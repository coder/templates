locals {
  realworld-django-port = local.port
  realworld-django = {
    (data.coder_parameter.system_prompt.name)          = templatefile("./scripts/django/SYSTEM.md", {
      PORT = local.realworld-django-port
    })
    "Preview Port"                                     = local.realworld-django-port
    (data.coder_parameter.ai_post_install_script.name) = templatefile("./scripts/django/ai_post_install.sh", {
      GH_TOKEN = var.gh_token
    })
  }
  default = {
    (data.coder_parameter.system_prompt.name)      = templatefile("./scripts/default/SYSTEM.md", {})
  }
}

data "coder_workspace_preset" "realworld-django-ohio" {
  name        = "🇺🇸 Ohio Settings"
  description = "Real World App w/ Angular + Django"
  icon        = "/icon/python.svg"
  default = true
  parameters = merge(local.realworld-django, {
    (data.coder_parameter.location.name) = "us-east-2"
  })

  prebuilds {
    instances = 1
    expiration_policy {
      ttl = 14400
    }
    scheduling {
      timezone = "UTC"

      schedule {
        cron = "* 12-23 * * 1-5" # 12PM-11PM UTC (5AM-4PM PST), turn on instances
        instances = 1
      }

      schedule {
        cron      = "* 1-11 * * *" # 2AM-11AM UTC (6PM-4AM PST), turn off instances
        instances = 0
      }
    }
  }
}