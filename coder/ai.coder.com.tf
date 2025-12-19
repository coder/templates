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

module "ai-coder-com-demo" {
  source = "../modules/template"
  providers = {
    coderd = coderd.ai-coder-com
  }
  access_url = var.ai_coder_com_access_url
  token      = var.ai_coder_com_token
  org_id     = data.coderd_organization.demo.id
  templates = {
    "claude-runner" = {
      path         = "${path.module}/../deployments/ai.coder.com/demo/claude-runner"
      description = "Nicky's Claude Runner for AI demos!"
      display_name = "Claude Runner for AI"
      icon         = "https://upload.wikimedia.org/wikipedia/commons/archive/f/fb/20210729021607%21Adobe_Illustrator_CC_icon.svg"
    }
    "claude-runner-java21" = {
      path         = "${path.module}/../deployments/ai.coder.com/demo/claude-runner-java21"
      description = "Nicky's Claude Runner Java 21 for AI demos!"
      display_name = "Claude Runner Java 21"
      icon         = "/icon/java.svg"
    }
    "coder-selenium-demo" = {
      path         = "${path.module}/../deployments/ai.coder.com/demo/coder-selenium-demo"
      description = "This template was created to demo automated Selenium testing inside a workspace"
      display_name = "Coder Selenium Demo"
      icon         = "https://upload.wikimedia.org/wikipedia/commons/d/d5/Selenium_Logo.png"
    }
    "devcontainers" = {
      path         = "${path.module}/../deployments/ai.coder.com/demo/devcontainers"
      description = "Deploy's an EC2 instance that auto-installs Docker, NPM, and @devcontainers/cli. You can also use this w/ VSCode's devcontainer"
      display_name = "DevContainers on EC2"
      icon         = "https://www.svgrepo.com/show/373550/devcontainer.svg"
    }
    "kitchensink" = {
      path         = "${path.module}/../deployments/ai.coder.com/demo/kitchensink"
      description = "A universal template that includes all sorts of IDEs!"
      display_name = "Universal Workspace"
      icon         = "/emojis/1fa90.png"
    }
    "ec2-win-vm" = {
      path         = "${path.module}/../deployments/ai.coder.com/demo/ec2-win-vm"
      description = "Work on a Windows VM on AWS EC2!"
      display_name = "Windows - AWS EC2"
      icon         = "/icon/windows.svg"
    }
  }
}