# Managed in https://github.com/coder/templates
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

# Minimum vCPUs needed 
data "coder_parameter" "cpu" {
  name        = "CPU cores"
  type        = "number"
  description = "CPU cores for your individual workspace"
  icon        = "https://png.pngtree.com/png-clipart/20191122/original/pngtree-processor-icon-png-image_5165793.jpg"
  validation {
    min = 2
    max = 8
  }
  form_type = "input"
  mutable   = true
  default   = 4
  order     = 1
}

# Minimum GB memory needed 
data "coder_parameter" "memory" {
  name        = "Memory (__ GB)"
  type        = "number"
  description = "Memory (__ GB) for your individual workspace"
  icon        = "https://www.vhv.rs/dpng/d/33-338595_random-access-memory-logo-hd-png-download.png"
  validation {
    min = 4
    max = 16
  }
  form_type = "input"
  mutable   = true
  default   = 8
  order     = 2
}

data "coder_parameter" "disk_size" {
  name        = "PVC storage size"
  type        = "number"
  description = "Number of GB of storage for '${local.home_dir}'! This will persist after the workspace's K8s Pod is shutdown or deleted."
  icon        = "https://www.pngall.com/wp-content/uploads/5/Database-Storage-PNG-Clipart.png"
  validation {
    min       = 10
    max       = 50
    monotonic = "increasing"
  }
  form_type = "slider"
  mutable   = true
  default   = 10
  order     = 3
}

data "coder_parameter" "image" {
  name        = "Container Image"
  type        = "string"
  description = "What container image and language do you want?"
  mutable     = true
  default     = "codercom/enterprise-base:ubuntu"
  icon        = "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png"
  form_type   = "dropdown"
  option {
    name  = "Node React"
    value = "codercom/enterprise-node:latest"
    icon  = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
  option {
    name  = "Golang"
    value = "codercom/enterprise-golang:latest"
    icon  = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Go_Logo_Blue.svg/1200px-Go_Logo_Blue.svg.png"
  }
  option {
    name  = "Java"
    value = "codercom/enterprise-java:latest"
    icon  = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  }
  option {
    name  = "Base including Python"
    value = "codercom/enterprise-base:ubuntu"
    icon  = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  }
  order = 4
}

data "coder_external_auth" "github" {
  id       = "primary-github"
  optional = true
}

data "coder_parameter" "repo" {
  name        = "Source Code Repository"
  type        = "string"
  description = "What source code repository do you want to clone?"
  mutable     = true
  form_type   = "dropdown"
  default     = "https://github.com/coder-contrib/coder"
  icon        = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"

  option {
    name  = "PAC-MAN"
    value = "https://github.com/coder-contrib/pacman-nodejs"
    icon  = "https://assets.stickpng.com/images/5a18871c8d421802430d2d05.png"
  }
  option {
    name  = "Coder v2 OSS project"
    value = "https://github.com/coder-contrib/coder"
    icon  = "/icon/coder.svg"
  }
  option {
    name  = "Coder code-server project"
    value = "https://github.com/coder/code-server"
    icon  = "/icon/code.svg"
  }
  order = 5
}

data "coder_parameter" "startup-script" {
  name        = "startup_script"
  type        = "string"
  description = "Script to run on startup!"
  mutable     = contains(data.coder_workspace_owner.me.groups, "admins")
  default     = ""
  icon        = "/icon/terminal.svg"
  form_type   = "textarea"
  order       = 6
}

locals {
  home_dir        = "/home/coder"
  folder_name     = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 1), "")
  repo_owner_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 2), "")
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
  default_namespace = "coder-ws-demo"
  namespaces = {
    "coder-ws-demo" = {
      name = "coder-ws-demo"
      icon = "/emojis/1f947.png"
    }
    "coder-ws" = {
      name = "coder-ws"
      icon = "/emojis/1f948.png"
    }
    "coder-ws-experiment" = {
      name = "coder-ws-experiment"
      icon = "/emojis/1f949.png"
    }
  }
}

data "coder_parameter" "namespace" {
  count        = contains(["phorcys420", "ju-pe"], data.coder_workspace_owner.me.name) ? 1 : 0
  name         = "namespace"
  display_name = "K8s Namespace"
  description  = "Choose the namespace to deploy to (NOTE: Only admins can see this)."
  mutable      = true
  default      = local.default_namespace
  form_type    = "dropdown"
  dynamic "option" {
    for_each = local.namespaces
    content {
      value = option.key
      name  = option.value.name
      icon  = option.value.icon
    }
  }
  order = 7
}

data "coder_parameter" "location" {
  name         = "location"
  display_name = "Location"
  description  = "Choose the location that's closest to you for the best connection!"
  mutable      = true
  default      = "us-east-2"
  form_type    = "dropdown"
  dynamic "option" {
    for_each = local.regions
    content {
      value = option.key
      name  = option.value.name
      icon  = option.value.icon
    }
  }
  order = 8
}

# Provisionser Tags
data "coder_workspace_tags" "location" {
  tags = {
    region = data.coder_parameter.location.value
  }
}

resource "coder_app" "preview-pac-man" {
  count = data.coder_parameter.repo.value == "https://github.com/coder-contrib/pacman-nodejs" ? 1 : 0

  agent_id     = coder_agent.k8s-pod.id
  slug         = "pacman"
  display_name = "Play PAC-MAN"
  icon         = "https://assets.stickpng.com/images/5a18871c8d421802430d2d05.png"
  url          = "http://localhost:8080"
  tooltip      = "Click to open and play PAC-MAN!"
  share        = "owner"
  subdomain    = true
  open_in      = "slim-window"
  order        = 998
  healthcheck {
    url       = "http://localhost:8080"
    interval  = 20
    threshold = 6
  }
}