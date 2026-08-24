#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# Demonstrate loading an INI file with ini-file-parser.sh.                         #
# -------------------------------------------------------------------------------- #

set -euo pipefail

# -------------------------------------------------------------------------------- #
# Declaration                                                                      #
# -------------------------------------------------------------------------------- #
# Optional declares for values the parser creates. Keeps shellcheck clean.         #
# -------------------------------------------------------------------------------- #

declare sections

declare section1_value1
declare section1_keys
declare section1_values

declare SECTION1_VALUE1
declare SECTION1_keys
declare SECTION1_values

# -------------------------------------------------------------------------------- #
# Global Overrides                                                                 #
# -------------------------------------------------------------------------------- #
# These variables allow us to override the parse script defaults.                  #
#                                                                                  #
# case_sensitive_sections - should section names be case sensitive                 #
# case_sensitive_keys     - should key names be case sensitive                     #
# default_to_uppercase    - should we default to uppercase?                        #
# show_config_warnings    - should we show config warnings                         #
# show_config_errors      - should we show config errors                           #
# -------------------------------------------------------------------------------- #

export case_sensitive_sections=false
export case_sensitive_keys=false
export default_to_uppercase=true
#export show_config_warnings=false
#export show_config_errors=false

# -------------------------------------------------------------------------------- #
# Use the source                                                                   #
# -------------------------------------------------------------------------------- #

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/src/ini-file-parser.sh"

# -------------------------------------------------------------------------------- #
# Profile ini file                                                                 #
# -------------------------------------------------------------------------------- #

process_ini_file "${SCRIPT_DIR}/complete-example.conf"

# -------------------------------------------------------------------------------- #
# Display Config                                                                   #
# -------------------------------------------------------------------------------- #

echo "Display Config"
display_config

# -------------------------------------------------------------------------------- #
# Display Config by Section                                                        #
# -------------------------------------------------------------------------------- #

echo "Display Section 2"
display_config_by_section 'section2'

# -------------------------------------------------------------------------------- #
# Get Value                                                                        #
# -------------------------------------------------------------------------------- #

echo "Display Section 1 - Value 1 (get_value lookup)"
value="$(get_value 'section1' 'value1')"
echo "${value}"

# -------------------------------------------------------------------------------- #
# Dynamic Variables                                                                #
# -------------------------------------------------------------------------------- #

echo "Display Section 1 - Value 1 (Named variable)"
if [[ "${default_to_uppercase}" == false ]]; then
    echo "${section1_value1}"
else
    echo "${SECTION1_VALUE1}"
fi

# -------------------------------------------------------------------------------- #
# Section, Key and Value Traversals                                                #
# -------------------------------------------------------------------------------- #

echo
echo "Display Section, Key and Value Traversals"

echo "${sections[@]}"

if [[ "${default_to_uppercase}" == false ]]; then
    echo "${section1_keys[@]}"
    echo "${section1_values[@]}"
else
    echo "${SECTION1_keys[@]}"
    echo "${SECTION1_values[@]}"
fi
