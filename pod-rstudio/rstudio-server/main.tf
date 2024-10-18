terraform {
    required_providers {
        coder = {
            source = "coder/coder"
        }
    }
}

variable "display_name" {
  type        = string
  description = "The display name for the RStudio server application."
  default     = "RStudio IDE"
}

variable "agent_id" {
    type        = string
    description = "The ID of a Coder agent."
}

variable "install_from" {
    type        = string
    description = "Base location to install RStudio from."
    default = "https://s3.amazonaws.com/rstudio-ide-build/server/jammy/amd64"
}

variable "package" {
    type        = string
    description = "RStudio package name."
    default = "rstudio-server-2024.04.2-764-amd64.deb"
}

variable "user" {
    type = string
    description = "User to run RStudio Server (server-user)"
    default = "coder"
}

variable "port" {
    type        = number
    description = "The port to run RStudio Server on."
    default     = 8787
}

variable "icon" {
    type = string
    description = "Coder app display icon."
    default = "https://upload.wikimedia.org/wikipedia/commons/d/d0/RStudio_logo_flat.svg"
}

variable "server_pid_file" {
    type = string
    description = "Absolute path to RStudio's .pid file."
    default = "/home/coder/.rstudio/rstudio-server.pid"
}

variable "server_data_dir" {
    type = string
    description = "RStudio server's data directory"
    default = "/home/coder/.rstudio/data"
}

variable "db_dir" {
    type = string
    description = "RStudio server's database directory"
    default = "/home/coder/.rstudio"
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
    default     = "rstudio-server"
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

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

resource "coder_script" "rstudio-server" {
    agent_id     = var.agent_id
    display_name = var.display_name
    icon         = var.icon
    run_on_start = true
    script = templatefile("${path.module}/run.sh", {
        RSTUDIO_PORT : var.port,
        INSTALL_FROM : var.install_from,
        RSTUDIO_PKG : var.package,
        USER: var.user,
        PID_PATH: var.server_pid_file,
        DATA_DIR: var.server_data_dir,
        DB_DIR: var.db_dir,
        CODER_USER: data.coder_workspace_owner.me.name,
        CODER_APP_NAME: var.slug,
        WORKSPACE_NAME: "${lower(data.coder_workspace.me.name)}.coder",
    })
}

resource "coder_app" "rstudio-server" {
    agent_id     = var.agent_id
    slug         = var.slug
    display_name = var.display_name
    url          = "http://localhost:${var.port}/"
    icon         = var.icon
    subdomain    = var.subdomain
    share        = var.share
    order        = var.order
}