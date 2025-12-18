##
# `https://ai.coder.com` Template CI/CD
## 

variable "ai_coder_com_access_url" {
  type = string
}

variable "ai_coder_com_token" {
  type      = string
  sensitive = true
}

provider "coderd" {
  alias = "ai-coder-com"
  url   = var.ai_coder_com_access_url
  token = var.ai_coder_com_token
}

data "coderd_organization" "coder" {
  provider = coderd.ai-coder-com
  name     = "coder"
}

data "coderd_organization" "experiment" {
  provider = coderd.ai-coder-com
  name     = "experiment"
}

data "coderd_organization" "demo" {
  provider = coderd.ai-coder-com
  name     = "demo"
}

# module "ai-coder-com-experiment" {
#   source = "../modules/template"
#   providers = {
#     coderd = coderd.ai-coder-com
#   }
#   access_url = var.ai_coder_com_access_url
#   token      = var.ai_coder_com_token
#   org_id     = data.coderd_organization.experiment.id
#   templates = {
#     "pod-kitchen-sink-matyas" = {
#       path         = "${path.module}/../deployments/ai.coder.com/experiment/pod-kitchen-sink-matyas"
#       description = "A universal template that includes all sorts of IDEs! Used for demo purposes only!"
#       display_name = "Matyas Universal Pod Template"
#       icon         = "/emojis/1fa90.png"
#     }
#   }
# }

# import {
#   to = module.ai-coder-com-experiment.coderd_template.this["pod-kitchen-sink-matyas"]
#   id = "experiment/pod-kitchen-sink-matyas"
# }