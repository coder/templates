import os
import sys
import json

def main():
  if len(sys.argv) != 2:
    print("::error title=Usage error::discover_templates.py <deployment_dir>", file=sys.stderr)
    sys.exit(1)

  deployment = sys.argv[1]
  if not os.path.isdir(deployment):
    print(f"::error title=Deployment directory not found::{deployment}", file=sys.stderr)
    sys.exit(1)

  items = []
  for organization in sorted(d for d in os.listdir(deployment) if os.path.isdir(os.path.join(deployment, d))):
    organization_dir = os.path.join(deployment, organization)
    for tmpl in sorted(d for d in os.listdir(organization_dir) if os.path.isdir(os.path.join(organization_dir, d))):
      tdir = os.path.join(organization_dir, tmpl)
      items.append({"organization": organization, "template": tmpl, "dir": tdir})

  if not items:
    print("::warning::No templates found under the deployment directory", file=sys.stderr)

  print(json.dumps({"include": items}))

if __name__ == "__main__":
    main()
