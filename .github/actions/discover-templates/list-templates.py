#!/usr/bin/env python3
import os
import sys
import json

def main():
    if len(sys.argv) != 2:
        print("::error title=Usage error::list-templates.py <deployment_dir>", file=sys.stderr)
        sys.exit(1)

    deployment = os.path.normpath(sys.argv[1])
    if not os.path.isdir(deployment):
        print(f"::error title=Deployment directory not found::{deployment}", file=sys.stderr)
        sys.exit(1)

    items = []
    for org in sorted(os.listdir(deployment)):
        org_dir = os.path.join(deployment, org)
        if not os.path.isdir(org_dir):
            continue
        for tmpl in sorted(os.listdir(org_dir)):
            tdir = os.path.join(org_dir, tmpl)
            if not os.path.isdir(tdir):
                continue
            items.append({"org": org, "template": tmpl, "dir": tdir})

    items = sorted(items, key=lambda x: (x["org"], x["template"]))
    print(json.dumps({"include": items}))

if __name__ == "__main__":
    main()
