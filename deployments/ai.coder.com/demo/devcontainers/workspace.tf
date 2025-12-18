variable "volume_type" {
  type    = string
  default = "gp3"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical AWS-owned Account
}

resource "coder_agent" "ec2" {
  count = data.coder_workspace.me.start_count
  arch = "amd64"
  auth = "aws-instance-identity"
  os   = "linux"
  dir  = local.home_folder
  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = false
  }
}

resource "coder_agent_instance" "dev" {
  count       = data.coder_workspace.me.start_count
  agent_id    = coder_agent.ec2[0].id
  instance_id = aws_instance.dev.id
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  boundary = "//"
  
  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init/cloud-config.yaml", {
      user = local.user
    })
  }
  part {
    filename     = "coder-agent.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/cloud-init/coder-agent.sh", {
      user                        = local.user
      enable_devcontainer_feature = "true"
      init_script                 = try(coder_agent.ec2[0].init_script, "")
    })
  }
}

resource "coder_script" "install" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.ec2[0].id
  display_name       = "Install Packages"
  icon               = "/icon/ubuntu.svg"
  run_on_start       = true
  start_blocks_login = true
  script             = templatefile("${path.module}/coder-scripts/install.sh", {})
}

resource "aws_instance" "dev" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = data.coder_parameter.instance_type.value

  user_data_base64 = base64encode(data.cloudinit_config.user_data.rendered)
  iam_instance_profile = "SsmManagerConnect_DELETE_LATER"
  
  root_block_device {
    volume_size           = data.coder_parameter.volume_size.value
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    instance_metadata_tags = "enabled"
    http_put_response_hop_limit = 1
  }

  tags = local.tags

  # Prevent sudden replacements due to AMI updates.
  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}

resource "aws_ec2_instance_state" "dev" {
  instance_id = aws_instance.dev.id
  state       = data.coder_workspace.me.start_count != 0 ? "running" : "stopped"
}