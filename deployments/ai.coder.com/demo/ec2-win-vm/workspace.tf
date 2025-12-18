variable "start_cold" {
    type = bool
    default = true
}

data "aws_region" "current" {}

data "aws_ami" "windows" {
    most_recent = true
    owners      = ["amazon"]
    filter {
        name   = "name"
        values = ["Windows_Server-2022-English-Full-Base-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    filter {
        name   = "architecture"
        values = ["x86_64"]
    }
}

data "aws_subnets" "available" {
    filter {
        name   = "availability-zone"
        values = [ "${data.coder_parameter.region.value}c" ]
    }
}

data "aws_subnet" "selected" {
    depends_on = [ data.aws_subnets.available ]
    id = data.aws_subnets.available.ids[0]
}

resource "aws_security_group" "this" {
    vpc_id      = data.aws_subnet.selected.vpc_id
    description = "SG for Windows-based workspaces"
    tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
    security_group_id = aws_security_group.this.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = -1
}

locals {
    ami_id = data.aws_ami.this.id
    az_id = "a" # Default. Switch according to region.
    availability_zone = "${data.aws_region.current.region}${local.az_id}"
}

resource "coder_metadata" "login_credentials" {
    count       = data.coder_workspace.me.start_count
    resource_id = aws_instance.this.arn
    item {
        key   = "username"
        value = local.username
    }
    item {
        key       = "password"
        value     = data.coder_parameter.password.value
        sensitive = true
    }
}

data "aws_ami" "this" {
    most_recent      = true
    owners           = ["amazon"]
    filter {
        name   = "name"
        values = ["Windows_Server-*-English-Full-Base-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    filter {
        name   = "architecture"
        values = ["x86_64"]
    }
}

resource "coder_agent" "ec2" {
    arch = "amd64"
    os = "windows"
    auth = "aws-instance-identity"

    display_apps {
        vscode          = false
        vscode_insiders = false
        web_terminal    = true
        ssh_helper      = false
    }

  metadata {
        display_name = "CPU Usage"
        key          = "cpu_usage"
        order        = 1
        script       = "& \"$env:TEMP\\sshd.exe\" stat cpu"
        interval     = 10
        timeout      = 30
  }

  metadata {
        display_name = "RAM Usage"
        key          = "ram_usage"
        order        = 2
        script       = "& \"$env:TEMP\\sshd.exe\" stat mem"
        interval     = 10
        timeout      = 30
  }

  metadata {
        display_name = "C:\\\\ Disk Usage"
        key          = "disk_usage_c"
        order        = 3
        script       = "& \"$env:TEMP\\sshd.exe\" stat disk --path C:"
        interval     = 600
        timeout      = 10
  }

}

resource "aws_instance" "this" {
    ami                         = local.ami_id
    instance_type               = data.coder_parameter.instance_type.value
    subnet_id                   = data.aws_subnets.available.ids[0]
    availability_zone           = data.aws_subnets.available.ids[0] == "" ? local.availability_zone : null
    associate_public_ip_address = false
    vpc_security_group_ids      = [ aws_security_group.this.id ]
    iam_instance_profile        = null
    ebs_optimized               = true
    monitoring                  = true

    user_data = <<-EOF
        <powershell>
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        ${coder_agent.ec2.init_script}
        </powershell>
        <persist>true</persist>
    EOF

    root_block_device {
        volume_size = data.coder_parameter.volume_size.value
        volume_type = "gp3"
        delete_on_termination = true
    }

    metadata_options {
        instance_metadata_tags = "enabled"
        http_tokens = "required"
    }

    lifecycle {
        ignore_changes = [ ami ]
    }

    tags = local.tags
}

resource "coder_agent_instance" "this" {
    agent_id    = coder_agent.ec2.id
    instance_id = aws_instance.this.id
}

resource "aws_ec2_instance_state" "this" {
    instance_id = aws_instance.this.id
    state       = (var.start_cold && data.coder_workspace.me.is_prebuild) ? "stopped" : data.coder_workspace.me.start_count != 0 ? "running" : "stopped"
}