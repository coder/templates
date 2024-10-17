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

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_parameter" "lang" {
  name        = "Programming Language"
  type        = "string"
  description = "What container image and language do you want?"
  mutable     = true
  default     = "Java"
  icon        = "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png"

  option {
    name = "Node"
    value = "Node"
    icon = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
  option {
    name = "Go"
    value = "Go"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Go_Logo_Blue.svg/1200px-Go_Logo_Blue.svg.png"
  } 
  option {
    name = "Java"
    value = "Java"
    icon = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  } 
  option {
    name = "Python"
    value = "Python"
    icon = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  } 
  order       = 1       
}

data "coder_parameter" "dotfiles_url" {
  name        = "Dotfiles URL (optional)"
  description = "Personalize your workspace e.g., https://github.com/coder/example-dotfiles.git"
  type        = "string"
  default     = ""
  mutable     = true 
  icon        = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.png"
  order       = 2
}

locals {
    repo = {
      "Node"    = "coder/coder-react.git"
      "Java"    = "coder/java_helloworld.git" 
      "Python"  = "coder/python_commissions.git" 
      "Go"      = "coder/go_helloworld.git"
    }  
    image = {
      "Node"    = "codercom/enterprise-node:latest"
      "Java"    = "codercom/enterprise-java:latest" 
      "Go"      = "codercom/enterprise-golang:latest"
      "Python"  = "codercom/enterprise-base:ubuntu" 
    }    

    registry_auth = toset([for auth in jsondecode(var.registry_auth): {
        address = lookup(auth, "address", var.default_registry)
        auth_disabled = lookup(auth, "auth_disabled", null)
        config_file = lookup(auth, "config_file", null)
        config_file_content = lookup(auth, "config_file_content", null)
        password = lookup(auth, "password", null)
        username = lookup(auth, "username", null)
    }])
}

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

provider "coder" {}

module "jetbrains_gateway" {
  source         = "https://registry.coder.com/modules/jetbrains-gateway"
  agent_id       = coder_agent.dev.id
  agent_name     = "dev"
  folder         = "/home/coder"
  jetbrains_ides = ["GO", "WS", "IU", "PY"]
  default        = "IU"
}

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/code-server/coder"
  version  = "1.0.18"
  agent_id = coder_agent.dev.id
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
  url      = "https://github.com/${lookup(local.repo, data.coder_parameter.lang.value)}"
}

resource "coder_agent" "dev" {
  os   = "linux"
  arch = "amd64"

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
    port_forwarding_helper = true
    web_terminal = true
  }

  dir = "/home/coder"
  startup_script_behavior = "blocking"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = "${lookup(local.image, data.coder_parameter.lang.value)}"
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"]

  entrypoint = ["sh", "-c", replace(coder_agent.dev.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

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
    key   = "dockerhub-image"
    value = "${lookup(local.image, data.coder_parameter.lang.value)}"
  }     
  item {
    key   = "language"
    value = data.coder_parameter.lang.value
  }   
}
