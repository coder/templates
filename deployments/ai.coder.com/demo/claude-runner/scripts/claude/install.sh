#!/usr/bin/env bash

mkdir -p '${HOME_FOLDER}/.claude'
echo '${SETTINGS}' | jq | tee '${HOME_FOLDER}/.claude/settings.json'

