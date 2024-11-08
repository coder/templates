terraform {
    required_providers {
        coder = {
            source = "coder/coder"
        }
        http = {
            source  = "hashicorp/http"
        }
    }
}

variable "display_name" {
  type        = string
  description = "The display name for the PyCharm server application."
  default     = "PyCharm IDE"
}

variable "folder" {
    type = string
    description = "Folder to open PyCharm into"
    default = "/home/coder"
}

variable "ide_version" {
    type = string
    description = "PyCharm IDE version."
    default = "2024.1"
}

variable "build_number" {
    type = string
    description = "PyCharm IDE build number."
    default = "241.14494.241"
}

variable "agent_id" {
    type        = string
    description = "The ID of a Coder agent."
}

variable "install_from" {
    type        = string
    description = "Base location to fetch PyCharm from."
    default = "https://download.jetbrains.com/python"
}

variable "package" {
    type        = string
    description = "PyCharm package name."
    default = "pycharm-professional-2023.1.1.tar.gz"
}

variable "port" {
    type        = number
    description = "The port to run PyCharm Server on."
    default     = 63342
}

variable "icon" {
    type = string
    description = "Coder app display icon."
    default =  "/icon/pycharm.svg"
}

variable "share" {
    type    = string
    default = "owner"
    validation {
        condition     = var.share == "owner" || var.share == "authenticated" || var.share == "public"
        error_message = "Incorrect value. Please set either 'owner', 'authenticated', or 'public'."
    }
}

variable "slug" {
    type        = string
    description = "The slug for the RStudio application."
    default     = "pycharm-server"
}

variable "subdomain" {
    type        = bool
    description = <<-EOT
        Determines whether the app will be accessed via it's own subdomain or whether it will be accessed via a path on Coder.
        If wildcards have not been setup by the administrator then apps with "subdomain" set to true will not be accessible.
    EOT
    default     = false
}

variable "order" {
    type        = number
    description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
    default     = null
}

variable "coder_parameter_order" {
  type        = number
  description = "The order determines the position of a template parameter in the UI/CLI presentation. The lowest order is shown first and parameters with equal order are sorted by name (ascending order)."
  default     = null
}

variable "default" {
  type        = string
  description = "Default IDE"
  default     = ""
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "http" "jetbrains_ide_versions" {
  url      = "https://data.services.jetbrains.com/products/releases?code=PY&latest=true&type=release"
}

resource "coder_app" "pycharm-server" {
    agent_id     = var.agent_id
    slug         = var.slug
    display_name = var.display_name
    url = join("", [
        "jetbrains-gateway://connect#type=coder&workspace=",
        data.coder_workspace.me.name,
        "&agent=",
        "coder",
        "&folder=",
        var.folder,
        "&url=",
        data.coder_workspace.me.access_url,
        "&token=",
        "$SESSION_TOKEN",
        "&ide_product_code=",
        "PY",
        "&ide_build_number=",
        var.build_number,
        "&ide_download_link=",
        "https://download.jetbrains.com/python/pycharm-professional-${var.ide_version}.tar.gz",
    ])
    icon         = var.icon
    share        = var.share
    order        = var.order
    external = true
}