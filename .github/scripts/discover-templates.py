#!/usr/bin/env python3
import os
import sys
import json
import subprocess

def git(args):
    return subprocess.check_output(["git", "--no-pager"] + args, text=True).strip()

def discover_all_templates(deployment):
    """Discover all templates in the deployment directory."""
    if not os.path.isdir(deployment):
        print(f"::error title=Deployment directory not found::{deployment}", file=sys.stderr)
        sys.exit(1)
    
    items = []
    
    # Walk through deployment/<org>/<template> structure
    for org in os.listdir(deployment):
        org_path = os.path.join(deployment, org)
        if not os.path.isdir(org_path):
            continue
            
        for tmpl in os.listdir(org_path):
            tdir = os.path.join(org_path, tmpl)
            if not os.path.isdir(tdir):
                continue
                
            items.append({"org": org, "template": tmpl, "dir": tdir})
    
    return items

def discover_changed_templates(deployment, base_sha, head_sha):
    """Discover only changed templates between two commits."""
    if not os.path.isdir(deployment):
        print(f"::error title=Deployment directory not found::{deployment}", file=sys.stderr)
        sys.exit(1)

    # Use git diff with merge-base triple-dot. Assumes full history fetched.
    try:
        out = git(["diff", "--name-only", f"{base_sha}...{head_sha}"])
        changed_paths = [p for p in out.splitlines() if p.strip()]
    except subprocess.CalledProcessError as e:
        print(f"::error title=git diff failed::{e}", file=sys.stderr)
        sys.exit(1)

    dep_prefix = deployment.rstrip(os.sep) + os.sep
    seen = set()
    items = []

    for p in changed_paths:
        norm = os.path.normpath(p)
        if norm != deployment and not norm.startswith(dep_prefix):
            continue
        rel = os.path.relpath(norm, deployment)
        parts = rel.split(os.sep)
        if len(parts) < 2:
            continue
        org, tmpl = parts[0], parts[1]
        tdir = os.path.join(deployment, org, tmpl)
        if not os.path.isdir(tdir):
            continue
        key = (org, tmpl, tdir)
        if key in seen:
            continue
        seen.add(key)
        items.append({"org": org, "template": tmpl, "dir": tdir})
    
    return items

def main():
    # Support both: <deployment_dir> --all and <deployment_dir> <base_sha> <head_sha>
    if len(sys.argv) == 3 and sys.argv[2] == "--all":
        deployment = os.path.normpath(sys.argv[1])
        items = discover_all_templates(deployment)
        print(f"::notice::Discovered {len(items)} templates in deployment directory", file=sys.stderr)
    elif len(sys.argv) == 4:
        deployment = os.path.normpath(sys.argv[1])
        base_sha = sys.argv[2]
        head_sha = sys.argv[3]
        items = discover_changed_templates(deployment, base_sha, head_sha)
        if not items:
            print("::notice::No changed templates detected under the deployment directory", file=sys.stderr)
    else:
        print("::error title=Usage error::discover-templates.py <deployment_dir> --all OR <deployment_dir> <base_sha> <head_sha>", file=sys.stderr)
        sys.exit(1)

    print(json.dumps({"include": items}))

if __name__ == "__main__":
    main()