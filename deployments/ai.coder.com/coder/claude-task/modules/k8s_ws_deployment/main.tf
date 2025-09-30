terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    coder = {
      source = "coder/coder"
    }
  }
}

variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "wait_for_rollout" {
  type    = bool
  default = false
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "node_selector" {
  type    = map(string)
  default = {}
}

variable "tolerations" {
  type = list(object({
    key      = string
    operator = optional(string, "Equal")
    value    = string
    effect   = optional(string, "NoSchedule")
  }))
  default = []
}

variable "termination_grace_period_seconds" {
  type    = number
  default = 0
}

variable "topology_spread_constraints" {
  type = list(object({
    max_skew           = optional(number, 1)
    topology_key       = optional(string, "kubernetes.io/hostname")
    node_taints_policy = optional(string, "Honor")
    when_unsatisfiable = optional(string, "DoNotSchedule")
    label_selector = optional(list(object({
      match_labels = optional(map(string), {})
    })), [])
  }))
  default = []
}

variable "container_image" {
  type    = string
  default = "codercom/enterprise-base:ubuntu"
}

variable "container_name" {
  type    = string
  default = "coder"
}

variable "container_image_pull_policy" {
  type    = string
  default = "Always"

  validation {
    condition     = contains(["IfNotPresent", "Always", "Never"], var.container_image_pull_policy)
    error_message = "'container_image_pull_policy' must be either 'IfNotPresent', 'Always', or 'Never'"
  }
}

variable "container_architecture" {
  type    = string
  default = "amd64"

  validation {
    condition     = contains(["amd64", "arm64", "armv7"], var.container_architecture)
    error_message = "'container_architecture' must be either 'amd64', 'arm64', or 'armv7'"
  }
}

variable "container_os" {
  type    = string
  default = "linux"

  validation {
    condition     = contains(["linux", "darwin", "windows"], var.container_os)
    error_message = "'container_os' must be either 'linux', 'darwin', or 'windows'"
  }
}

variable "envs" {
  type    = map(string)
  default = {}
}

variable "envs_secret" {
  type = map(object({
    name = string
    key  = string
  }))
  default = {}
}

variable "cpu" {
  type        = number
  description = "CPU in m."
  default     = 250
}

variable "memory" {
  type        = number
  description = "Memory in GB."
  default     = 1
}

variable "user_id" {
  type    = number
  default = 1000
}

variable "fs_gid" {
  type    = number
  default = 1000
}

variable "allow_privilege_escalation" {
  type    = bool
  default = false
}

variable "read_only_root_filesystem" {
  type    = bool
  default = false
}

variable "privileged" {
  type    = bool
  default = false
}

variable "deployment_strategy" {
  type    = string
  default = "Recreate"
}

variable "add_dind_sidecar" {
  type    = bool
  default = false
}

variable "pre_command" {
  type        = string
  description = "Command(s) to run before the Coder initialization script."
  default     = ""
}

variable "post_command" {
  type        = string
  description = "Command(s) to run after the Coder initialization script."
  default     = ""
}

variable "attach_volume" {
  type    = bool
  default = false
}

variable "home_mount_path" {
  type    = string
  default = "/home/coder"
}

variable "pvc_access_mode" {
  type    = string
  default = "ReadWriteOnce"
}

variable "pvc_storage_size" {
  type    = number
  default = 10
}

variable "show_builtin_vscode" {
  type    = bool
  default = false
}

variable "show_builtin_vscode_insiders" {
  type    = bool
  default = false
}

variable "show_builtin_web_terminal" {
  type    = bool
  default = true
}

variable "show_builtin_ssh_helper" {
  type    = bool
  default = false
}

variable "coder_agent_startup_script" {
  type    = string
  default = ""
}

variable "memory_monitoring" {
  type = object({
    threshold = optional(number, 80)
  })
  default = {}
}

variable "volume_monitoring" {
  type = object({
    threshold = optional(number, 80)
    path      = optional(string, "")
  })
  default = {}
}

variable "metadata_blocks" {
  type = list(object({
    display_name = string
    key          = string
    order        = optional(number, 1)
    script       = string
    interval     = optional(number, 10)
    timeout      = optional(number, 1)
  }))
  default = []
}

data "coder_workspace" "me" {}

resource "coder_agent" "pod-agent" {
  arch           = var.container_architecture
  os             = var.container_os
  startup_script = var.coder_agent_startup_script

  display_apps {
    vscode          = var.show_builtin_vscode
    vscode_insiders = var.show_builtin_vscode_insiders
    web_terminal    = var.show_builtin_web_terminal
    ssh_helper      = var.show_builtin_ssh_helper
  }

  dynamic "metadata" {
    for_each = var.metadata_blocks
    content {
      display_name = metadata.value.display_name
      key          = metadata.value.key
      order        = metadata.value.order
      script       = metadata.value.script
      interval     = metadata.value.interval
      timeout      = metadata.value.timeout
    }
  }

  dynamic "resources_monitoring" {
    for_each = var.volume_monitoring != {} || var.memory_monitoring != {} ? [1] : []
    content {
      dynamic "memory" {
        for_each = var.memory_monitoring != {} ? [1] : []
        content {
          enabled   = true
          threshold = var.memory_monitoring.threshold
        }
      }
      dynamic "volume" {
        for_each = var.volume_monitoring != {} ? [1] : []
        content {
          enabled   = true
          threshold = local.volume_monitoring.threshold
          path      = local.volume_monitoring.path
        }
      }
    }
  }
}

locals {
  envs = merge({
    CODER_AGENT_TOKEN = try(coder_agent.pod-agent.token, "")
  }, var.add_dind_sidecar ? { DOCKER_HOST = "localhost:2375" } : {}, var.envs)
  envs_secret = merge({}, var.envs_secret)
  command = ["sh", "-c", join("\n", [
    var.pre_command,
    try(coder_agent.pod-agent.init_script, ""),
    var.post_command
  ])]
  volume_monitoring = try(var.volume_monitoring.path, false) == "" ? {
    threshold = var.volume_monitoring.threshold
    path      = var.home_mount_path
  } : var.volume_monitoring
}

resource "kubernetes_persistent_volume_claim" "home" {
  count = var.attach_volume ? 1 : 0
  metadata {
    name        = var.name
    namespace   = var.namespace
    labels      = var.labels
    annotations = var.annotations
  }
  wait_until_bound = false
  spec {
    access_modes = [var.pvc_access_mode]
    resources {
      requests = {
        storage = "${var.pvc_storage_size}Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "this" {
  count            = data.coder_workspace.me.start_count
  depends_on       = [kubernetes_persistent_volume_claim.home]
  wait_for_rollout = false
  metadata {
    name        = var.name
    namespace   = var.namespace
    labels      = var.labels
    annotations = var.annotations
  }
  spec {
    replicas = var.replica_count
    selector {
      match_labels = var.labels
    }
    strategy {
      type = var.deployment_strategy
    }
    template {
      metadata {
        labels      = var.labels
        annotations = var.annotations
      }
      spec {
        node_selector                    = var.node_selector
        termination_grace_period_seconds = var.termination_grace_period_seconds

        dynamic "toleration" {
          for_each = var.tolerations
          content {
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
            effect   = toleration.value.effect
          }
        }

        dynamic "topology_spread_constraint" {
          for_each = var.topology_spread_constraints
          content {
            max_skew           = topology_spread_constraint.value.max_skew
            topology_key       = topology_spread_constraint.value.topology_key
            node_taints_policy = topology_spread_constraint.value.node_taints_policy
            when_unsatisfiable = topology_spread_constraint.value.when_unsatisfiable
            dynamic "label_selector" {
              for_each = topology_spread_constraint.value.label_selector
              content {
                match_labels = label_selector.value.match_labels
              }
            }
          }
        }

        security_context {
          run_as_user = var.user_id
          fs_group    = var.fs_gid
        }

        dynamic "init_container" {
          for_each = var.attach_volume ? [1] : []
          content {
            name              = "copy-to-mount"
            image             = var.container_image
            image_pull_policy = var.container_image_pull_policy
            command           = ["cp", "-an", "${var.home_mount_path}/.", "/opt/data"]
            security_context {
              run_as_user                = 0
              allow_privilege_escalation = true
              privileged                 = true
            }
            resources {
              limits = {
                cpu    = "250m"
                memory = "250Mi"
              }
            }
            volume_mount {
              mount_path = "/opt/data"
              name       = "home"
              read_only  = false
            }
          }
        }

        dynamic "container" {
          for_each = var.add_dind_sidecar ? [1] : []
          content {
            name              = "docker"
            image             = "docker:dind"
            image_pull_policy = "IfNotPresent"
            command           = ["dockerd", "-H", "tcp://127.0.0.1:2375"]
            security_context {
              run_as_user                = 0
              allow_privilege_escalation = true
              privileged                 = true
            }
            env {
              name  = "DOCKER_HOST"
              value = "localhost:2375"
            }
            resources {
              limits = {
                cpu               = "1000m"
                memory            = "2Gi"
                ephemeral-storage = "10Gi"
              }
            }
          }
        }

        container {
          name              = var.container_name
          image             = var.container_image
          image_pull_policy = var.container_image_pull_policy
          command           = local.command
          security_context {
            run_as_user                = var.user_id
            allow_privilege_escalation = var.allow_privilege_escalation
            privileged                 = var.privileged
            read_only_root_filesystem  = var.read_only_root_filesystem
          }
          resources {
            limits = {
              cpu    = "${var.cpu}m"
              memory = "${var.memory}Gi"
            }
          }
          dynamic "env" {
            for_each = local.envs
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "env" {
            for_each = local.envs_secret
            content {
              name = env.key
              value_from {
                secret_key_ref {
                  name = env.value.name
                  key  = env.value.key
                }
              }
            }
          }
          dynamic "volume_mount" {
            for_each = var.attach_volume ? [1] : []
            content {
              mount_path = var.home_mount_path
              name       = "home"
              read_only  = false
            }
          }
        }
        dynamic "volume" {
          for_each = var.attach_volume ? [1] : []
          content {
            name = "home"
            persistent_volume_claim {
              claim_name = var.name
              read_only  = false
            }
          }
        }
      }
    }
  }
}

output "agent_id" {
  value = coder_agent.pod-agent.id
}

output "agent_name" {
  value = "pod-agent" # This is not referrable, statically set based on the coder_agent's resource name.
}

output "id" {
  value = try(kubernetes_deployment.this[0].id, "")
}