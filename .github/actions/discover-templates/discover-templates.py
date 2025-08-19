#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import argparse
from typing import Tuple, Optional, List, Dict

def git(args: List[str]) -> str:
    return subprocess.check_output(["git", "--no-pager"] + args, text=True).strip()

def parse_template_folder(deployment: str, path: str) -> Optional[Tuple[str, str, str]]:
    # path may be absolute or relative; normalize relative to deployment
    deployment = os.path.normpath(deployment)
    path = os.path.normpath(path)
    if path != deployment and not path.startswith(deployment.rstrip(os.sep) + os.sep):
        rel = os.path.relpath(path, deployment)
    else:
        rel = os.path.relpath(path, deployment)
    parts = rel.split(os.sep)
    if len(parts) < 2:
        return None
    org, tmpl = parts[0], parts[1]
    tdir = os.path.join(deployment, org, tmpl)
    if not os.path.isdir(tdir):
        return None
    return org, tmpl, tdir

def discover_changed(deployment: str, base_sha: str, head_sha: str) -> List[Dict[str, str]]:
    try:
        out = git(["diff", "--name-only", f"{base_sha}...{head_sha}"])
        changed_paths = [p for p in out.splitlines() if p.strip()]
    except subprocess.CalledProcessError as e:
        print(f"::error title=git diff failed::{e}", file=sys.stderr)
        sys.exit(1)

    seen = set()
    items: List[Dict[str, str]] = []
    for p in changed_paths:
        parsed = parse_template_folder(deployment, p)
        if not parsed:
            continue
        org, tmpl, tdir = parsed
        key = (org, tmpl, tdir)
        if key in seen:
            continue
        seen.add(key)
        items.append({"org": org, "template": tmpl, "dir": tdir})
    return items

def list_all(deployment: str) -> List[Dict[str, str]]:
    items: List[Dict[str, str]] = []
    for org in sorted(os.listdir(deployment)):
        org_dir = os.path.join(deployment, org)
        if not os.path.isdir(org_dir):
            continue
        for tmpl in sorted(os.listdir(org_dir)):
            tdir = os.path.join(org_dir, tmpl)
            if not os.path.isdir(tdir):
                continue
            items.append({"org": org, "template": tmpl, "dir": tdir})
    return items

def parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Discover or list templates under a deployment directory")
    p.add_argument("--deployment-dir", required=True, dest="deployment_dir")
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list-all", action="store_true", dest="list_all")
    mode.add_argument("--diff", action="store_true", dest="diff")
    p.add_argument("--base", help="Base SHA for diff mode")
    p.add_argument("--head", help="Head SHA for diff mode")
    return p.parse_args(argv)

def main(argv: List[str]) -> None:
    args = parse_args(argv)
    deployment = os.path.normpath(args.deployment_dir)
    if not os.path.isdir(deployment):
        print(f"::error title=Deployment directory not found::{deployment}", file=sys.stderr)
        sys.exit(1)

    if args.list_all:
        items = list_all(deployment)
    else:
        if not args.base or not args.head:
            print("::error title=Usage error::--diff requires --base and --head", file=sys.stderr)
            sys.exit(1)
        items = discover_changed(deployment, args.base, args.head)
        if not items:
            print("::notice::No changed templates detected under the deployment directory", file=sys.stderr)

    items = sorted(items, key=lambda x: (x["org"], x["template"]))
    print(json.dumps({"include": items}))

if __name__ == "__main__":
    main(sys.argv[1:])