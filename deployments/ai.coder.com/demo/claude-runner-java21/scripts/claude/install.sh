#!/usr/bin/env bash

# Create Claude settings directory and config
mkdir -p '${HOME_FOLDER}/.claude'
echo '${SETTINGS}' | jq | tee '${HOME_FOLDER}/.claude/settings.json'

# Verify Java is available
echo "Verifying Java installation..."
java -version 2>&1 || echo "Warning: Java not found in PATH"

echo "Claude configuration complete!"