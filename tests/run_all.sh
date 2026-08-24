#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/test_version.sh
bash tests/test_ini_file_parser.sh
echo "PASS: all ini-file-parser tests"
