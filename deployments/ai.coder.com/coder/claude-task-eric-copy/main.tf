terraform {
    required_providers {
        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "2.37.1"
        }
        coder = {
            source = "coder/coder"
            version = "~> 2.0"
        }
        random = {
            source = "hashicorp/random"
            version = "3.7.2"
        }
    }
}

variable "gh_token" {
    type = string
    sensitive = true
}

variable "gh_username" {
    type = string
    sensitive = true
}

resource "coder_app" "hterm" {
  agent_id     = coder_agent.dev.id
  slug         = "hterm"
  display_name = "HTerminal"
  url          = "http://localhost:3000"
  icon         = "/icon/terminal.svg"
  subdomain    = false
  share        = "owner"
}


data "coder_parameter" "ai_prompt" {
    type        = "string"
    name        = "AI Prompt"
    icon        = "/emojis/1f4ac.png"
    description = "Write a task prompt for Claude. This will be the first action it will attempt to finish."
    default = "Report 'task completed' to Coder"
    mutable     = false
}

locals {
    regions = {
        "us-east-2" = {
            name = "Ohio"
            icon = "/emojis/1f1fa-1f1f8.png" # 🇺🇸
        }
        "us-west-2" = {
            name = "Oregon"
            icon = "/emojis/1f1fa-1f1f8.png" # 🇺🇸
        }
        "eu-west-2" = {
            name = "London"
            icon = "/emojis/1f1ec-1f1e7.png" # 🇬🇧
        }
    }
}

data "coder_parameter" "location" {
    name         = "location"
    display_name = "Location"
    description  = "Choose the location that's closest to you for the best connection!"
    mutable      = true
    order = 1
    default      = "us-east-2"
    dynamic "option" {
        for_each = local.regions
        content {
            value = option.key
            name = option.value.name
            icon = option.value.icon
        }
    }
}

data "coder_parameter" "git-repo" {
    name         = "git-repo"
    display_name = "Git Repository"
    description  = "Clone a Git repo over HTTPS (if public) or SSH (if private)."
    mutable      = false
    order = 0
    default      = ""
}

data "coder_workspace_tags" "location" {
    tags = {
        region = data.coder_parameter.location.value
    }
}

data "coder_external_auth" "github" {
    id = "primary-github"
    optional = true
}

resource "coder_metadata" "pod_info" {
    count = data.coder_workspace.me.start_count
    resource_id = kubernetes_pod.dev[0].id
    daily_cost = local.cost
    item {
        key   = "UUID"
        value = random_uuid.prebuilds.result
    }
    item {
        key = "Location"
        value = local.regions[data.coder_parameter.location.value].name
    }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
    home_folder = "/home/coder"
    work_folder = data.coder_parameter.git-repo.value == "" ? local.home_folder : join("/", [
        local.home_folder, element(split(".", element(split("/", data.coder_parameter.git-repo.value), -1)), 0)
    ])
}

resource "random_uuid" "prebuilds" {}

resource "coder_agent" "dev" {
    arch = "amd64"
    os = "linux"
    dir = local.home_folder
    startup_script = <<-EOT

# Install Node.js if not present
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Create hterm app directory
mkdir -p /home/coder/hterm-app
cd /home/coder/hterm-app

# Initialize npm project
npm init -y
npm install hterm express ws node-pty

# Create the hterm server
cat > server.js << 'EOF'
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const pty = require('node-pty');
const path = require('path');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.static('public'));
app.use('/hterm', express.static(path.join(__dirname, 'node_modules/hterm/dist')));

wss.on('connection', (ws) => {
  const shell = process.platform === 'win32' ? 'powershell.exe' : 'bash';
  const ptyProcess = pty.spawn(shell, [], {
    name: 'xterm-color',
    cols: 80,
    rows: 24,
    cwd: process.env.HOME,
    env: process.env
  });

  ptyProcess.on('data', (data) => {
    ws.send(data);
  });

  ws.on('message', (data) => {
    ptyProcess.write(data);
  });

  ws.on('close', () => {
    ptyProcess.kill();
  });
});

server.listen(3000, () => {
  console.log('HTerminal server running on port 3000');
});
EOF

