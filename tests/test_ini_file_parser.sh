#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2034,SC2154
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARSER="${ROOT}/src/ini-file-parser.sh"
FAILS=0

assert_eq() {
    local got="$1"
    local want="$2"
    local name="$3"
    if [[ "${got}" == "${want}" ]]; then
        printf 'PASS  %s\n' "${name}"
        return 0
    fi
    printf 'FAIL  %s\n' "${name}"
    printf '      got:  [%s]\n' "${got}"
    printf '      want: [%s]\n' "${want}"
    FAILS=$((FAILS + 1))
}

assert_file_absent() {
    local path="$1"
    local name="$2"
    if [[ -e "${path}" ]]; then
        printf 'FAIL  %s (path exists: %s)\n' "${name}" "${path}"
        FAILS=$((FAILS + 1))
        return 0
    fi
    printf 'PASS  %s\n' "${name}"
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

# ---------------------------------------------------------------------------
# Case-sensitive get_value (documented default)
# ---------------------------------------------------------------------------
cat > "${WORKDIR}/case.conf" <<'EOF'
[SectionOne]
KeyName=Alpha
[sectionone]
KeyName=Beta
EOF

# shellcheck disable=SC1090
source "${PARSER}"
process_ini_file "${WORKDIR}/case.conf"
assert_eq "$(get_value 'SectionOne' 'KeyName')" "Alpha" "case-sensitive get_value SectionOne"
assert_eq "$(get_value 'sectionone' 'KeyName')" "Beta" "case-sensitive get_value sectionone"
assert_eq "${SectionOne_KeyName}" "Alpha" "case-sensitive named variable SectionOne"
assert_eq "${sectionone_KeyName}" "Beta" "case-sensitive named variable sectionone"
global_reset

# ---------------------------------------------------------------------------
# Case-insensitive + uppercase
# ---------------------------------------------------------------------------
case_sensitive_sections=false
case_sensitive_keys=false
default_to_uppercase=true
show_config_warnings=false
process_ini_file "${WORKDIR}/case.conf"
show_config_warnings=true
assert_eq "$(get_value 'SectionOne' 'KeyName')" "Beta" "case-insensitive last write wins"
assert_eq "${SECTIONONE_KEYNAME}" "Beta" "uppercase named variable"
case_sensitive_sections=true
case_sensitive_keys=true
default_to_uppercase=false
global_reset

# ---------------------------------------------------------------------------
# Quotes, comments, URLs, hex, semicolons
# ---------------------------------------------------------------------------
cat > "${WORKDIR}/values.conf" <<EOF
[sec]
quoted='world'
dquoted="hello there"
hash=color #fff
hex=#fff
semi=a;b;c
url=https://example.com/#frag
spaces=  padded
commented=keep ; trailing comment
hashcomment=keep # trailing comment
unsafe=\$(touch ${WORKDIR}/pwned)
quoted_cmd='\$(touch ${WORKDIR}/pwned2)'
literal_nl=key\\nname
EOF

process_ini_file "${WORKDIR}/values.conf"
assert_eq "$(get_value sec quoted)" "'world'" "keep matching single quotes"
assert_eq "$(get_value sec dquoted)" '"hello there"' "keep matching double quotes"
assert_eq "$(get_value sec hash)" "color" "whitespace + hash is an inline comment"
assert_eq "$(get_value sec hex)" "#fff" "leading hash is kept as a value"
assert_eq "$(get_value sec semi)" "a;b;c" "semicolon without whitespace is kept"
assert_eq "$(get_value sec url)" "https://example.com/#frag" "URL fragment is kept"
assert_eq "$(get_value sec spaces)" "padded" "trim value whitespace"
assert_eq "$(get_value sec commented)" "keep" "whitespace + semicolon is an inline comment"
assert_eq "$(get_value sec hashcomment)" "keep" "whitespace + hash comment"
assert_eq "$(get_value sec unsafe)" '$(touch '"${WORKDIR}/pwned"')' "command substitution is stored literally"
assert_file_absent "${WORKDIR}/pwned" "command substitution is not executed"
assert_eq "$(get_value sec quoted_cmd)" "'\$(touch ${WORKDIR}/pwned2)'" "quoted command keeps its quotes and is not executed"
assert_file_absent "${WORKDIR}/pwned2" "quoted command substitution is not executed"
assert_eq "$(get_value sec literal_nl)" 'key\nname' "backslash-n in a value is literal"
global_reset

# ---------------------------------------------------------------------------
# Backslash in a key is not interpreted by echo -e
# ---------------------------------------------------------------------------
printf '%s\n' '[sec]' 'key\nname=val' > "${WORKDIR}/esc.conf"
process_ini_file "${WORKDIR}/esc.conf"
assert_eq "$(get_value sec 'key\nname')" "val" "backslash-n in a key is cleansed, not split"
assert_eq "${#sec_keys[@]}" "1" "backslash-n key produces one key"
global_reset

# ---------------------------------------------------------------------------
# Duplicate keys: last write wins, get_value returns one value
# ---------------------------------------------------------------------------
cat > "${WORKDIR}/dup.conf" <<'EOF'
[s]
k=one
k=two
EOF
process_ini_file "${WORKDIR}/dup.conf" >/dev/null
assert_eq "$(get_value s k)" "two" "duplicate key last write wins"
assert_eq "${#s_keys[@]}" "1" "duplicate key does not append a second array entry"
global_reset

# ---------------------------------------------------------------------------
# Default section, sanitised names, display_config_by_section
# ---------------------------------------------------------------------------
cat > "${WORKDIR}/default.conf" <<'EOF'
test=before
[ another section]
value 1 = 12345678
EOF
process_ini_file "${WORKDIR}/default.conf" >/dev/null
assert_eq "$(get_value default test)" "before" "pre-section keys land in default"
assert_eq "$(get_value 'another section' 'value 1')" "12345678" "section and key names are cleansed"
display_out="$(display_config_by_section 'another section')"
if [[ "${display_out}" == *'value_1=12345678'* ]]; then
    printf 'PASS  %s\n' "display_config_by_section uses process_section_name"
else
    printf 'FAIL  %s\n' "display_config_by_section uses process_section_name"
    printf '      got: [%s]\n' "${display_out}"
    FAILS=$((FAILS + 1))
fi
global_reset

# ---------------------------------------------------------------------------
# global_reset clears generated state; re-parse does not duplicate default
# ---------------------------------------------------------------------------
cat > "${WORKDIR}/reset.conf" <<'EOF'
[sec]
safe=hello
EOF
process_ini_file "${WORKDIR}/reset.conf"
global_reset
if [[ -z "${sec_safe+x}" ]]; then
    printf 'PASS  %s\n' "global_reset unsets generated scalars"
else
    printf 'FAIL  %s\n' "global_reset unsets generated scalars (still set: ${sec_safe})"
    FAILS=$((FAILS + 1))
fi
process_ini_file "${WORKDIR}/reset.conf"
default_count=0
for item in "${sections[@]}"; do
    if [[ "${item}" == "default" ]]; then
        default_count=$((default_count + 1))
    fi
done
assert_eq "${default_count}" "1" "re-parse does not duplicate the default section"
assert_eq "${#sec_keys[@]}" "1" "re-parse after reset has one key"
global_reset

# ---------------------------------------------------------------------------
# Missing file
# ---------------------------------------------------------------------------
if process_ini_file "${WORKDIR}/nope.conf" >/dev/null 2>&1; then
    printf 'FAIL  %s\n' "missing file returns non-zero"
    FAILS=$((FAILS + 1))
else
    printf 'PASS  %s\n' "missing file returns non-zero"
fi

# ---------------------------------------------------------------------------
# set -u
# ---------------------------------------------------------------------------
if bash -c 'set -u; source "$1"; process_ini_file "$2"' bash "${PARSER}" "${WORKDIR}/reset.conf" >/dev/null; then
    printf 'PASS  %s\n' "process_ini_file works under set -u"
else
    printf 'FAIL  %s\n' "process_ini_file works under set -u"
    FAILS=$((FAILS + 1))
fi

# ---------------------------------------------------------------------------
# Colour: plain when piped, ANSI when FORCE_COLOR, none when NO_COLOR
# ---------------------------------------------------------------------------
cat > "${WORKDIR}/colour.conf" <<'EOF'
before=1
[ok]
k=v
EOF

plain_warn="$(process_ini_file "${WORKDIR}/colour.conf" 2>/dev/null)"
if [[ "${plain_warn}" == *'[ WARNING ]'* && "${plain_warn}" != *$'\033'* ]]; then
    printf 'PASS  %s\n' "warnings are plain when not a colour TTY"
else
    printf 'FAIL  %s\n' "warnings are plain when not a colour TTY"
    printf '      got: [%s]\n' "${plain_warn}"
    FAILS=$((FAILS + 1))
fi
global_reset

colour_warn="$(NO_COLOR='' FORCE_COLOR=1 process_ini_file "${WORKDIR}/colour.conf" 2>/dev/null)"
if [[ "${colour_warn}" == *'[ WARNING ]'* && "${colour_warn}" == *$'\033'* ]]; then
    printf 'PASS  %s\n' "warnings use colour when FORCE_COLOR is set"
else
    printf 'FAIL  %s\n' "warnings use colour when FORCE_COLOR is set"
    printf '      got: [%s]\n' "${colour_warn}"
    FAILS=$((FAILS + 1))
fi
global_reset

plain_err="$(process_ini_file "${WORKDIR}/nope.conf" 2>&1 >/dev/null || true)"
if [[ "${plain_err}" == *'[ ERROR ]'* && "${plain_err}" != *$'\033'* ]]; then
    printf 'PASS  %s\n' "errors are plain when not a colour TTY"
else
    printf 'FAIL  %s\n' "errors are plain when not a colour TTY"
    printf '      got: [%s]\n' "${plain_err}"
    FAILS=$((FAILS + 1))
fi

colour_err="$(NO_COLOR='' FORCE_COLOR=1 process_ini_file "${WORKDIR}/nope.conf" 2>&1 >/dev/null || true)"
if [[ "${colour_err}" == *'[ ERROR ]'* && "${colour_err}" == *$'\033'* ]]; then
    printf 'PASS  %s\n' "errors use colour when FORCE_COLOR is set"
else
    printf 'FAIL  %s\n' "errors use colour when FORCE_COLOR is set"
    printf '      got: [%s]\n' "${colour_err}"
    FAILS=$((FAILS + 1))
fi

nocolor_warn="$(NO_COLOR=1 FORCE_COLOR=1 process_ini_file "${WORKDIR}/colour.conf" 2>/dev/null)"
if [[ "${nocolor_warn}" == *'[ WARNING ]'* && "${nocolor_warn}" != *$'\033'* ]]; then
    printf 'PASS  %s\n' "NO_COLOR disables warning colour"
else
    printf 'FAIL  %s\n' "NO_COLOR disables warning colour"
    printf '      got: [%s]\n' "${nocolor_warn}"
    FAILS=$((FAILS + 1))
fi
global_reset

if [[ "${FAILS}" -ne 0 ]]; then
    printf '\n%d test(s) failed\n' "${FAILS}" >&2
    exit 1
fi

echo "PASS: test_ini_file_parser.sh"
