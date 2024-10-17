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

locals {
  folder_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 1), "")  
  repo_owner_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 2), "")  
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



variable "workspaces_namespace" {
  description = <<-EOF
  Kubernetes namespace to deploy the workspace into

  EOF
  default = ""
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
  default     = "codercom/enterprise-golang:ubuntu"
  icon        = "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png"

  option {
    name = "Node React"
    value = "codercom/enterprise-node:ubuntu"
    icon = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
  option {
    name = "Golang"
    value = "codercom/enterprise-golang:ubuntu"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Go_Logo_Blue.svg/1200px-Go_Logo_Blue.svg.png"
  } 
  option {
    name = "Java"
    value = "codercom/enterprise-java:ubuntu"
    icon = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  } 
  option {
    name = "Base including Python"
    value = "docker.io/codercom/enterprise-base:ubuntu"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  }  
  order       = 4      
}

data "coder_parameter" "repo" {
  name        = "Source Code Repository"
  type        = "string"
  description = "What source code repository do you want to clone?"
  mutable     = true
  icon        = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.png"
  default     = "https://github.com/coder/coder-react"

  option {
    name = "PAC-MAN"
    value = "https://github.com/coder/pacman-nodejs"
    icon =  "https://assets.stickpng.com/images/5a18871c8d421802430d2d05.png"
  }

  option {
    name = "coder-react"
    value = "https://github.com/coder/coder-react"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/React-icon.svg/2300px-React-icon.svg.png"
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
  option {
    name = "Java Hello, World! command line app"
    value = "https://github.com/coder/java_helloworld"
    icon = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  }  
  option {
    name = "Python command line app"
    value = "https://github.com/coder/python_commissions"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  }
  order       = 5     
}

data "coder_parameter" "dotfiles_url" {
  name        = "Dotfiles URL (optional)"
  description = "Personalize your workspace e.g., https://github.com/coder/example-dotfiles.git"
  type        = "string"
  default     = ""
  mutable     = true 
  icon        = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.png"
  order       = 7
}

resource "coder_agent" "coder" {
  os             = "linux"
  arch           = "amd64"
 # startup_script = <<-EOT
 #    set -e
 #
    # install and start code-server
 #   curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.11.0
 #   /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
 # EOT

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

# clone repo selected by user
if test -z "${data.coder_parameter.repo.value}" 
then
  echo "No git repo specified, skipping"
else
  if [ ! -d "${local.folder_name}" ] 
  then
    echo "Cloning git repo..."
    git clone ${data.coder_parameter.repo.value}
  else
    echo "Repo ${data.coder_parameter.repo.value} already exists. Will not reclone"
  fi
  cd ${local.folder_name}
fi

# install and code-server, VS Code in a browser 
#curl -fsSL https://code-server.dev/install.sh | sh
#code-server --auth none --port 13337 >/dev/null 2>&1 &

# use coder CLI to clone and install dotfiles
if [[ ! -z "${data.coder_parameter.dotfiles_url.value}" ]]; then
  coder dotfiles -y ${data.coder_parameter.dotfiles_url.value}
fi


coder login ${data.coder_workspace.me.access_url} --token ${data.coder_workspace_owner.me.session_token}

  EOT  
}

# code-server
#resource "coder_app" "code-server" {
#  agent_id      = coder_agent.coder.id
#  slug          = "code-server"  
#  display_name  = "code-server"
#  icon          = "/icon/code.svg"
#  url           = "http://localhost:13337?folder=/home/coder"
#  subdomain = false
#  share     = "owner"
#
#  healthcheck {
#    url       = "http://localhost:13337/healthz"
#    interval  = 3
#    threshold = 10
#  }  
#}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home-directory
  ]  
  metadata {
    name = lower("coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}")
    namespace = var.workspaces_namespace
  }
  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }    
    container {
      name    = "coder-container"
      image   = data.coder_parameter.image.value
      image_pull_policy = "Always"
      command = ["sh", "-c", coder_agent.coder.init_script]
      security_context {
        run_as_user = "1000"
      }      
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.coder.token
      }  
      resources {
        requests = {
          cpu    = "250m"
          memory = "500Mi"
        }        
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}G"
        }
      }                       
      volume_mount {
        mount_path = "/home/coder"
        name       = "home-directory"
      }      
    }
    volume {
      name = "home-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
      }
    }        
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = lower("home-coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}")
    namespace = var.workspaces_namespace
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
  resource_id = kubernetes_pod.main[0].id
  item {
    key   = "image"
    value = data.coder_parameter.image.value
  }
  item {
    key   = "repo cloned"
    value = "${local.repo_owner_name}/${local.folder_name}"
  }   
}
