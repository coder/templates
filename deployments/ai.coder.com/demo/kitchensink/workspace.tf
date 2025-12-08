resource "coder_agent" "k8s-pod" {
  os             = "linux"
  arch           = "amd64"
  startup_script = data.coder_parameter.startup-script.value
  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  display_apps {
    vscode                 = false
    vscode_insiders        = false
    ssh_helper             = true
    port_forwarding_helper = true
    web_terminal           = true
  }

  dir                     = local.home_dir
  startup_script_behavior = "blocking"
}

locals {
  # This is the init script for the main workspace container that runs before the
  # agent starts to configure workspace process logging.
  exectrace_init_script = <<EOF
    set -eu
    pidns_inum=$(readlink /proc/self/ns/pid | sed 's/[^0-9]//g')
    if [ -z "$pidns_inum" ]; then
      echo "Could not determine process ID namespace inum"
      exit 1
    fi

    # Before we start the script, does curl exist?
    if ! command -v curl >/dev/null 2>&1; then
      echo "curl is required to download the Coder binary"
      echo "Please install curl to your image and try again"
      # 127 is command not found.
      exit 127
    fi

    echo "Sending process ID namespace inum to exectrace sidecar"
    rc=0
    max_retry=5
    counter=0
    until [ $counter -ge $max_retry ]; do
      set +e
      curl \
        --fail \
        --silent \
        --connect-timeout 5 \
        -X POST \
        -H "Content-Type: text/plain" \
        --data "$pidns_inum" \
        http://127.0.0.1:56123
      rc=$?
      set -e
      if [ $rc -eq 0 ]; then
        break
      fi

      counter=$((counter+1))
      echo "Curl failed with exit code $${rc}, attempt $${counter}/$${max_retry}; Retrying in 3 seconds..."
      sleep 3
    done
    if [ $rc -ne 0 ]; then
      echo "Failed to send process ID namespace inum to exectrace sidecar"
      exit $rc
    fi

  EOF
}

locals {
  deployment_name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  deployment_labels = {
    "app.kubernetes.io/name"     = "coder-workspace"
    "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
    "app.kubernetes.io/part-of"  = "coder"
    "com.coder.resource"         = "true"
    "com.coder.workspace.id"     = data.coder_workspace.me.id
    "com.coder.workspace.name"   = data.coder_workspace.me.name
    "com.coder.user.id"          = data.coder_workspace_owner.me.id
    "com.coder.user.username"    = data.coder_workspace_owner.me.name
  }
  deployment_annotations = {
    "com.coder.user.email" = data.coder_workspace_owner.me.email
  }
}

resource "kubernetes_deployment" "main" {
  wait_for_rollout = false
  metadata {
    name        = local.deployment_name
    namespace   = "coder-ws-demo"
    labels      = local.deployment_labels
    annotations = local.deployment_annotations
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.deployment_labels
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = local.deployment_labels
      }
      spec {
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "coder-workspace"
          image             = data.coder_parameter.image.value
          image_pull_policy = "IfNotPresent"
          command = [
            "sh",
            "-c",
            join("\n\n", [
              # local.exectrace_init_script,
              coder_agent.k8s-pod.init_script
            ])
          ]
          security_context {
            run_as_user = "1000"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.k8s-pod.token
          }

          env {
            name = "GH_TOKEN"
            value = data.coder_external_auth.github.access_token
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = local.home_dir
            name       = "home-directory"
            read_only  = false
          }
        }

        # Sidecar process logging container
        # container {
        #   name              = "exectrace"
        #   image             = "ghcr.io/coder/exectrace:latest"
        #   image_pull_policy = "Always"
        #   command = [
        #     "/opt/exectrace",
        #     "--init-address", "127.0.0.1:56123",
        #     "--label", "workspace_id=${data.coder_workspace.me.id}",
        #     "--label", "workspace_name=${data.coder_workspace.me.name}",
        #     "--label", "user_id=${data.coder_workspace_owner.me.id}",
        #     "--label", "username=${data.coder_workspace_owner.me.name}",
        #     "--label", "user_email=${data.coder_workspace_owner.me.email}",
        #   ]
        #   security_context {
        #     run_as_user  = "0"
        #     run_as_group = "0"
        #     privileged   = true
        #   }
        #   #Process logging env variables
        #   env {
        #     name  = "CODER_AGENT_SUBSYSTEM"
        #     value = "exectrace"
        #   }
        # }

        volume {
          name = "home-directory"
          empty_dir {}
        }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "coder-ws"
          effect   = "NoSchedule"
        }
      }
    }
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment.main.id
  item {
    key   = "Docker Image"
    value = data.coder_parameter.image.value
  }
  item {
    key   = "Repository Cloned"
    value = "${local.repo_owner_name}/${local.folder_name}"
  }
  item {
    key   = "Region"
    value = local.regions[data.coder_parameter.location.value].name
  }
  item {
    key   = "OS"
    value = coder_agent.k8s-pod.os
  }
  item {
    key   = "Architecture"
    value = coder_agent.k8s-pod.arch
  }
  item {
    key   = "K8s Deployment Name"
    value = local.deployment_name
  }
}