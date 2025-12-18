---
display_name: Windows EC2 VM
description: Deploy a Windows Server EC2 instance with RDP access
maintainer_github: jatcod3r
verified: false
tags: [vm, windows, aws, ec2]
---

# Windows EC2 VM

This template deploys a Windows Server EC2 VM to a default subnet in AWS. It is managed by [this repository](https://github.com/coder/templates) and is pushed to [ai.coder.com](https://ai.coder.com).

> [!IMPORTANT]
> If consuming this template, make sure to CHANGE the default password!

## Included in this template

This template provisions an AWS EC2 instance running Windows Server 2022 with the following features:

- Web-based terminal
- Remote Desktop via [Amazon DCV](https://registry.coder.com/modules/coder/amazon-dcv-windows) or [Devolutions](https://registry.coder.com/modules/coder/windows-rdp)
- [Local Windows RDP](https://registry.coder.com/modules/coder/local-windows-rdp) support for native RDP clients
- CPU, RAM, and disk usage monitoring

### Configurable Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| Region | AWS region (Ohio, Oregon, London) | `us-east-2` |
| Instance Type | EC2 instance size | `t3.medium` |
| Volume Size | Root volume size (30-200 GB) | `50 GB` |
| DCV or Devolutions | Remote desktop client choice | DCV |
| Windows Password | (default) Administrator password | `coderRDP!` |

### Prerequisites

- AWS credentials configured for the Coder provisioner
- Access to the default VPC and subnets in the selected region

## Known Limitations

1. AWS Windows AMIs take a few minutes to start up
2. When selecting Devolutions, `Local RDP` will redirect to tunneling documentation rather than opening your local RDP client

### Using Local RDP Client

To connect via your local RDP client:

```sh
# Install the Coder CLI and login
coder login <your Coder deployment access URL>

# Start a tunnel to the RDP port
coder tunnel <workspace-name> --tcp 3399:3389
```

Then connect using [Microsoft Remote Desktop](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients) with:
- Host: `127.0.0.1:3399`
- Username: `Administrator`
- Password: Your configured password (default: `coderRDP!`)

## Resources

- [AWS EC2 Instance Terraform Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)
- [Microsoft Remote Desktop (macOS)](https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466)
- [AWS Regions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html)
- [AWS Instance Types](https://aws.amazon.com/ec2/instance-types/)
