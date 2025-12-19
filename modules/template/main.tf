terraform {
    required_providers {
        coderd = {
            source = "coder/coderd"
        }
        null = {
            source = "hashicorp/null"
        }
        time = {
            source = "hashicorp/time"
        }
    }
}

variable "org_id" {
    type = string   
}

variable "access_url" {
    type = string
}

variable "token" {
    type = string   
    sensitive = true
}

variable "templates" {
    type = map(object({
        path        = string
        display_name = optional(string, "")
        icon        = optional(string, "")
        description = optional(string, "")
        platform = optional(string, "linux_amd64")
    }))
}

locals {
    env = {
        CODER_SESSION_TOKEN = nonsensitive(var.token)
        CODER_URL = var.access_url
    }
}

data "archive_file" "init" {
  for_each = var.templates
  type        = "zip"
  excludes    = ["${each.value.path}/.terraform"]
  source_dir = each.value.path
  output_path = "/tmp/${each.key}.zip"
}

# Initialize template & lockfile to ensure consistency
resource "null_resource" "upgrade-and-init" {
    for_each = var.templates
    triggers = {
        # Ensure that modules are always re-initialized when checksum changes.
        run_on_checksum = "${data.archive_file.init[each.key].id}" 
    }
    provisioner "local-exec" {
        working_dir = each.value.path
        command = "terraform init -upgrade && terraform providers lock -platform=${each.value.platform}"
        environment = local.env
    }
}

resource "time_static" "this" {
    for_each = var.templates
    triggers = {
        # Ensure that modules are always re-initialized when checksum changes.
        run_on_checksum = "${data.archive_file.init[each.key].id}" 
    }
}

resource "coderd_template" "this" {
    for_each = var.templates
    depends_on = [ null_resource.upgrade-and-init ]
    organization_id = var.org_id
    name = each.key
    display_name = each.value.display_name == "" ? each.key : each.value.display_name
    icon = each.value.icon
    description = each.value.description
    # At least 1 template must be stable. 
    # We'll keep track of this via Terraform.
    versions = [{
        name        = "stable-${formatdate("YYYY-MM-DD_hh-mm-ss", time_static.this[each.key].rfc3339)}"
        description = "Stable Version."
        directory   = each.value.path
        active = true
    }]
}

# Intentionally remove all access once. 
# Owners should manually set to avoid accidental exposure. 
# Will not re-run unless template is replaced.
resource "null_resource" "remove-public-access" {
    for_each = var.templates
    triggers = {
        template_id = coderd_template.this[each.key].id
    }
    provisioner "local-exec" {
        working_dir = each.value.path
        command = "coder templates edit --private -O ${var.org_id} ${each.key}"
        environment = local.env
    }
}