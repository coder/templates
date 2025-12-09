#!/usr/bin/env bash

# Coder Boundary Setup

mkdir -p '${HOME_FOLDER}/.config/coder_boundary'
echo '${CODER_BOUNDARY_B64}' | base64 -d > '${HOME_FOLDER}/.config/coder_boundary/config.yaml'
chmod 600 '${HOME_FOLDER}/.config/coder_boundary/config.yaml'

# Claude Settings

mkdir -p '${HOME_FOLDER}/.claude'
echo '${SETTINGS}' | jq | tee '${HOME_FOLDER}/.claude/settings.json'

# Add MCP Servers for this project

claude mcp add -s user playwright npx -- @playwright/mcp@latest --headless --isolated --no-sandbox

${PRESET_SCRIPT}