# code-server
resource "coder_app" "code-server" {
  agent_id      = coder_agent.coder.id
  slug          = "code-server"  
  display_name  = "code-server"
  icon          = "/icon/code.svg"
  url           = "http://localhost:13337?folder=/home/coder"
  subdomain = true
  share     = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }  
}

resource "coder_app" "selenium-grid" {
  agent_id      = coder_agent.coder.id
  slug          = "selenium-grid"  
  display_name  = "selenium-grid"
  icon          = "https://upload.wikimedia.org/wikipedia/commons/d/d5/Selenium_Logo.png"
  url           = "http://localhost:4444"
  subdomain = true
  share     = "owner"
}

resource "coder_app" "filebrowser" {
  agent_id     = coder_agent.coder.id
  display_name = "file browser"
  slug         = "filebrowser"
  url          = "http://localhost:13339"
  icon         = "https://raw.githubusercontent.com/matifali/logos/main/database.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13339/healthz"
    interval  = 3
    threshold = 10
  }
}

module "vscode-web" {
 source         = "registry.coder.com/modules/vscode-web/coder"
 version        = "1.0.14"
 agent_id       = coder_agent.coder.id
 extensions     = ["github.copilot", "ms-python.python", "ms-toolsai.jupyter", "redhat.vscode-yaml"]
 accept_license = true
}

module "vscode" {
  source   = "registry.coder.com/modules/vscode-desktop/coder"
  version  = "1.0.15"
  agent_id = coder_agent.coder.id
}

module "jetbrains_gateway" {
  source         = "https://registry.coder.com/modules/jetbrains-gateway"
  agent_id       = coder_agent.coder.id
  agent_name     = "coder"
  folder         = "/home/coder"
  jetbrains_ides = ["GO", "WS", "IU", "PY"]
  default        = "PY"
}

data "coder_parameter" "jupyter" {
  name        = "Jupyter IDE type"
  type        = "string"
  description = "What type of Jupyter do you want?"
  mutable     = true
  default     = ""
  icon        = "/icon/jupyter.svg"
  order       = 1 

  option {
    name = "Jupyter Lab"
    value = "lab"
    icon = "https://raw.githubusercontent.com/gist/egormkn/672764e7ce3bdaf549b62a5e70eece79/raw/559e34c690ea4765001d4ba0e715106edea7439f/jupyter-lab.svg"
  }
  option {
    name = "Jupyter Notebook"
    value = "notebook"
    icon = "https://codingbootcamps.io/wp-content/uploads/jupyter_notebook.png"
  }    
  option {
    name = "None"
    value = ""
  }       
}

module "jupyterlab" {
  count = data.coder_parameter.jupyter.value == "lab" ? 1 : 0

  source   = "registry.coder.com/modules/jupyterlab/coder"
  version  = "1.0.19"
  agent_id = coder_agent.coder.id
}

module "jupyterlab-notebook" {
  count = data.coder_parameter.jupyter.value == "notebook" ? 1 : 0

  source   = "registry.coder.com/modules/jupyter-notebook/coder"
  version  = "1.0.19"
  agent_id = coder_agent.coder.id
}

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }   
  }
}

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default = false
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "disk_size" {
  name        = "PVC storage size"
  type        = "number"
  description = "Number of GB of storage for /home/coder and this will persist even when the workspace's Kubernetes pod and container are shutdown and deleted"
  icon        = "https://www.pngall.com/wp-content/uploads/5/Database-Storage-PNG-Clipart.png"
  validation {
    min       = 1
    max       = 20
    monotonic = "increasing"
  }
  mutable     = true
  default     = 10
  order       = 3  
}

# Minimum vCPUs needed 
data "coder_parameter" "cpu" {
  name        = "CPU cores"
  type        = "number"
  description = "CPU cores for your individual workspace"
  icon        = "https://png.pngtree.com/png-clipart/20191122/original/pngtree-processor-icon-png-image_5165793.jpg"
  validation {
    min       = 2
    max       = 4
  }
  mutable     = true
  default     = 2
  order       = 1  
}

