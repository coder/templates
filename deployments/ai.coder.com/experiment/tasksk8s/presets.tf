locals {
  realworld-django = {
    (data.coder_parameter.repo.name)                   = "https://github.com/coder-contrib/realworld-django-rest-framework-angular"
    (data.coder_parameter.ai_prompt.name)              = templatefile("./scripts/django/TASK.md", {})
    (data.coder_parameter.system_prompt.name)          = templatefile("./scripts/django/SYSTEM.md", {})
    (data.coder_parameter.enable_preview_app.name)     = true
    "Preview Port"                                     = 4200
    (data.coder_parameter.ai_post_install_script.name) = templatefile("./scripts/django/ai_post_install.sh", {})
  }
  default = {
    (data.coder_parameter.system_prompt.name)      = templatefile("./scripts/default/SYSTEM.md", {})
    (data.coder_parameter.enable_preview_app.name) = false
  }
}

data "coder_workspace_preset" "default-ohio" {
  name        = "0. (Ohio 🇺🇸) Default"
  description = "Coder Tasks"
  icon        = "/icon/python.svg"
  default     = true
  parameters = merge(local.default, {
    (data.coder_parameter.location.name) = "us-east-2"
  })

  prebuilds {
    instances = 0
    expiration_policy {
      ttl = 14400
    }
    scheduling {
      timezone = "UTC"

      schedule {
        cron = "* 12-23 * * 1-5" # 12PM-11PM UTC (5AM-4PM PST), turn on instances
        instances = 0
      }

      schedule {
        cron      = "* 1-11 * * *" # 2AM-11AM UTC (6PM-4AM PST), turn off instances
        instances = 0
      }
    }
  }
}

data "coder_workspace_preset" "default-oregon" {
  name        = "1. (Oregon 🇺🇸) Default"
  description = "Coder Tasks"
  icon        = "/icon/python.svg"
  default     = false
  parameters = merge(local.default, {
    (data.coder_parameter.location.name) = "us-west-2"
  })
}

data "coder_workspace_preset" "default-london" {
  name        = "2. (London 🇬🇧) Default"
  description = "Coder Tasks"
  icon        = "/icon/python.svg"
  default     = false
  parameters = merge(local.default, {
    (data.coder_parameter.location.name) = "eu-west-2"
  })
}

data "coder_workspace_preset" "realworld-django-ohio" {
  name        = "3. (Ohio 🇺🇸) Django REST Framework w/ Angular"
  description = "Real World App w/ Angular + Django"
  icon        = "/icon/python.svg"
  parameters = merge(local.realworld-django, {
    (data.coder_parameter.location.name) = "us-east-2"
  })

  prebuilds {
    instances = 0
    expiration_policy {
      ttl = 14400
    }
    scheduling {
      timezone = "UTC"

      schedule {
        cron = "* 12-23 * * 1-5" # 12PM-11PM UTC (5AM-4PM PST), turn on instances
        instances = 0
      }

      schedule {
        cron      = "* 1-11 * * *" # 2AM-11AM UTC (6PM-4AM PST), turn off instances
        instances = 0
      }
    }
  }
}

data "coder_workspace_preset" "realworld-django-oregon" {
  name        = "4. (Oregon 🇺🇸) Django REST Framework w/ Angular"
  description = "Real World App w/ Angular + Django"
  icon        = "/icon/python.svg"
  parameters = merge(local.realworld-django, {
    (data.coder_parameter.location.name) = "us-west-2"
  })
}

data "coder_workspace_preset" "realworld-django-london" {
  name        = "5. (London 🇬🇧) Django REST Framework w/ Angular"
  description = "Real World App w/ Angular + Django"
  icon        = "/icon/python.svg"
  parameters = merge(local.realworld-django, {
    (data.coder_parameter.location.name) = "eu-west-2"
  })
}