# Managed in https://github.com/coder/templates
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
}

data "coder_parameter" "region" {
    name         = "region"
    display_name = "Region"
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

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "What instance type should your workspace use?"
  default      = "t3.small"
  mutable      = false
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

provider "aws" {
  region = data.coder_parameter.region.value
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "coder_agent" "main" {
    arch  = "amd64"
    auth  = "aws-instance-identity"
    os    = "windows"
}

locals {

  # User data is used to stop/start AWS instances. See:
  # https://github.com/hashicorp/terraform-provider-aws/issues/22

  user_data_start = <<-EOT
    <powershell>
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    ${coder_agent.main.init_script}
    </powershell>
    <persist>true</persist>
  EOT

  user_data_end = <<-EOT
    <powershell>
    shutdown /s
    </powershell>
    <persist>true</persist>
  EOT
}

resource "aws_instance" "dev" {
  ami               = data.aws_ami.windows.id
  instance_type     = data.coder_parameter.instance_type.value

  user_data = local.user_data_start # data.coder_workspace.me.transition == "start" ? local.user_data_start : local.user_data_end
  tags = {
    Name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    Coder_Provisioned = "true"
  }
  lifecycle {
    ignore_changes = [ami]
  }
}

locals {
  admin_password = "coderRDP!"
  admin_username = "Administrator"
}

module "rdp_desktop" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/local-windows-rdp/coder"
  version    = "1.0.2"
  agent_id   = coder_agent.main.id
  agent_name = "main"
}

module "windows_rdp" {
  count          = data.coder_workspace.me.start_count
  source = "./modules/windows_rdp"
  # source         = "registry.coder.com/coder/windows-rdp/coder"
  # version        = "1.0.18"
  agent_id       = coder_agent.main.id
  admin_username = local.admin_username
  admin_password = local.admin_password
  resource_id    = resource.aws_instance.dev.id
}

# module "dcv" {
#   count          = data.coder_workspace.me.start_count
#   source         = "registry.coder.com/coder/amazon-dcv-windows/coder"
#   version        = "1.1.0"
#   admin_password = local.admin_password
#   agent_id       = coder_agent.main.id
#   group          = "Web Desktop"
# }

# resource "coder_app" "dcv_client" {
#   count        = data.coder_workspace.me.start_count
#   agent_id     = coder_agent.main.id
#   slug         = "dcv-client"
#   display_name = "Local DCV"
#   url          = "dcv://${data.coder_workspace.me.name}.coder:${module.dcv[count.index].port}${module.dcv[count.index].web_url_path}?username=${local.admin_username}&password=${local.admin_password}"
#   icon         = "/icon/dcv.svg"
#   external     = true
#   group        = "Local Desktop"
# }


data "coder_workspace_tags" "region" {
    tags = {
        region = data.coder_parameter.region.value
    }
}

resource "coder_metadata" "login_credentials" {
  count       = data.coder_workspace.me.start_count
  resource_id = resource.aws_instance.dev.id

  item {
    key   = "username"
    value = local.admin_username
  }
  item {
    key       = "password"
    value     = local.admin_password
    sensitive = true
  }
}