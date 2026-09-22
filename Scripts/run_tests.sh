#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SWIFT_JOBS="${ZEUVE_SWIFT_JOBS:-1}"
swift test --jobs "$SWIFT_JOBS"
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