# Minimum GB memory needed 
data "coder_parameter" "memory" {
  name        = "Memory (__ GB)"
  type        = "number"
  description = "Memory (__ GB) for your individual workspace"
  icon        = "https://www.vhv.rs/dpng/d/33-338595_random-access-memory-logo-hd-png-download.png"
  validation {
    min       = 4
    max       = 8
  }
  mutable     = true
  default     = 4
  order       = 2  
}

data "coder_parameter" "image" {
  name        = "Container Image"
  type        = "string"
  description = "What container image and language do you want?"
  mutable     = true
  default     = "codercom/enterprise-base:ubuntu"
  icon        = "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png"

  option {
    name = "Node React"
    value = "codercom/enterprise-node:latest"
    icon = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
  option {
    name = "Golang"
    value = "codercom/enterprise-golang:latest"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Go_Logo_Blue.svg/1200px-Go_Logo_Blue.svg.png"
  } 
  option {
    name = "Java"
    value = "codercom/enterprise-java:latest"
    icon = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  } 
  option {
    name = "Base including Python"
    value = "codercom/enterprise-base:ubuntu"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  }  
  order       = 4      
}

module "dotfiles" {
  source   = "registry.coder.com/modules/dotfiles/coder"
  version  = "1.0.18"
  agent_id = coder_agent.coder.id
}

data "coder_parameter" "repo" {
  name        = "Source Code Repository"
  type        = "string"
  description = "What source code repository do you want to clone?"
  mutable     = true
  default = "https://github.com/coder/coder"
  icon = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"

  option {
    name = "PAC-MAN"
    value = "https://github.com/coder/pacman-nodejs"
    icon =  "https://assets.stickpng.com/images/5a18871c8d421802430d2d05.png"
  }
  option {
    name = "Coder v2 OSS project"
    value = "https://github.com/coder/coder"
    icon = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"
  }  
  option {
    name = "Coder code-server project"
    value = "https://github.com/coder/code-server"
    icon = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"
  }
  order       = 5     
}

locals {
  folder_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 1), "")  
  repo_owner_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 2), "") 
}

module "git-clone" {
  source   = "registry.coder.com/modules/git-clone/coder"
  version  = "1.0.18"
  agent_id = coder_agent.coder.id
  url      = data.coder_parameter.repo.value
}

resource "coder_agent" "coder" {
  os             = "linux"
  arch           = "amd64"
  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  display_apps {
    vscode = false
    vscode_insiders = false
    ssh_helper = true
    port_forwarding_helper = true
    web_terminal = true
  }
    
  dir = "/home/coder"
  startup_script_behavior = "blocking"
  startup_script = <<EOT
# install and code-server, VS Code in a browser 
curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port 13337 >/dev/null 2>&1 &
coder login ${data.coder_workspace.me.access_url} --token ${data.coder_workspace_owner.me.session_token}

# Install required packages
sudo apt-get update
sudo apt-get install -y openjdk-11-jre wget unzip curl jq xvfb python3-venv

# Install Chrome and its dependencies
echo "Installing Chrome..."
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt-get update

# Install Chrome with all necessary dependencies for headless mode
sudo apt-get install -y --no-install-recommends \
  google-chrome-stable \
  fonts-liberation \
  libasound2 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libatspi2.0-0 \
  libcups2 \
  libdbus-1-3 \
  libdrm2 \
  libgbm1 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libwayland-client0 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2 \
  xdg-utils || {
    echo "Chrome installation failed, trying alternative method..."
    cd /tmp
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt-get install -y -f ./google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb
  }

# Verify Chrome installation
if ! command -v google-chrome &> /dev/null; then
    echo "ERROR: Chrome installation failed!"
    exit 1
fi

echo "Chrome installed successfully at: $(which google-chrome)"
google-chrome --version

# Setup Selenium
mkdir -p /home/coder/selenium-drivers
cd /home/coder/selenium-drivers

# Get Chrome version and download matching ChromeDriver
CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d'.' -f1)
echo "Chrome version: $CHROME_VERSION"

