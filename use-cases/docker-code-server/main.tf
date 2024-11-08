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

data "coder_parameter" "image" {
  name        = "Container Image"
  type        = "string"
  description = "What container image and language do you want?"
  mutable     = true
  default     = "codercom/enterprise-node:ubuntu"
  icon        = "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png"

  option {
    name = "Node React"
    value = "codercom/enterprise-node:ubuntu"
    icon = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
  option {
    name = "Java"
    value = "codercom/enterprise-java:ubuntu"
    icon = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  } 
  option {
    name = "Base including Python"
    value = "codercom/enterprise-base:ubuntu"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  }
  order       = 1        
}

data "coder_parameter" "repo" {
  name        = "Source Code Repository"
  type        = "string"
  description = "What source code repository do you want to clone?"
  mutable     = true
  default     = "https://github.com/coder/code-server"
  icon        = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"
  order       = 2       
}

data "coder_parameter" "extension" {
  name        = "VS Code extension"
  type        = "string"
  description = "Which VS Code extension do you want?"
  mutable     = true
  default     = "eg2.vscode-npm-script"
  icon        = "/icon/code.svg"

  option {
    name = "npm"
    value = "eg2.vscode-npm-script"
    icon = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
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
  option {
    name = "Java"
    value = "redhat.java"
    icon = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  } 
  order       = 3             
}


locals {
    folder_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 1), "")  
    repo_owner_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 2), "")
    
    registry_auth = toset([for auth in jsondecode(var.registry_auth): {
        address = lookup(auth, "address", var.default_registry)
        auth_disabled = lookup(auth, "auth_disabled", null)
        config_file = lookup(auth, "config_file", null)
        config_file_content = lookup(auth, "config_file_content", null)
        password = lookup(auth, "password", null)
        username = lookup(auth, "username", null)
    }])
}

provider "coder" {}

provider "docker" {
  host = var.socket

  dynamic "registry_auth" {
    for_each = local.registry_auth

    content {
      address = registry_auth.value["address"]
      auth_disabled = registry_auth.value["auth_disabled"]
      config_file = registry_auth.value["config_file"]
      config_file_content = registry_auth.value["config_file_content"]
      password = registry_auth.value["password"]
      username = registry_auth.value["username"]
    }
  }
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

resource "coder_agent" "dev" {
  arch           = "amd64"
  os             = "linux"

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
    vscode = true
    vscode_insiders = false
    ssh_helper = false
    port_forwarding_helper = true
    web_terminal = true
  }

  startup_script_behavior = "blocking"
  connection_timeout = 300  
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = data.coder_parameter.image.value
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"] 
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
    value = data.coder_parameter.image.value
  }
  item {
    key   = "repo cloned"
    value = "${local.repo_owner_name}/${local.folder_name}"
  }  
}