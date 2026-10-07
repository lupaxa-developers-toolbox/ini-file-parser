#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# Pure Bash INI reader for Bash 4.3+. Section and key names are cleansed into      #
# valid identifiers. Values are stored in parallel arrays plus optional scalars    #
# named section_key.                                                               #
# -------------------------------------------------------------------------------- #

INI_FILE_PARSER_VERSION="0.1.3"

get_version()
{
    printf '%s\n' "${INI_FILE_PARSER_VERSION}"
}

# -------------------------------------------------------------------------------- #
# Caller overrides (set before process_ini_file). Unset is treated as default.     #
# -------------------------------------------------------------------------------- #
# case_sensitive_sections - should section names be case sensitive                 #
# case_sensitive_keys     - should key names be case sensitive                     #
# default_to_uppercase    - when case-insensitive, fold to uppercase               #
# show_config_warnings    - should we show config warnings                         #
# show_config_errors      - should we show config errors                           #
# -------------------------------------------------------------------------------- #

DEFAULT_SECTION='default'
sections=()
_ini_generated=()

_ini_case_sensitive_sections=true
_ini_case_sensitive_keys=true
_ini_default_to_uppercase=false
_ini_show_config_warnings=true
_ini_show_config_errors=true

function _ini_bool_override()
{
    local raw="${1-}"
    local current="$2"

    if [[ "${raw}" == true || "${raw}" == false ]]; then
        printf '%s' "${raw}"
    else
        printf '%s' "${current}"
    fi
}

function setup_global_variables()
{
    _ini_case_sensitive_sections="$(_ini_bool_override "${case_sensitive_sections-}" "${_ini_case_sensitive_sections}")"
    _ini_case_sensitive_keys="$(_ini_bool_override "${case_sensitive_keys-}" "${_ini_case_sensitive_keys}")"
    _ini_default_to_uppercase="$(_ini_bool_override "${default_to_uppercase-}" "${_ini_default_to_uppercase}")"
    _ini_show_config_warnings="$(_ini_bool_override "${show_config_warnings-}" "${_ini_show_config_warnings}")"
    _ini_show_config_errors="$(_ini_bool_override "${show_config_errors-}" "${_ini_show_config_errors}")"

    if [[ "${_ini_case_sensitive_sections}" == false ]]; then
        DEFAULT_SECTION="$(_ini_apply_case "default")"
    else
        DEFAULT_SECTION='default'
    fi
    _ini_ensure_section_listed "${DEFAULT_SECTION}"
}

function _ini_apply_case()
{
    local str="$1"

    if [[ "${_ini_default_to_uppercase}" == true ]]; then
        printf '%s' "${str^^}"
    else
        printf '%s' "${str,,}"
    fi
}

function _ini_trim()
{
    local s="$1"

    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "${s}"
}

function _ini_cleanse_identifier()
{
    local raw="$1"
    local case_sensitive="$2"
    local s

    s="$(_ini_trim "${raw}")"
    s="$(printf '%s' "${s}" | tr -s '[:punct:][:blank:]' '_')"
    s="$(printf '%s' "${s}" | tr -cd 'a-zA-Z0-9_')"

    if [[ "${case_sensitive}" == false ]]; then
        s="$(_ini_apply_case "${s}")"
    fi
    printf '%s' "${s}"
}

function process_section_name()
{
    _ini_cleanse_identifier "${1-}" "${_ini_case_sensitive_sections}"
}

function process_key_name()
{
    _ini_cleanse_identifier "${1-}" "${_ini_case_sensitive_keys}"
}

function _ini_is_valid_identifier()
{
    [[ "${1-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

function process_value()
{
    local value="${1-}"

    value="$(printf '%s' "${value}" | sed -E 's/[[:space:]]+[;#].*$//')"
    value="$(_ini_trim "${value}")"
    printf '%s' "${value}"
}

function in_array()
{
    local -n _ini_haystack="$1"
    local needle="${2-}"
    local item

    for item in "${_ini_haystack[@]+"${_ini_haystack[@]}"}"; do
        if [[ "${item}" == "${needle}" ]]; then
            return 0
        fi
    done
    return 1
}

function _ini_colour_enabled()
{
    local fd="$1"
    local ncolors

    if [[ -n "${NO_COLOR-}" ]]; then
        return 1
    fi
    case "${FORCE_COLOR-}" in
        1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]) return 0 ;;
        0|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]) return 1 ;;
    esac
    [[ -t "${fd}" ]] || return 1
    ncolors="$(tput colors 2>/dev/null || true)"
    [[ -n "${ncolors}" && "${ncolors}" -ge 8 ]]
}

function _ini_colour()
{
    local name="$1"
    local code=""

    case "${name}" in
        red) code="$(tput setaf 1 2>/dev/null || true)" ;;
        yellow) code="$(tput setaf 3 2>/dev/null || true)" ;;
        reset) code="$(tput sgr0 2>/dev/null || true)" ;;
    esac
    if [[ -z "${code}" ]]; then
        case "${name}" in
            red) code=$'\033[31m' ;;
            yellow) code=$'\033[33m' ;;
            reset) code=$'\033[0m' ;;
        esac
    fi
    printf '%s' "${code}"
}

function show_warning()
{
    local format
    local yellow=""
    local reset=""

    if [[ "${_ini_show_config_warnings}" == true ]]; then
        if _ini_colour_enabled 1; then
            yellow="$(_ini_colour yellow)"
            reset="$(_ini_colour reset)"
        fi
        format="$1"
        shift
        # shellcheck disable=SC2059
        printf "${yellow}[ WARNING ] ${format}${reset}" "$@"
    fi
}

