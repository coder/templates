---
display_name: Develop in Windows and VS Code on AWS EC2
description: Get started with Windows and VS Code development on AWS EC2.
icon: ../../../site/static/icon/aws.svg
maintainer_github: coder
verified: true
tags: [vm, windows, aws]
---

# Visual Studio Code IDE on a Windows VM in AWS

### Apps included

1. A web-based terminal
1. Visual Studio Code over SSH
1. Remote Desktop (RDP) w/ Visual Studio Code App

### Additional bash scripting

1. Asks for deployment region (default us-east-1)
1. Asks for instance type (default t3.micro)
1. Asks for disk size (default 30 GB)
1. Creates disk partition
1. Attaches Z-Drive
1. Installs Microsoft's VS Code for the remote desktop client only.

### Known limitations and required steps

1. `Local RDP` icon does not open your local RDP, redirects to tunneling documentation for RDP.
1. Add the Coder CLI to your local machine, login and start a tunnel for the RDP port in the workspace

```sh
coder login <your Coder deployment access URL>
coder tunnel <workspace-name> --tcp 3399:3389
```

1. [Microsoft's RDP client](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients) must be installed on the local machine to access the workspace. CoRD RDP client did not connect.
1. Create a new configuration in Microsoft's RDP client, adding 127.0.0.1:3301 as the host, `Administrator` as the username and the password `coderRDP!` and connect.

## Additional Notes

1. AWS Windows AMI's take a few minutes to startup, so hang tight.
1. Installation of VS Code and creating the partition will also add some extra time.

### Resources

[AWS Terraform provider - instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)

[Microsoft Remote Desktop (macOS)](https://apps.apple.com/us/app/microsoft-remote-desktop/id1295203466)

[AWS Regions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html)

[AWS Instance Types](https://aws.amazon.com/ec2/instance-types/)

[Coder Templates](https://github.com/coder/templates)

[Microsoft technical overview of the RDP protocol](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/understanding-remote-desktop-protocol)

[RDP on Wikipedia](https://en.wikipedia.org/wiki/Remote_Desktop_Protocol)
