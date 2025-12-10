locals {
  memory-card-port = 5173
  memory-card = {
    (data.coder_parameter.system_prompt.name) = templatefile("./scripts/memory-card/SYSTEM.md", {
      PORT = local.memory-card-port
    })
    "Preview Port"                                 = local.memory-card-port
    (data.coder_parameter.ai_post_install_script.name) = templatefile("./scripts/memory-card/ai_post_install.sh", {
      GH_TOKEN = var.gh_token
    })
    (data.coder_parameter.use_bots_git_creds.name) = true
  }
}

data "coder_workspace_preset" "memory-card-ohio" {
  name        = "🇺🇸 Ohio Settings"
  description = "Work on a Memory Card Game Using AI"
  icon        = "/icon/python.svg"
  default     = true
  parameters = merge(local.memory-card, {
    (data.coder_parameter.location.name) = "us-east-2"
  })
}