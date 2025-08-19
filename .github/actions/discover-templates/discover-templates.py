#!/usr/bin/env python3
import os
import sys
import json
import subprocess

def git(args):
    return subprocess.check_output(["git", "--no-pager"] + args, text=True).strip()

def main():
    # Expect: <deployment_dir> <base_sha> <head_sha>
    if len(sys.argv) != 4:
        print("::error title=Usage error::discover-templates.py <deployment_dir> <base_sha> <head_sha>", file=sys.stderr)
        sys.exit(1)

    deployment = os.path.normpath(sys.argv[1])
    base_sha = sys.argv[2]
    head_sha = sys.argv[3]

    if not os.path.isdir(deployment):
        print(f"::error title=Deployment directory not found::{deployment}", file=sys.stderr)
        sys.exit(1)

    # When LIST_ALL is set, include all <org>/<template> directories under the deployment.
    list_all = os.getenv("LIST_ALL", "").strip().lower() in ("1", "true", "yes", "y", "on")

    dep_prefix = deployment.rstrip(os.sep) + os.sep
    seen = set()
    items = []

    if list_all:
        # Enumerate all templates under the deployment directory.
        for org in sorted(os.listdir(deployment)):
            org_dir = os.path.join(deployment, org)
            if not os.path.isdir(org_dir):
                continue
            for tmpl in sorted(os.listdir(org_dir)):
                tdir = os.path.join(org_dir, tmpl)
                if not os.path.isdir(tdir):
                    continue
                key = (org, tmpl, tdir)
                if key in seen:
                    continue
                seen.add(key)
                items.append({"org": org, "template": tmpl, "dir": tdir})
    else:
        # Use git diff with merge-base triple-dot. Assumes full history fetched.
        try:
            out = git(["diff", "--name-only", f"{base_sha}...{head_sha}"])
            changed_paths = [p for p in out.splitlines() if p.strip()]
        except subprocess.CalledProcessError as e:
            print(f"::error title=git diff failed::{e}", file=sys.stderr)
            sys.exit(1)

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

    if not items:
        print("::notice::No templates detected under the deployment directory", file=sys.stderr)

    # Stable ordering for determinism
    items = sorted(items, key=lambda x: (x["org"], x["template"]))

    print(json.dumps({"include": items}))

if __name__ == "__main__":
    main()