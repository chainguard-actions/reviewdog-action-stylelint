<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.32.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-stylelint/v1.32.0** was hardened automatically. 2 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/.../install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. Even though the URL is pinned to a commit SHA in the path, the content is still executed immediately without any integrity check (e.g. checksum verification). The script should be downloaded to a temporary file, verified, and then executed separately.

Locations:

- `script.sh:32`

### script-injection (severity: high)

Sub-rule (b): Unquoted shell variable expansion of untrusted data in two places:

1. Line 9: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"` — `${INPUT_STYLELINT_INPUT}` is sourced from `inputs.stylelint_input` (a caller-controlled value) and is interpolated unquoted inside a double-quoted string that is later passed to `npx --no-install -c "${cmd}"`. An attacker can inject shell metacharacters (e.g. `; malicious-command`) via the `stylelint_input` input.

2. Line 43: `npm install ${INPUT_PACKAGES}` — `${INPUT_PACKAGES}` is sourced from `inputs.packages` and is completely unquoted, allowing word-splitting and shell metacharacter injection. It should be `npm install "${INPUT_PACKAGES}"` at minimum, or ideally handled via an array.

Locations:

- `script.sh:9`
- `script.sh:43`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed all three findings in hardened/action/script.sh:

1. unsafe-shell (line 32): Replaced `curl ... | sh -s -- -b ...` with: download the install script to a temp file using `curl -sfL ... -o "${INSTALL_SCRIPT}"`, execute it with `sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"` (dropping the `--` which was the shell's own option terminator, not the script's argument), then clean up with `rm -f "${INSTALL_SCRIPT}"`.

2. script-injection (line 9): `INPUT_STYLELINT_INPUT` is a whitespace-separated list of files/globs. Tokenized it via xargs into a bash array `stylelint_inputs` using the NUL-delimited read loop pattern. Built the entire stylelint command as a bash array `cmd` so all values are properly quoted and argument boundaries are preserved.

3. script-injection (line 43): `INPUT_PACKAGES` is a whitespace-separated list of npm package names. Tokenized it via xargs into a bash array `packages` using the same NUL-delimited read loop pattern (guarded by `if [ -n ... ]` to avoid xargs running on empty input). Passed to `npm install "${packages[@]}"` with proper quoting.

Also updated the shebang from `#!/bin/sh` to `#!/bin/bash` since action.yml already specifies `shell: bash` and the fixes use bash-specific features (arrays, process substitution).

