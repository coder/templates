terraform {
    required_version = ">= 1.0"

    required_providers {
        coder = {
            source  = "coder/coder"
            version = ">= 0.23"
        }
    }
}

variable "agent_id" {
    type = string
}

variable "port" {
    type = number
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
    domain = element(split("/", data.coder_workspace.me.access_url), -1)
}

resource "coder_app" "preview" {
    agent_id     = var.agent_id
    slug         = "preview"
    display_name = "Preview App"
    icon         = "${data.coder_workspace.me.access_url}/emojis/1f50e.png"
    url          = "http://localhost:${var.port}"
    share        = "authenticated"
    subdomain    = true
    open_in      = "tab"
    order = 3
    healthcheck {
        url       = "http://localhost:${var.port}/"
        interval  = 5
        threshold = 15
    }
}

# Install and Initialize Claude Code
resource "coder_script" "preview_app" {
    agent_id     = var.agent_id
    display_name = "Preview App"
    icon         = "${data.coder_workspace.me.access_url}/emojis/1f50e.png"
    run_on_start = true
    script       = <<-EOT
        cat <<EOF >/tmp/index.html
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Site Status</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 960px;
                    margin: 0 auto;
                    padding: 2rem;
                    text-align: center;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    min-height: 100vh;
                }
                
                .container {
                    border: 1px solid #ddd;
                    padding: 2rem;
                    border-radius: 4px;
                    background-color: #f9f9f9;
                }
                
                h1 {
                    font-size: 1.5rem;
                    margin-bottom: 1rem;
                }
                
                p {
                    font-size: 1rem;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Site Not Ready!</h1>
                <span>Your AI Assistant probably hasn't finished building your site yet if you requested one. Refresh your browser when it tells you it's complete! Otherwise, check if it created it on a different port or failed. You can also view your app from the</span>
                <a href="https://preview--dev--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}.${local.domain}/" target=_blank><span>Preview Tasks App</span></a>
                <span>or by visiting the</span>
                <a href="https://${local.domain}/tasks/${data.coder_workspace_owner.me.name}/${data.coder_workspace.me.name}" target="_blank"><span>Tasks</span></a>
                <span>page.</span>
            </div>
        </body>
        </html>
        EOF

        cd /tmp
        python3 -m http.server ${var.port} >/dev/null 2>&1 & 
    EOT
}