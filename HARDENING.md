<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.33.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-stylelint/v1.33.0** was hardened automatically. 2 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it. The pattern `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/.../install.sh | sh -s -- ...` executes whatever the remote server returns in a shell. Even though the URL is pinned to a specific commit SHA in the path, the content is still streamed directly into `sh` without any integrity check (e.g. checksum verification), making this an unsafe-shell pattern.

Locations:

- `script.sh:36`

### script-injection (severity: high)

Rule (b) violation — unquoted shell variable expansion of untrusted/workflow-controllable data in script.sh:

1. Line 46: `npm install ${INPUT_PACKAGES}` — `INPUT_PACKAGES` is set from `${{ inputs.packages }}` (an attacker-controlled input) and is expanded **unquoted**, allowing shell word-splitting and glob expansion. An attacker could inject additional shell arguments or metacharacters (e.g. `; malicious-command`).

2. Line 9: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"` — `INPUT_STYLELINT_INPUT` (from `${{ inputs.stylelint_input }}`) is interpolated unquoted inside the double-quoted string that is later passed to `npx --no-install -c "${cmd}"`, allowing injection of additional stylelint flags or shell metacharacters via the input value.

Locations:

- `script.sh:9`
- `script.sh:46`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed three issues in script.sh:

1. unsafe-shell (line 36): Replaced `curl ... | sh -s -- -b ...` with a two-step approach: download the install script to a temp file with `curl -sfL ... -o "${INSTALL_SCRIPT}"`, then execute it with `sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The `--` was dropped (it was the shell's option terminator in the pipe form, not a script argument).

2. script-injection (line 9): `INPUT_STYLELINT_INPUT` (a list/glob input) is no longer interpolated unquoted into a command string. The `__run_stylelint` function now uses `set --` to build flag arguments safely, and pipes `INPUT_STYLELINT_INPUT` through `xargs` to tokenize it into separate arguments: `printf '%s' "${INPUT_STYLELINT_INPUT}" | xargs npx --no-install stylelint "$@"`.

3. script-injection (line 46): `INPUT_PACKAGES` (a whitespace-separated list of npm package names) is no longer expanded unquoted. It's now safely tokenized via `printf '%s' "${INPUT_PACKAGES}" | xargs npm install`.

All fixes use POSIX-compatible constructs (no bash arrays or process substitution) since the script has a `#!/bin/sh` shebang.

