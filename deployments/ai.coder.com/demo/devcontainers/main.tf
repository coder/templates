terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.5.3"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "= 2.3.7"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.95.0"
    }
  }
}

data "coder_parameter" "location" {
  name         = "location"
  display_name = "Location"
  description  = "Choose the location that's closest to you for the best connection!"
  mutable      = true
  order        = 0
  default      = "us-east-2"
  dynamic "option" {
    for_each = local.regions
    content {
      value = option.key
      name  = option.value.name
      icon  = option.value.icon
    }
  }
}

data "coder_parameter" "volume_size" {
  name         = "volume_size"
  display_name = "Volume Size"
  description  = "How big do you want your EBS root volume to be?"
  default      = 20
  order        = 1
  type         = "number"
  mutable      = true
  validation {
    min       = 20
    max       = 100
    monotonic = "increasing"
  }
}

locals {
  user        = "coder"
  home_folder = "/home/${local.user}"
  work_folder = join("/", [local.home_folder, element(split(".", element(split("/", data.coder_parameter.git-repo.value), -1)), 0)])
  repo_dir    = replace(try(module.git-clone[0].repo_dir, ""), "/^~\\//", "/home/${local.user}/")
  tags = {
    Name  = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}}"
    Owner = data.coder_workspace_owner.me.name
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "What instance type should your workspace use?"
  default      = "t3.small"
  order        = 2
  type         = "string"
  mutable      = true
  option {
    name  = "2 vCPU, 2 GiB RAM"
    value = "t3.small"
  }
  option {
    name  = "2 vCPU, 4 GiB RAM"
    value = "t3.medium"
  }
  option {
    name  = "2 vCPU, 8 GiB RAM"
    value = "t3.large"
  }
  option {
    name  = "4 vCPU, 16 GiB RAM"
    value = "t3.xlarge"
  }
}

data "coder_parameter" "enable_devcontainer_feature" {
  name         = "enable_devcontainer_feature"
  display_name = "Enable DevContainer"
  description  = "Enable Coder's experimental devcontainer feature."
  order        = 3
  type         = "bool"
  default      = false
  mutable      = false
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

data "coder_parameter" "git-repo" {
  name         = "git-url"
  display_name = "Git Repository"
  description  = "Git Repository to clone."
  mutable      = true
  default      = "https://github.com/jatcod3r/devcontainer.git"
  order        = 4
}

provider "aws" {
  region = data.coder_parameter.location.value
}

data "coder_workspace_tags" "location" {
  tags = {
    region = data.coder_parameter.location.value
  }
}

locals {
  enable_devcontainer_feature = tobool(data.coder_parameter.enable_devcontainer_feature.value) ? 1 : 0
  is_prebuild = data.coder_workspace.me.is_prebuild ? 0 : 1
}

resource "coder_devcontainer" "dev" {
  count            = local.is_prebuild * local.enable_devcontainer_feature * data.coder_workspace.me.start_count
  agent_id         = coder_agent.ec2[0].id
  workspace_folder = local.repo_dir # local.work_folder
  config_path      = join("/", [local.repo_dir, ".devcontainer", "devcontainer.json"])
  # https://github.com/coder/coder/blob/071383bbe829dd51bc863c821d1d6862ad546b2b/site/src/testHelpers/entities.ts#L4479-L4493
}

module "coder-login" {
  count    = local.is_prebuild * data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/coder-login/coder"
  version  = "1.0.15"
  agent_id = coder_agent.ec2[0].id
}

module "git-clone" {
  count    = local.is_prebuild * data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.1.0"
  url      = data.coder_parameter.git-repo.value
  agent_id = coder_agent.ec2[0].id
}

module "vscode-desktop" {
  count    = local.is_prebuild * data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.1.0"
  folder   = local.work_folder
  agent_id = coder_agent.ec2[0].id
}