# Create public directory and HTML file
mkdir -p public
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>HTerminal</title>
    <script src="/hterm/hterm_all.js"></script>
    <style>
        body { margin: 0; padding: 0; background: #000; }
        #terminal { width: 100vw; height: 100vh; }
    </style>
</head>
<body>
    <div id="terminal"></div>
    <script>
        hterm.defaultStorage = new lib.Storage.Local();
        const t = new hterm.Terminal();
        
        t.onTerminalReady = function() {
            const io = t.io.push();
            
            const ws = new WebSocket(`ws://$${window.location.host}`);
            
            ws.onopen = () => {
                console.log('WebSocket connected');
            };
            
            ws.onmessage = (event) => {
                io.print(event.data);
            };
            
            io.onVTKeystroke = (string) => {
                ws.send(string);
            };
            
            io.sendString = (string) => {
                ws.send(string);
            };
        };
        
        t.decorate(document.getElementById('terminal'));
        t.installKeyboard();
    </script>
</body>
</html>
EOF

# Start the server in background
nohup node server.js > /tmp/hterm.log 2>&1 &


    EOT

    display_apps {
        vscode          = false
        vscode_insiders = false
        web_terminal    = true
        ssh_helper      = false
    }

    metadata {
        display_name = "CPU Usage"
        key          = "cpu_usage"
        order        = 0
        script       = "coder stat cpu"
        interval     = 10
        timeout      = 1
    }

    metadata {
        display_name = "RAM Usage"
        key          = "ram_usage"
        order        = 1
        script       = "coder stat mem"
        interval     = 10
        timeout      = 1
    }

    metadata {
        display_name = "CPU Usage (Host)"
        key          = "cpu_usage_host"
        order        = 2
        script       = "coder stat cpu --host"
        interval     = 10
        timeout      = 1
    }

    metadata {
        display_name = "RAM Usage (Host)"
        key          = "ram_usage_host"
        order        = 3
        script       = "coder stat mem --host"
        interval     = 10
        timeout      = 1
    }

    metadata {
        display_name = "Swap Usage (Host)"
        key          = "swap_usage_host"
        order        = 4
        script       = <<-EOT
            #!/usr/bin/env bash
            echo "$(free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }') GiB"
        EOT
        interval     = 10
        timeout      = 1
    }

    metadata {
        display_name = "Load Average (Host)"
        key          = "load_host"
        order        = 5
        # get load avg scaled by number of cores
        script   = <<-EOT
            #!/usr/bin/env bash
            echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
        EOT
        interval = 60
        timeout  = 1
    }

    metadata {
        display_name = "Disk Usage (Host)"
        key          = "disk_host"
        order        = 6
        script       = "coder stat disk --path /"
        interval     = 600
        timeout      = 10
    }

    resources_monitoring {
        memory {
            enabled   = true
            threshold = 80
        }
        volume {
            enabled   = true
            threshold = 90
            path      = "/home/coder"
        }
    }
}

module "coder-login" {
    source = "./modules/coder-login"
    agent_id = coder_agent.dev.id
}

module "git-clone" {
    count = data.coder_parameter.git-repo.value == "" ? 0 : 1
    source = "./modules/git-clone"
    agent_id = coder_agent.dev.id
    url      = data.coder_parameter.git-repo.value
    base_dir = local.home_folder
}

module "code-server" {
    source   = "./modules/code-server"
    agent_id = coder_agent.dev.id
    folder = local.work_folder
}

module "vscode-desktop" {
    source   = "./modules/vscode-desktop"
    agent_id = coder_agent.dev.id
    folder   = local.work_folder
}

module "cursor" {
    source   = "./modules/cursor"
    agent_id = coder_agent.dev.id
    folder = local.work_folder
}

locals {
    cost = 2

    logged_into_git = data.coder_external_auth.github.access_token != ""
    env = {
        CODER_AGENT_TOKEN = coder_agent.dev.token
        CODER_MCP_APP_STATUS_SLUG           = "claude-code"
        ANTHROPIC_BASE_URL = "https://litellm.ai.demo.coder.com"
        ANTHROPIC_MODEL = "anthropic.claude.sonnet"
        ANTHROPIC_SMALL_FAST_MODEL = "anthropic.claude.haiku"
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
        DISABLE_PROMPT_CACHING = "1"
        DISABLE_INTERLEAVED_THINKING = "1"
        GIT_AUTHOR_NAME = data.coder_workspace_owner.me.name
        GIT_AUTHOR_EMAIL = data.coder_workspace_owner.me.email
        GH_TOKEN = local.logged_into_git ? data.coder_external_auth.github.access_token : var.gh_token
        NODE_OPTIONS = "--max-old-space-size=${512*local.cost}"
        CLAUDE_CODE_MAX_OUTPUT_TOKENS = "8192"
    }
}

resource "kubernetes_pod" "dev" {

    count = data.coder_workspace.me.start_count

    metadata {
        name = random_uuid.prebuilds.result
        namespace = "coder-ws"
    }

    spec {
        node_selector = {
            "node.coder.io/used-for" = "coder-ws-all"
            "node.coder.io/name" = "coder"
        }
        termination_grace_period_seconds = 0

        toleration {
            key = "dedicated"
            operator = "Equal"
            value = "coder-ws"
            effect = "NoSchedule"
        }

        container {
            name = random_uuid.prebuilds.result
            image = "750246862020.dkr.ecr.us-east-2.amazonaws.com/claude-ws:ubuntu-noble"
            image_pull_policy = "IfNotPresent"
            command = [
                "/bin/bash", "-c", 
                join("\n", [
                    "export PATH=$PATH:${local.home_folder}/bin",
                    local.logged_into_git ? "" : "git config --global credential.helper 'store --file=/tmp/.git-credentials'",
                    local.logged_into_git ? "" : "echo \"https://$GH_USERNAME:$GH_TOKEN@github.com\" > /tmp/.git-credentials",
                    coder_agent.dev.init_script
                ])
            ]
            dynamic "env" {
                for_each = local.env
                content {
                    name = env.key
                    value = env.value
                }
            }
            env {
                name = "ANTHROPIC_AUTH_TOKEN"
                value_from {
                    secret_key_ref {
                        name = "litellm"
                        key = "token"
                    }
                }
            }
            dynamic "env" {
                for_each = local.logged_into_git ? {} : {
                    GH_USERNAME = var.gh_username
                }
                content {
                    name = env.key
                    value = env.value
                }
            }
            resources {
                limits = {
                    cpu = "${ceil(local.cost/2)}"
                    memory = "${local.cost}G"
                    ephemeral-storage = "${local.cost*5}Gi"
                }
            }
            security_context {
                allow_privilege_escalation = true
                privileged = false
                read_only_root_filesystem = false
            }
        }
    }

    lifecycle {
        ignore_changes = [ spec.0.container.0.env ]
    }
}