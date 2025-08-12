terraform {
    required_providers {
        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "2.37.1"
        }
        coder = {
            source = "coder/coder"
            version = "2.8.0"
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

data "coder_parameter" "ai_prompt" {
    type        = "string"
    name        = "AI Prompt"
    icon        = "/emojis/1f4ac.png"
    description = "Write a task prompt for Claude. This will be the first action it will attempt to finish."
    default = "Do nothing but report a 'task completed' update to Coder"
    mutable     = false
}

data "coder_parameter" "location" {
    name         = "location"
    display_name = "Location"
    description  = "Choose the location that's closest to you for the best connection!"
    mutable      = true
    order = 1
    default      = "us-east-2"
    option {
        value = "us-east-2"
        name  = "Ohio"
        icon  = "/emojis/1f1fa-1f1f8.png" # 🇺🇸
    }
    option {
        value = "us-west-2"
        name  = "Oregon"
        icon  = "/emojis/1f1fa-1f1f8.png" # 🇺🇸
    }
    option {
        value = "eu-west-2"
        name  = "London"
        icon  = "/emojis/1f1ec-1f1e7.png" # 🇬🇧
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

locals {
    region_map = {
        "us-east-2" = "Ohio"
        "us-west-2" = "Oregon"
        "eu-west-2" = "London"
    }
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
        value = local.region_map[data.coder_parameter.location.value]
    }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
    cost = 2
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

module "goose" {
    source        = "./modules/goose"
    agent_id      = coder_agent.dev.id
    folder        = local.work_folder
    install_goose = false
    install_agentapi = true

    pre_install_script = <<-EOF
        # If user doesn't have a Github account or aren't 
        # part of the coder-contrib organization, then they can use the `coder-contrib-bot` account.
        if [ ! -z "$GH_USERNAME" ]; then
            unset -v GIT_ASKPASS
            unset -v GIT_SSH_COMMAND
        fi
    EOF
    goose_version = "1.0.27"
    goose_provider = "openai"
    goose_model = "anthropic.claude.haiku"
    additional_extensions = yamlencode({
        desktop-command = {
            name = "Desktop-commander"
            enabled = true
            args = []
            cmd = "${local.home_folder}/bin/desktop-commander"
            env = {}
            type = "stdio"
        },
        playwright = {
            name = "Playwright"
            enabled = true
            args = []
            cmd = "${local.home_folder}/bin/playwright-mcp-server"
            env = {}
            type = "stdio"
        }
    })
}

locals {
    port = 3000
    domain = element(split("/", data.coder_workspace.me.access_url), -1)
}

module "preview" {
    source = "./modules/preview"
    agent_id = coder_agent.dev.id
    port = local.port
}

locals {
    task_prompt = join(" ", [
        "First, post a 'task started' update to Coder.",
        "Then, review all of your memory.",
        "Finally, ${data.coder_parameter.ai_prompt.value}.",
    ])
    system_prompt = <<-EOT
        First, report an initial task to Coder to show you have started. The user has provided you with a prompt of something to create. Create it the best you can, and keep it as short as possible.
        
        If you're being tasked to create a web application, then:
        - ALWAYS start the server using `python3` or `node` on localhost:${local.port}.
        - BEFORE starting the server, ALWAYS attempt to kill ANY process using port ${local.port}, and then run the dev server on port ${local.port}.
        - ALWAYS build the project using dev servers (and ALWAYS VIA desktop-commander)
        - When finished, you should use Playwright to review the HTML to ensure it is working as expected.

        ALWAYS run long-running commands (e.g. `pnpm dev` or `npm run dev`) using desktop-commander so it runs it in the background and users can prompt you. Other short-lived commands (build, test, cd, write, read, view, etc) can run normally.

        NEVER run the dev server without desktop-commander.

        For previewing, always use the dev server for fast feedback loops (never do a full Next.js build, for exmaple). A simple static HTML is preferred for web applications, but pick the best AND lightest framework for the job.
        
        The dev server will ALWAYS be on localhost:${local.port} and NEVER start on another port. If the dev server crashes for some reason, kill port ${local.port} (or the desktop-commander session) and restart the dev server.

        After large changes, use Playwright to ensure your changes work (preview localhost:${local.port}). Take a screenshot, look at the screenshot. Also look at the HTML output from Playwright. If there are errors or something looks "off," fix it.
        
        Aim to autonomously investigate and solve issues the user gives you and test your work, whenever possible.
        
        Avoid shortcuts like mocking tests. When you get stuck, you can ask the user but opt for autonomy.
        
        If you're making a git commit, always work on a different branch called "${data.coder_workspace.me.name}" and set the `user.name` to "Goose AI", and `user.email` to "${data.coder_workspace_owner.me.email}".

        If you're making a pull request, then do not ask anyone to review it.

        In your task reports to Coder:
        - Be specific about what you're doing
        - Clearly indicate what information you need from the user when in "failure" state
        - Keep it under 160 characters
        - Make it actionable

        If you're being tasked to create a Coder template, then,
        - You must ALWAYS ask the user for permission to push it. 
        - You are NOT allowed to push templates OR create workspaces from them without the users explicit approval.

        When reporting URLs to Coder, report to "https://preview--dev--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}.${local.domain}/" that proxies port ${local.port}
    EOT
    logged_into_git = data.coder_external_auth.github.access_token != ""
    env = {
        CODER_AGENT_TOKEN = coder_agent.dev.token
        OPENAI_HOST = "https://litellm.ai.demo.coder.com"
        CODER_MCP_APP_STATUS_SLUG = "goose"
        GOOSE_DISABLE_KEYRING = "1"
        GOOSE_SYSTEM_PROMPT = local.system_prompt
        GOOSE_TASK_PROMPT = local.task_prompt
        GOOSE_LEAD_MODEL = "anthropic.claude.sonnet"
        DISABLE_PROMPT_CACHING = "1"
        GIT_AUTHOR_NAME = data.coder_workspace_owner.me.name
        GIT_AUTHOR_EMAIL = data.coder_workspace_owner.me.email
        GH_TOKEN = local.logged_into_git ? data.coder_external_auth.github.access_token : var.gh_token
        NODE_OPTIONS = "--max-old-space-size=${512*local.cost}"
    }
}

resource "kubernetes_pod" "dev" {

    count = data.coder_workspace.me.start_count

    metadata {
        name = random_uuid.prebuilds.result
        namespace = "coder-ws"
    }

    spec {
        termination_grace_period_seconds = 0
        node_selector = {
            "node.coder.io/used-for" = "coder-ws-all"
            "node.coder.io/name" = "coder"
        }

        toleration {
            key = "dedicated"
            operator = "Equal"
            value = "coder-ws"
            effect = "NoSchedule"
        }

        container {
            name = random_uuid.prebuilds.result
            image = "750246862020.dkr.ecr.us-east-2.amazonaws.com/goose-ws:ubuntu-noble"
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
                name = "OPENAI_API_KEY"
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