data "coder_workspace_preset" "ohio-dcv" {
    name = "(Ohio) DCV"
    parameters = {
        (data.coder_parameter.region.name) = "us-east-2"
        (data.coder_parameter.use_dcv_or_devolutions.name) = true
        (data.coder_parameter.instance_type.name) = "t3.medium"
        (data.coder_parameter.volume_size.name) = 50
    }
    prebuilds {
        instances = 1
    }
}

data "coder_workspace_preset" "ohio-dev" {
    name = "(Ohio) Devolutions"
    parameters = {
        (data.coder_parameter.region.name) = "us-east-2"
        (data.coder_parameter.use_dcv_or_devolutions.name) = false
        (data.coder_parameter.instance_type.name) = "t3.medium"
        (data.coder_parameter.volume_size.name) = 50
    }
    prebuilds {
        instances = 1
    }
}
