---
display_name: RStudio Server Open Source
description: Add a one-click button to launch RStudio in the dashboard.
icon: ../.icons/rstudio.svg
maintainer_github: coder
verified: true
tags: [ide, rstudio, helper, parameter]
---

# RStudio Server Open Source

This module adds a RStudio button to open any workspace with a single click.

```tf
module "rstudio-server" {
  source = "./rstudio-server"
  agent_id = coder_agent.coder.id
  slug = "rstudio-server"
  display_name  = "RStudio IDE"
  subdomain = false
}
```
