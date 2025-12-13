# Coder Templates Repository

> [!IMPORTANT]
> This repository contains opinionated templates and infrastructure configuration for Coder's internal demo environments.
>
> **Deployment**: This repository is designed to be deployed internally within Coder's infrastructure and is **not intended for external deployment**. However, you can reference this repository as an example of template organization, CI/CD workflows, and Terraform-based template management.
>
> **External Users**: While these templates may not be directly deployable to your environment, you can use them as reference implementations for:
> - Template structure and organization patterns
> - Terraform-based template deployment workflows
> - CI/CD integration with GitHub Actions
> - Multi-deployment template management

## Overview

This repository centralizes Coder workspace templates across multiple demo environments, providing automated deployment and version management through Terraform and GitHub Actions. It serves as a single source of truth for templates used in sales demonstrations, experiments, and internal showcases.

## Repository Structure

```
.
├── .github/
│   └── workflows/          # GitHub Actions for CI/CD
├── coder/                  # Terraform configuration for template deployment
│   ├── main.tf            # Core Terraform setup and backend configuration
│   ├── ai.coder.com.tf    # Template definitions for ai.coder.com
│   └── coderdemo.io.tf    # Template definitions for coderdemo.io
├── deployments/            # Deployment-specific template source code
│   └── <domain>/          # Organized by deployment domain
│       └── <org>/         # Organized by Coder organization
│           └── <template>/ # Individual template directories
├── modules/
│   └── template/          # Reusable Terraform module for template deployment
└── README.md
```

### Key Directories

#### `/coder`
Terraform infrastructure-as-code for managing template deployment to various Coder instances. Uses the [coderd provider](https://registry.terraform.io/providers/coder/coderd/latest) to automate template versioning, deployment, and updates.

See [coder/README.md](./coder/README.md) for detailed documentation.

#### `/deployments`
Template source code organized by deployment domain and organization:
```
deployments/<deployment-domain>/<organization-name>/<template-name>/
```

Each organization folder may contain specific guidelines for contributing templates.

#### `/modules`
Reusable Terraform modules:
- **template**: Handles template initialization, versioning, and deployment to Coder instances

## How It Works

1. **Templates are organized** in `deployments/` by domain and organization
2. **Terraform manages deployment** from the `coder/` directory using the coderd provider
3. **GitHub Actions automate** template validation and deployment on changes
4. **Versions are automatically created** with timestamps (e.g., `stable-YYYY-MM-DD_hh-mm-ss`)

## For External Users

If you're looking to learn from this repository:

- **Template Examples**: Browse `deployments/` for workspace template implementations
- **Deployment Automation**: Review `coder/` for Terraform-based template management patterns
- **CI/CD Workflows**: Check `.github/workflows/` for automation examples
- **Multi-Org Management**: See how templates are organized across multiple deployments and organizations

Keep in mind that templates in this repository are configured for Coder's specific infrastructure and may require modifications to work in your environment.

## Contributing

This repository is maintained by the Coder team for internal use. Contributions should follow the guidelines specified in each organization's deployment folder.
