##
# `https://coderdemo.io` Template CI/CD
## 

variable "coderdemo_io_access_url" {
  type = string
}

variable "coderdemo_io_token" {
  type      = string
  sensitive = true
}

provider "coderd" {
  alias = "coderdemo-io"
  url   = var.coderdemo_io_access_url
  token = var.coderdemo_io_token
}