# Use Chrome for Testing API to get matching ChromeDriver
CHROMEDRIVER_URL=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | \
  jq -r ".versions[] | select(.version | startswith(\"$CHROME_VERSION.\")) | .downloads.chromedriver[] | select(.platform==\"linux64\") | .url" | \
  tail -1)

if [ -z "$CHROMEDRIVER_URL" ]; then
  # Fallback to a known working version
  CHROMEDRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/131.0.6778.87/linux64/chromedriver-linux64.zip"
fi

wget "$CHROMEDRIVER_URL" -O chromedriver-linux64.zip
unzip chromedriver-linux64.zip
mv chromedriver-linux64/chromedriver .
chmod +x chromedriver
rm -rf chromedriver-linux64*

# Download GeckoDriver
GECKO_VERSION=$(curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest | jq -r '.tag_name')
wget "https://github.com/mozilla/geckodriver/releases/download/$GECKO_VERSION/geckodriver-$GECKO_VERSION-linux64.tar.gz"
tar -xzf geckodriver-$GECKO_VERSION-linux64.tar.gz
rm geckodriver-$GECKO_VERSION-linux64.tar.gz

# Download Selenium Server
wget https://github.com/SeleniumHQ/selenium/releases/download/selenium-4.23.0/selenium-server-4.23.0.jar -O selenium-server.jar

# Setup Python environment
python3 -m venv /home/coder/selenium-env
/home/coder/selenium-env/bin/pip install selenium

# Add to PATH
export PATH=$PATH:/home/coder/selenium-drivers
echo 'export PATH=$PATH:/home/coder/selenium-drivers' >> /home/coder/.bashrc

# Start Xvfb with proper settings
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > /dev/null 2>&1 &

# Wait for Xvfb to start
sleep 2

# Start Selenium Grid with Chrome options configuration
cd /home/coder/selenium-drivers
cat > /home/coder/selenium-config.toml << 'CONFIG'
[node]
detect-drivers = false

[[node.driver-configuration]]
display-name = "Chrome"
max-sessions = 1
webdriver-executable = "/home/coder/selenium-drivers/chromedriver"
stereotype = '{"browserName": "chrome", "browserVersion": "131", "platformName": "linux", "goog:chromeOptions": {"binary": "/usr/bin/google-chrome", "args": ["--headless", "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--disable-web-security", "--disable-features=VizDisplayCompositor", "--window-size=1920,1080"]}}'
CONFIG

java -jar selenium-server.jar standalone --config /home/coder/selenium-config.toml > /home/coder/selenium.log 2>&1 &

# Wait for Selenium to start
sleep 5

# Create test script with improved Chrome options
cat > /home/coder/test-selenium.py << 'SCRIPT'
#!/home/coder/selenium-env/bin/python3
import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

# Find Chrome binary
chrome_paths = [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium'
]

chrome_binary = None
for path in chrome_paths:
    if os.path.exists(path):
        chrome_binary = path
        break

if chrome_binary:
    print(f"Found Chrome at: {chrome_binary}")
else:
    print("Chrome binary not found!")
    exit(1)

chrome_options = Options()
chrome_options.binary_location = chrome_binary
chrome_options.add_argument('--headless=new')  # Use new headless mode
chrome_options.add_argument('--no-sandbox')
chrome_options.add_argument('--disable-dev-shm-usage')
chrome_options.add_argument('--disable-gpu')
chrome_options.add_argument('--disable-web-security')
chrome_options.add_argument('--disable-features=VizDisplayCompositor')
chrome_options.add_argument('--window-size=1920,1080')
chrome_options.add_argument('--remote-debugging-port=9222')
chrome_options.add_argument('--disable-blink-features=AutomationControlled')
chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
chrome_options.add_experimental_option('useAutomationExtension', False)

try:
    print("Attempting to connect to Selenium Grid...")
    driver = webdriver.Remote(
        command_executor='http://localhost:4444',
        options=chrome_options
    )
    driver.get("https://www.google.com")
    print(f"Success! Page title: {driver.title}")
    driver.quit()
