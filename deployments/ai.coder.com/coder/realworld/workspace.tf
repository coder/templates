locals {
  labels = {
    "com.coder.workspace.uuid" = random_uuid.this.result
  }
  annotations = {
    "com.coder.user.email"     = data.coder_workspace_owner.me.email
    "com.coder.workspace.id"   = data.coder_workspace.me.id
    "com.coder.workspace.name" = data.coder_workspace.me.name
    "com.coder.user.id"        = data.coder_workspace_owner.me.id
    "com.coder.user.username"  = data.coder_workspace_owner.me.name
  }
  node_selector = {
    "node.coder.io/used-for" = "coder-ws-all"
    "node.coder.io/name"     = "coder"
  }
}

resource "coder_metadata" "pod_info" {
  resource_id = try(kubernetes_deployment_v1.this[0].id, "")
  daily_cost = 1
  item {
    key   = "Workspace UUID"
    value = local.workspace_name
  }
  item {
    key   = "Location"
    value = local.regions[data.coder_parameter.location.value].name
  }
}


resource "coder_agent" "k8s-deployment" {
  arch           = "amd64"
  os             = "linux"
  dir            = "/home/coder"

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = false
  }

  metadata {
    display_name = "CPU Usage (Workspace)"
    key          = "cpu_usage"
    order        = 0
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage (Workspace)"
    key          = "ram_usage"
    order        = 1
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "cpu_usage_host"
    order        = 2
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage (Host)"
    key          = "ram_usage_host"
    order        = 3
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage (Host)"
    key          = "disk_host"
    order        = 6
    script       = "coder stat disk --path / --prefix Gi"
    interval     = 600
    timeout      = 10
  }
}

locals {
  envs = merge({
    CODER_AGENT_TOKEN = try(coder_agent.k8s-deployment.token, "")
  }, local.user_settings)
}

resource "kubernetes_deployment_v1" "this" {
  count            = data.coder_workspace.me.start_count
  wait_for_rollout = false
  metadata {
    name        = local.workspace_name
    namespace   = var.namespace
    labels      = local.labels
    annotations = local.annotations
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.labels
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels      = local.labels
        annotations = local.annotations
      }
      spec {
        node_selector                    = local.node_selector
        termination_grace_period_seconds = 0

        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "coder-ws"
          effect   = "NoSchedule"
        }

        container {
          name              = "coder"
          image             = "750246862020.dkr.ecr.us-east-2.amazonaws.com/base-ws:1.0.0"
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", join("\n", [
            try(coder_agent.k8s-deployment.init_script, "")
          ])]

          security_context {
            run_as_user                = 1000
            allow_privilege_escalation = true
            privileged                 = true
            read_only_root_filesystem  = false
          }

          resources {
            limits = {
              cpu    = "4000m"
              memory = "8Gi"
              ephemeral-storage = "25Gi"
            }
          }
          dynamic "env" {
            for_each = local.envs
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}