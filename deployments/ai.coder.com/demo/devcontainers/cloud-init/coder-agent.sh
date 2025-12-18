#!/usr/bin/env bash

# Only add -x for debugging. Cloud-Init logs will reveal source code with Coder tokens if added.
# https://www.man7.org/linux/man-pages/man1/set.1p.html

set -eu

# Loop until metadata is accessible.
echo "here!"
max=10 ; idx=0
while ! curl -s -f "http://169.254.169.254/latest/meta-data/instance-id" > /dev/null; do
  echo "Waiting for EC2 instance metadata service..."
  sleep 5
  idx=$((idx + 1))
  if [ $idx -ge $max ] ; then
    echo "Timed out waiting for EC2 instance metadata service"
    exit 1
  fi
done
echo "EC2 instance metadata service is ready!"

# Close standard output file descriptor
exec 1<&-
# Close standard error file descriptor
exec 2<&-

# Open standard output as $LOG_FILE file for read and write.
exec 1<>/tmp/coder-init-script.log

# Redirect standard error to standard output
exec 2>&1
sudo PATH="$PATH:/home/${user}/bin" CODER_AGENT_DEVCONTAINERS_ENABLE="${enable_devcontainer_feature}" \
    -u '${user}' sh -c '${init_script}' &
disown ;