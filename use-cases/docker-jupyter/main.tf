terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
    }
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

locals {
  cpu-limit = "1"
  memory-limit = "2G"
  cpu-request = "500m"
  memory-request = "500Mi" 
  home-volume = "10Gi"
  image = "codercom/enterprise-base:ubuntu"
}

variable "default_registry" {
    type = string
    description = "The default docker image registry to use."
    default = "index.docker.io"
}

variable registry_auth {
  # Cannot be list, must be string: https://coder.com/docs/templates/variables
  # Uses registry_auth nested schema: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs#nested-schema-for-registry_auth
  type = string
  description = <<-EOF
  List of registry auths for your docker provider.
  
  e.g., "[{\"username\": \"User1\", \"password\": \"ABCD1234\"}]"
  EOF
  default = "[]"
}

variable "socket" {
  type        = string
  description = <<-EOF
  The Unix socket that the Docker daemon listens on and how containers
  communicate with the Docker daemon.

  Either Unix or TCP
  e.g., unix:///var/run/docker.sock

  EOF
  default = "unix:///var/run/docker.sock"
}

provider "docker" {
  host = var.socket
}

data "coder_workspace" "me" {
}

data "coder_workspace_owner" "me" {
}

provider "coder" {

}

data "coder_parameter" "jupyter" {
  name        = "Jupyter IDE type"
  type        = "string"
  description = "What type of Jupyter do you want?"
  mutable     = true
  default     = "lab"
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
}

data "coder_parameter" "appshare" {
  name        = "App Sharing"
  type        = "string"
  description = "What sharing level do you want for the IDEs?"
  mutable     = true
  default     = "owner"
  icon        = "/emojis/1f30e.png"

  option {
    name = "Accessible outside the Coder deployment"
    value = "public"
    icon = "/emojis/1f30e.png"
  }
  option {
    name = "Accessible by authenticated users of the Coder deployment"
    value = "authenticated"
    icon = "/emojis/1f465.png"
  } 
  option {
    name = "Only accessible by the workspace owner"
    value = "owner"
    icon = "/emojis/1f510.png"
  } 
  order       = 2      
}

data "coder_parameter" "marketplace" {
  name        = "VS Code Extension Marketplace"
  type        = "string"
  description = "What extension marketplace do you want to use with code-server?"
  mutable     = true
  default     = "ovsx"
  icon        = "/icon/code.svg"

  option {
    name = "Microsoft"
    value = "ms"
    icon = "/icon/microsoft.svg"
  }
  option {
    name = "Open VSX"
    value = "ovsx"
    icon = "https://files.mastodon.social/accounts/avatars/110/249/536/652/270/515/original/bde7b7fef9cef005.png"
  }  
  order       = 4      
}

data "coder_parameter" "repo" {
  name        = "Source Code Repository"
  type        = "string"
  description = "What source code repository do you want to clone?"
  mutable     = true
  icon        = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"
  default     = "https://github.com/coder/code-server"
  order       = 5     
}

data "coder_parameter" "extension" {
  name        = "VS Code extension"
  type        = "string"
  description = "Which VS Code extension do you want?"
  mutable     = true
  default     = "ms-python.python"
  icon        = "/icon/code.svg"

  option {
    name = "Python"
    value = "ms-python.python"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  } 
  option {
    name = "Jupyter"
    value = "ms-toolsai.jupyter"
    icon = "/icon/jupyter.svg"
  }
  order       = 6        
}

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/code-server/coder"
  version  = "1.0.18"
  agent_id = coder_agent.dev.id
  extensions = [ data.coder_parameter.extension.value ]
  auto_install_extensions = true
}

module "dotfiles" {
  source               = "registry.coder.com/modules/dotfiles/coder"
  version              = "1.0.18"
  agent_id             = coder_agent.dev.id
  default_dotfiles_uri = "https://github.com/coder/example-dotfiles.git"
}

module "git-clone" {
  source   = "registry.coder.com/modules/git-clone/coder"
  version  = "1.0.18"
  agent_id = coder_agent.dev.id
  url      = data.coder_parameter.repo.value
}

module "jupyterlab" {
  source   = "registry.coder.com/modules/jupyterlab/coder"
  version  = "1.0.19"
  agent_id = coder_agent.dev.id
  count = data.coder_parameter.jupyter.value == "lab" ? 1 : 0
}

module "jupyterlab-notebook" {
  source   = "registry.coder.com/modules/jupyter-notebook/coder"
  version  = "1.0.19"
  agent_id = coder_agent.dev.id
  count = data.coder_parameter.jupyter.value == "notebook" ? 1 : 0
}

resource "coder_agent" "dev" {
  arch           = "amd64"
  os             = "linux"

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

  display_apps {
    vscode = false
    vscode_insiders = false
    ssh_helper = false
    port_forwarding_helper = false
    web_terminal = true
  }
  startup_script_behavior = "blocking"
}


resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = local.image
  # Uses lower() to avoid Docker restriction on container names.
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"]
  # Use the docker gateway if the access URL is 127.0.0.1
  #entrypoint = ["sh", "-c", replace(coder_agent.dev.init_script, "127.0.0.1", "host.docker.internal")]

  command = [
    "sh", "-c",
    <<EOT
    trap '[ $? -ne 0 ] && echo === Agent script exited with non-zero code. Sleeping infinitely to preserve logs... && sleep infinity' EXIT
    ${replace(coder_agent.dev.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}
    EOT
  ]

  env        = ["CODER_AGENT_TOKEN=${coder_agent.dev.token}"]
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.coder_volume.name
    read_only      = false
  }  
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
}

resource "docker_volume" "coder_volume" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
}


resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id   
  item {
    key   = "image"
    value = local.image
  }
   
}
