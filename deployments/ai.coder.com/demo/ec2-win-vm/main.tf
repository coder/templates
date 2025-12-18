terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
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
    instance_types = {
        "t3.medium" = "2 vCPU, 4 GiB RAM"
        "t3.large"  = "2 vCPU, 8 GiB RAM"
        "t3.xlarge" = "4 vCPU, 16 GiB RAM"
    }
}

data "coder_parameter" "region" {
    name         = "Region"
    description  = "Choose the location that's closest to you for the best connection!"
    mutable      = true
    order = 1
    default = "us-east-2"
    form_type = "dropdown"
    dynamic "option" {
        for_each = local.regions
        content {
            value = option.key
            name = option.value.name
            icon = option.value.icon
        }
    }
}

data "coder_parameter" "password" {
    name = "Windows Password"
    description = "Window's 'Administrator' user's password."
    mutable = false
    order = 2
    form_type = "input"
    default = "coderRDP!"
    styling = jsonencode({
        mask_input = true
    })
    # validation {
    #     regex = "([a-zA-Z]\\s){8,100}"
    # }
}

data "coder_parameter" "use_dcv_or_devolutions" {
    name         = "DCV or Devolutions?"
    description = "Choose either DCV or Devolutions Remote Desktop for connecting to your Windows workspace. True for DCV, False for Devolutions."
    type         = "bool"
    order = 3
    form_type    = "checkbox"
    default = true
}

data "coder_parameter" "instance_type" {
    name         = "Instance Type"
    description  = "What instance type should your workspace use?"
    default      = "t3.medium"
    mutable      = false
    order = 4
    form_type = "dropdown"
    dynamic "option" {
        for_each = local.instance_types
        content {
            value = option.key
            name = option.value
        }
    }
}

data "coder_parameter" "volume_size" {
    name         = "Volume Size"
    description = "Volume size of the home directory to mount."
    type         = "number"
    order = 6
    icon = "/emojis/1faa3.png"
    form_type    = "slider"
    default      = 50
    validation {
        min = 30
        max = 200
    }
}

locals {
    username = "Administrator"
    tags = {
        Name = data.coder_workspace.me.name
        Owner = data.coder_workspace_owner.me.email
    }
}

provider "aws" {
    region = data.coder_parameter.region.value
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_workspace_tags" "region" {
    tags = {
        region = data.coder_parameter.region.value
    }
}

module "rdp_desktop" {
    count      = data.coder_workspace.me.start_count
    source     = "registry.coder.com/coder/local-windows-rdp/coder"
    version    = "1.0.2"
    username  = local.username
    password = data.coder_parameter.password.value
    agent_id   = coder_agent.ec2.id
    agent_name = "ec2"
}

locals {
    use_dcv = tobool(data.coder_parameter.use_dcv_or_devolutions.value) ? 1 : 0
    use_devolutions = tobool(data.coder_parameter.use_dcv_or_devolutions.value) ? 0 : 1
}

module "dcv" {
    count          = data.coder_workspace.me.start_count * local.use_dcv
    source         = "registry.coder.com/coder/amazon-dcv-windows/coder"
    version        = "1.1.1"
    admin_password = data.coder_parameter.password.value
    agent_id       = coder_agent.ec2.id
}

module "windows_rdp" {
  count    = data.coder_workspace.me.start_count * local.use_devolutions
  source   = "registry.coder.com/coder/windows-rdp/coder"
  version  = "1.3.0"
  agent_id = coder_agent.ec2.id
}