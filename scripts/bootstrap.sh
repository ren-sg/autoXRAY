#!/bin/bash
# Minimal bootstrap for clean Ubuntu before git clone.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Need root"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git curl

echo "Bootstrap done: git, curl installed"