function show_error()
{
    local format
    local red=""
    local reset=""

    if [[ "${_ini_show_config_errors}" == true ]]; then
        if _ini_colour_enabled 2; then
            red="$(_ini_colour red)"
            reset="$(_ini_colour reset)"
        fi
        format="$1"
        shift
        # shellcheck disable=SC2059
        printf "${red}[ ERROR ] ${format}${reset}" "$@" >&2
    fi
}

function _ini_track()
{
    local name="$1"

    if ! in_array _ini_generated "${name}"; then
        _ini_generated+=("${name}")
    fi
}

function _ini_ensure_section_listed()
{
    local section="$1"

    if ! in_array sections "${section}"; then
        sections+=("${section}")
    fi
}

function _ini_init_section_arrays()
{
    local section="$1"

    if ! declare -p "${section}_keys" >/dev/null 2>&1; then
        declare -g -a "${section}_keys=()"
        declare -g -a "${section}_values=()"
        _ini_track "${section}_keys"
        _ini_track "${section}_values"
    fi
}

function _ini_set_pair()
{
    local section="$1"
    local key="$2"
    local value="$3"
    local -n _ini_keys="${section}_keys"
    local -n _ini_values="${section}_values"
    local i
    local found=false

    for i in "${!_ini_keys[@]}"; do
        if [[ "${_ini_keys[${i}]}" == "${key}" ]]; then
            show_warning 'key %s - Defined multiple times within section %s\n' "${key}" "${section}"
            _ini_values[i]="${value}"
            found=true
            break
        fi
    done

    if [[ "${found}" == false ]]; then
        _ini_keys+=("${key}")
        _ini_values+=("${value}")
    fi

    printf -v "${section}_${key}" '%s' "${value}"
    _ini_track "${section}_${key}"
}

function global_reset()
{
    local name

    for name in "${_ini_generated[@]+"${_ini_generated[@]}"}"; do
        unset "${name}"
    done
    _ini_generated=()
    sections=()

    if [[ "${_ini_case_sensitive_sections}" == false ]]; then
        DEFAULT_SECTION="$(_ini_apply_case "default")"
    else
        DEFAULT_SECTION='default'
    fi
    _ini_ensure_section_listed "${DEFAULT_SECTION}"
}

function process_ini_file()
{
    local ini_path="${1-}"
    local line_number=0
    local section
    local line trimmed key value

    setup_global_variables
    section="${DEFAULT_SECTION}"

    if [[ -z "${ini_path}" || ! -f "${ini_path}" || ! -r "${ini_path}" ]]; then
        show_error 'Cannot read ini file: %s\n' "${ini_path:-"(missing path)"}"
        return 1
    fi

    _ini_init_section_arrays "${DEFAULT_SECTION}"

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line//$'\r'/}"
        line_number=$((line_number + 1))

        trimmed="$(_ini_trim "${line}")"
        if [[ -z "${trimmed}" || "${trimmed}" == \#* || "${trimmed}" == \;* ]]; then
            continue
        fi

        if [[ "${trimmed}" =~ ^\[(.+)\]$ ]]; then
            section="$(process_section_name "${BASH_REMATCH[1]}")"
            if ! _ini_is_valid_identifier "${section}"; then
                show_error 'line %d: Invalid section name\n' "${line_number}"
                continue
            fi
            _ini_ensure_section_listed "${section}"
            _ini_init_section_arrays "${section}"
        elif [[ "${trimmed}" == *"="* ]]; then
            key="$(process_key_name "${trimmed%%=*}")"
            value="$(process_value "${trimmed#*=}")"
            if ! _ini_is_valid_identifier "${key}"; then
                show_error 'line %d: No key name\n' "${line_number}"
                continue
            fi
            if [[ "${section}" == "${DEFAULT_SECTION}" ]]; then
                show_warning '%s=%s - Defined on line %s before first section - added to "%s" group\n' \
                    "${key}" "${value}" "${line_number}" "${DEFAULT_SECTION}"
            fi
            _ini_set_pair "${section}" "${key}" "${value}"
        fi
    done < "${ini_path}"
}

function get_value()
{
    local section key i

    section="$(process_section_name "${1-}")"
    key="$(process_key_name "${2-}")"

    if ! declare -p "${section}_keys" >/dev/null 2>&1; then
        return 0
    fi

    local -n _ini_lookup_keys="${section}_keys"
    local -n _ini_lookup_values="${section}_values"

    for i in "${!_ini_lookup_keys[@]}"; do
        if [[ "${_ini_lookup_keys[${i}]}" == "${key}" ]]; then
            printf '%s' "${_ini_lookup_values[${i}]}"
            return 0
        fi
    done
}

function _ini_print_section()
{
    local section="$1"
    local i

    printf '[%s]\n' "${section}"
    if declare -p "${section}_keys" >/dev/null 2>&1; then
        local -n _ini_print_keys="${section}_keys"
        local -n _ini_print_values="${section}_values"
        for i in "${!_ini_print_keys[@]}"; do
            printf '%s=%s\n' "${_ini_print_keys[${i}]}" "${_ini_print_values[${i}]}"
        done
    fi
    printf '\n'
}

function display_config()
{
    local s

    for s in "${!sections[@]}"; do
        _ini_print_section "${sections[${s}]}"
    done
}

function display_config_by_section()
{
    _ini_print_section "$(process_section_name "${1-}")"
}
