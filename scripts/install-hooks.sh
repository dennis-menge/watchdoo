#!/usr/bin/env bash
# Configure git to use the in-tree hooks under .githooks/.
# Run this once after cloning.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

git config core.hooksPath .githooks
echo "✓ git core.hooksPath set to .githooks"
echo "  Active hooks:"
ls -1 .githooks | sed 's/^/    /'
