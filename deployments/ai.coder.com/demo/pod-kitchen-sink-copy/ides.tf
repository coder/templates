# Managed in https://github.com/coder/templates
# Web
module "code-server" {
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "1.3.1"

  group = "Web IDEs"
  order = 1
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

module "vscode-web" {
  accept_license = true
  extensions     = ["github.copilot", "ms-python.python", "ms-toolsai.jupyter", "redhat.vscode-yaml"]

  source  = "registry.coder.com/coder/vscode-web/coder"
  version = "1.3.1"

  group = "Web IDEs"
  order = 2
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

data "coder_parameter" "jupyter" {
  name        = "Jupyter IDE type"
  type        = "string"
  description = "What type of Jupyter do you want?"
  mutable     = true
  default     = ""
  icon        = "/icon/jupyter.svg"
  order       = 1 

  option {
    name = "Jupyter Lab"
    value = "lab"
    icon = "https://raw.githubusercontent.com/gist/egormkn/672764e7ce3bdaf549b62a5e70eece79/raw/559e34c690ea4765001d4ba0e715106edea7439f/jupyter-lab.svg"
  }
  option {
    name = "Jupyter Notebook"
    value = "notebook"
    icon = "https://codingbootcamps.io/wp-content/uploads/jupyter_notebook.png"
  }    
  option {
    name = "None"
    value = ""
  }       
}

# TODO: also use data.coder_workspace.me.start_count
module "jupyterlab" {
  count = data.coder_parameter.jupyter.value == "lab" ? 1 : 0

  source  = "registry.coder.com/coder/jupyterlab/coder"
  version = "1.1.1"

  group = "Web IDEs"
  order = 3
  
  agent_id = coder_agent.coder.id
}

# TODO: also use data.coder_workspace.me.start_count
module "jupyterlab-notebook" {
  count = data.coder_parameter.jupyter.value == "notebook" ? 1 : 0

  source   = "registry.coder.com/coder/jupyter-notebook/coder"
  version  = "1.2.0"

  group = "Web IDEs"
  order = 3
  
  agent_id = coder_agent.coder.id
}

# Desktop
module "vscode" {
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.1.1" 

  group = "Desktop IDEs"
  order = 1
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

module "jetbrains" {
  source   = "registry.coder.com/coder/jetbrains/coder"
  version  = "1.0.1"

  folder = "/home/coder"
  options = ["GO", "WS", "IU", "PY"]

  group = "Desktop IDEs"
  coder_app_order = 2
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

module "jetbrains_gateway" {
  source  = "registry.coder.com/coder/jetbrains-gateway/coder"
  version = "1.2.2"

  folder         = "/home/coder"
  jetbrains_ides = ["GO", "WS", "IU", "PY"]
  default        = "PY"

  group = "Desktop IDEs"
  order = 3
  
  agent_name = "coder"
  agent_id   = coder_agent.coder.id
  count      = data.coder_workspace.me.start_count
}

module "cursor" {
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.2.1"

  group = "Desktop IDEs"
  order = 4
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

module "windsurf" {
  source  = "registry.coder.com/coder/windsurf/coder"
  version = "1.1.1"

  group = "Desktop IDEs"
  order = 5
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

module "kiro" {
  source   = "registry.coder.com/coder/kiro/coder"
  version  = "1.0.0"

  group = "Desktop IDEs"
  order = 6
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}

module "zed" {
  source   = "registry.coder.com/coder/zed/coder"
  version  = "1.0.1"

  group = "Desktop IDEs"
  order = 7
  
  agent_id = coder_agent.coder.id
  count    = data.coder_workspace.me.start_count
}