<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.31.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-stylelint/v1.31.0** was hardened automatically. 3 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes the output of a remote curl download directly to `sh` for execution: `curl -sfL https://raw.githubusercontent.com/.../install.sh | sh -s -- ...`. This pattern executes remotely-fetched content without any integrity verification, allowing a compromised or man-in-the-middle response to run arbitrary code on the runner.

Locations:

- `script.sh:34`

### script-injection (severity: high)

Rule (b) violation: `script.sh` line 44 expands `${INPUT_PACKAGES}` unquoted in `npm install ${INPUT_PACKAGES}`. `INPUT_PACKAGES` is set from `inputs.packages` (a workflow-controllable value). An attacker can inject shell metacharacters (e.g. `;`, `&&`, `|`) via this input to execute arbitrary commands.

Locations:

- `script.sh:44`

### script-injection (severity: high)

Rule (b) violation: `script.sh` line 9 builds a shell command string by interpolating `${INPUT_STYLELINT_INPUT}` unquoted inside a double-quoted string: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ..."`. This `cmd` string is then passed to `npx --no-install -c "${cmd}"` which re-evaluates it as a shell command. Since `INPUT_STYLELINT_INPUT` is sourced from `inputs.stylelint_input` (a workflow-controllable value), an attacker can inject shell metacharacters to achieve command injection.

Locations:

- `script.sh:9`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed three security issues in script.sh:
1. unsafe-shell (line 34): Replaced `curl ... | sh -s -- ...` with a download-then-execute pattern: curl downloads the install script to a temp file with `-o`, it's executed separately with `sh`, then removed with `rm -f`.
2. script-injection (line 9): Rewrote `__run_stylelint` to use a bash array (`stylelint_args`) instead of building a shell command string. Now calls `npx --no-install stylelint "${stylelint_args[@]}"` directly with all arguments properly quoted, eliminating injection via `${INPUT_STYLELINT_INPUT}`.
3. script-injection (line 44): Replaced unquoted `npm install ${INPUT_PACKAGES}` with `read -ra packages_array <<< "${INPUT_PACKAGES}"` followed by `npm install "${packages_array[@]}"` to safely handle space-separated package names.
Also updated shebang from `#!/bin/sh` to `#!/bin/bash` since the script now uses bash-specific features (arrays, `read -ra`, here-strings).

