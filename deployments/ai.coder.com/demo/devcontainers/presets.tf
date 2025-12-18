locals {
  devcontainer = {
    (data.coder_parameter.volume_size.name)                 = 20
    (data.coder_parameter.instance_type.name)               = "t3.small"
    (data.coder_parameter.enable_devcontainer_feature.name) = true
  }
}

data "coder_workspace_preset" "devcontainer-ohio" {
  name        = "🇺🇸 Ohio Settings"
  description = "DevContainer Preset! Use an existing DevContainer instance for faster startups."
  icon        = "/icon/python.svg"
  default     = true
  parameters = merge(local.devcontainer, {
    (data.coder_parameter.location.name) = "us-east-2"
  })
  prebuilds {
    instances = 1
  }
}