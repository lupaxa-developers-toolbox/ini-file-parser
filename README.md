<p align="center">
  <a href="https://github.com/lupaxa-developers-toolbox">
    <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/organisations/developers-toolbox/readme-logo.png" alt="Developers Toolbox" />
  </a>
</p>

<h1 align="center">Ini File Parser</h1>

Sourceable Bash helper that reads INI-style config files. Bash has no built-in INI support; this script loads a file into per-section key/value arrays and optional `section_key` variables.

## Requirements

- Bash 4.3 or later (namerefs)

## Use

```bash
source src/ini-file-parser.sh
process_ini_file 'example.conf'
echo "$(get_value 'section1' 'value1')"
echo "${section1_value1}"
```

A full walkthrough is in [demos/parse-example.sh](demos/parse-example.sh). Sample files:

| File                                            | Description                                              |
| :---------------------------------------------- | :------------------------------------------------------- |
| [simple example](demos/simple-example.conf)     | Sections and `key=value` pairs.                          |
| [complete example](demos/complete-example.conf) | Processing rules, warnings, and error conditions.        |

## Processing Rules

1. Empty lines are ignored.
2. Lines starting with `#` or `;` (after trim) are ignored.
3. Keys defined before the first section go in `default`.
4. Section and key names keep only letters, digits, and underscores. Punctuation and blanks become `_`.
5. Section and key names are case-sensitive by default.
6. Leading and trailing whitespace is removed from keys and values.
7. Inline `#` or `;` comments are removed only when preceded by whitespace, so URL fragments and values such as `#fff` or `a;b;c` are kept.
8. Quotes around a value are kept. `'quoted value'` is stored as `'quoted value'`.
9. Command-like text such as `$(ls)` is stored as a string. The parser never executes it.
10. Duplicate keys in a section warn; the last value wins.
11. After processing, each pair is also available as `section_key=value`.

## Subroutines

| Name                        | Purpose                                                      |
| :-------------------------- | :----------------------------------------------------------- |
| `process_ini_file`          | Load a named INI file. Returns 1 if the file cannot be read. |
| `get_value`                 | Return one value for a section and key.                      |
| `display_config`            | Print the processed config in INI form.                      |
| `display_config_by_section` | Print one processed section.                                 |
| `global_reset`              | Drop all loaded sections, arrays, and scalars.               |
| `get_version`               | Print the library version string.                            |

## Global Overrides

Set these **before** `process_ini_file`. Values must be `true` or `false`.

| Name                      | Description                                      | Default |
| :------------------------ | :----------------------------------------------- | :------ |
| `case_sensitive_sections` | Treat section names as case-sensitive.           | `true`  |
| `case_sensitive_keys`     | Treat key names as case-sensitive.               | `true`  |
| `default_to_uppercase`    | When case-insensitive, fold names to uppercase.  | `false` |
| `show_config_warnings`    | Print config warnings.                           | `true`  |
| `show_config_errors`      | Print config errors.                             | `true`  |

Warnings are yellow and errors are red when that stream is a colour-capable
terminal. Set `NO_COLOR` to disable, or `FORCE_COLOR=1` to enable in pipes.

```bash
show_config_warnings=false
case_sensitive_sections=false
source src/ini-file-parser.sh
process_ini_file 'example.conf'
```

## Development

```bash
make init     # first-time makefile-skills checkout
make check    # shellcheck, bash -n, and tests/run_all.sh
```

<a href="https://github.com/the-lupaxa-project">
    <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/components/footer-for-child-orgs.svg" alt="The Lupaxa Project Footer" width="100%" />
</a>