except Exception as e:
    print(f"Error: {e}")
    print("\nTroubleshooting tips:")
    print("1. Check if Selenium is running: ps aux | grep selenium")
    print("2. Check Selenium logs: tail -n 50 /home/coder/selenium.log")
    print("3. Check if Chrome is installed: google-chrome --version")
    print("4. Check if ChromeDriver is executable: ls -la /home/coder/selenium-drivers/chromedriver")
SCRIPT
chmod +x /home/coder/test-selenium.py

# Create alternative test script for direct ChromeDriver connection
cat > /home/coder/test-direct.py << 'SCRIPT'
#!/home/coder/selenium-env/bin/python3
import os
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options

# Find Chrome binary
chrome_paths = [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium'
]

chrome_binary = None
for path in chrome_paths:
    if os.path.exists(path):
        chrome_binary = path
        break

if chrome_binary:
    print(f"Found Chrome at: {chrome_binary}")
else:
    print("Chrome binary not found!")
    print("Checking installed packages...")
    os.system("dpkg -l | grep -i chrome")
    exit(1)

chrome_options = Options()
chrome_options.binary_location = chrome_binary
chrome_options.add_argument('--headless=new')
chrome_options.add_argument('--no-sandbox')
chrome_options.add_argument('--disable-dev-shm-usage')
chrome_options.add_argument('--disable-gpu')
chrome_options.add_argument('--window-size=1920,1080')

try:
    print("Attempting direct ChromeDriver connection...")
    service = Service('/home/coder/selenium-drivers/chromedriver')
    driver = webdriver.Chrome(service=service, options=chrome_options)
    driver.get("https://www.google.com")
    print(f"Success! Page title: {driver.title}")
    driver.quit()
except Exception as e:
    print(f"Error: {e}")
    print("\nDebugging info:")
    os.system("which google-chrome google-chrome-stable chromium-browser chromium 2>/dev/null")
    os.system("ls -la /usr/bin/ | grep -i chrome")
SCRIPT
chmod +x /home/coder/test-direct.py

# Install filebrowser
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
filebrowser --noauth --root /home/coder --port 13339 >/tmp/filebrowser.log 2>&1 &

# Create a helper script to check Selenium status
cat > /home/coder/check-selenium.sh << 'SCRIPT'
#!/bin/bash
echo "=== Selenium Status Check ==="
echo "Chrome version:"
google-chrome --version
echo -e "\nChromeDriver version:"
/home/coder/selenium-drivers/chromedriver --version
echo -e "\nSelenium processes:"
ps aux | grep -E "(java|selenium)" | grep -v grep
echo -e "\nSelenium Grid status:"
curl -s http://localhost:4444/wd/hub/status | jq . || echo "Grid not responding"
echo -e "\nLast 20 lines of Selenium log:"
tail -n 20 /home/coder/selenium.log
SCRIPT
chmod +x /home/coder/check-selenium.sh

echo "Selenium setup complete! Test with: ./test-selenium.py"
echo "Check status with: ./check-selenium.sh"
  EOT  
}

variable "workspace_namespace" {
  description = <<-EOF
  Kubernetes namespace to deploy the workspace into

  EOF
  default = ""
}

locals {
  # This is the init script for the main workspace container that runs before the
  # agent starts to configure workspace process logging.
  exectrace_init_script = <<EOT
    set -eu
    pidns_inum=$(readlink /proc/self/ns/pid | sed 's/[^0-9]//g')
    if [ -z "$pidns_inum" ]; then
      echo "Could not determine process ID namespace inum"
      exit 1
    fi

    # Before we start the script, does curl exist?
    if ! command -v curl >/dev/null 2>&1; then
      echo "curl is required to download the Coder binary"
      echo "Please install curl to your image and try again"
      # 127 is command not found.
      exit 127
    fi

    echo "Sending process ID namespace inum to exectrace sidecar"
    rc=0
    max_retry=5
    counter=0
    until [ $counter -ge $max_retry ]; do
      set +e
      curl \
        --fail \
        --silent \
        --connect-timeout 5 \
        -X POST \
        -H "Content-Type: text/plain" \
        --data "$pidns_inum" \
        http://127.0.0.1:56123
      rc=$?
      set -e
      if [ $rc -eq 0 ]; then
        break
      fi

      counter=$((counter+1))
      echo "Curl failed with exit code $${rc}, attempt $${counter}/$${max_retry}; Retrying in 3 seconds..."
      sleep 3
    done
    if [ $rc -ne 0 ]; then
      echo "Failed to send process ID namespace inum to exectrace sidecar"
      exit $rc
    fi

  EOT 
}


resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home-directory
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    namespace = var.workspace_namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"  = "coder"
          "com.coder.resource"         = "true"
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }
      spec {
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "coder-container"
          image             = data.coder_parameter.image.value
          image_pull_policy = "Always"
          command           = [
            "sh", 
            "-c", 
            "${local.exectrace_init_script}\n\n${coder_agent.coder.init_script}"          
          ]
          security_context {
            run_as_user = "1000"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.coder.token
          }
          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home-directory"
            read_only  = false
          }
        }

        # Sidecar process logging container
        container {
          name              = "exectrace"
          image             = "ghcr.io/coder/exectrace:latest"
          image_pull_policy = "Always"
          command = [
            "/opt/exectrace",
            "--init-address", "127.0.0.1:56123",
            "--label", "workspace_id=${data.coder_workspace.me.id}",
            "--label", "workspace_name=${data.coder_workspace.me.name}",
            "--label", "user_id=${data.coder_workspace_owner.me.id}",
            "--label", "username=${data.coder_workspace_owner.me.name}",
            "--label", "user_email=${data.coder_workspace_owner.me.email}",
          ]
          security_context {
            run_as_user  = "0"
            run_as_group = "0"
            privileged   = true
          }
            #Process logging env variables
          env {
            name = "CODER_AGENT_SUBSYSTEM"
            value = "exectrace"
          }
        }

        volume {
            name = "home-directory"
            persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
            }
        }  

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = lower("home-coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}")
    namespace = var.workspace_namespace
  }
  wait_until_bound = false    
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment.main[0].id
  daily_cost  = data.coder_parameter.cpu.value + data.coder_parameter.memory.value
  item {
    key   = "image"
    value = data.coder_parameter.image.value
  }
  item {
    key   = "repo cloned"
    value = "${local.repo_owner_name}/${local.folder_name}"
  }   
}

resource "coder_script" "selenium_testing" {
  agent_id     = coder_agent.coder.id
  display_name = "Selenium Testing"
  icon         = "https://upload.wikimedia.org/wikipedia/commons/d/d5/Selenium_Logo.png"
  run_on_start = true
  script = <<EOF
    #!/bin/bash
    set -e
    echo "Running Selenium Tests"
    
    # Wait for the startup script to complete and Selenium environment to be ready
    while [ ! -f /home/coder/selenium-env/bin/activate ]; do
      echo "Waiting for Selenium environment to be ready..."
      sleep 5
    done
    
    # Additional wait to ensure all services are up
    sleep 10
    
    # Check if Selenium Grid is running
    while ! curl -s http://localhost:4444/wd/hub/status > /dev/null 2>&1; do
      echo "Waiting for Selenium Grid to start..."
      sleep 5
    done
    
    echo "Selenium Grid is ready!"
    
    # Clone the repository
    cd /home/coder
    rm -rf coder-selenium-testing
    git clone https://github.com/dahr/coder-selenium-testing.git
    cd /home/coder/coder-selenium-testing
    
    # Make scripts executable
    chmod +x *.py
    
    # Run the tests using the selenium virtual environment's Python
    echo "Running quick-selenium-demo.py..."
    /home/coder/selenium-env/bin/python quick-selenium-demo.py
    
    echo "Running selenium-test-suite.py..."
    /home/coder/selenium-env/bin/python selenium-test-suite.py
    
    echo "Running ecommerce-selenium-test.py..."
    /home/coder/selenium-env/bin/python ecommerce-selenium-test.py
    
    echo "All Selenium tests completed!"
    EOF
  depends_on = [
    coder_agent.coder
  ]
}