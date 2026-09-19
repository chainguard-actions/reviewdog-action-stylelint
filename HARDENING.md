<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.33.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-stylelint/v1.33.0** was hardened automatically. 2 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it. The pattern `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"` executes whatever content is served at that URL directly in the shell. Even though the URL is pinned to a commit SHA in the path, the content is still piped directly to `sh` rather than being downloaded, verified, and executed separately.

Locations:

- `script.sh:33`

### script-injection (severity: high)

Rule (b) violation — unquoted shell variable expansion of untrusted (workflow-controllable) data in two places:

1. Line 9: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"` — `${INPUT_STYLELINT_INPUT}` (sourced from `inputs.stylelint_input`) is unquoted inside the double-quoted string that builds a command passed to `npx --no-install -c "${cmd}"`. An attacker can inject shell metacharacters (`;`, `|`, `$()`, etc.) via this input.

2. Line 43: `npm install ${INPUT_PACKAGES}` — `${INPUT_PACKAGES}` (sourced from `inputs.packages`) is completely unquoted, allowing word-splitting and shell metacharacter injection by an attacker supplying a malicious packages value.

Locations:

- `script.sh:9`
- `script.sh:43`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed all three findings in hardened/action/script.sh:

1. unsafe-shell (line 33): Replaced `curl ... | sh -s -- -b ...` with a two-step approach: download the install script to a temp file (`curl -sfL ... -o "${INSTALL_SCRIPT}"`), then execute it separately (`sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`). Dropped the `--` as instructed (it was the shell's option terminator in the pipe form, not the script's argument). Temp file is removed after execution.

2. script-injection (line 9): Quoted `${INPUT_STYLELINT_INPUT}` with escaped double quotes inside the command string (`\"${INPUT_STYLELINT_INPUT}\"`), preventing shell metacharacter injection via the stylelint_input input.

3. script-injection (line 43): Replaced unquoted `npm install ${INPUT_PACKAGES}` with a safe xargs-based tokenization using `while IFS= read -r -d '' t; do set -- "$@" "$t"; done < <(printf '%s' "${INPUT_PACKAGES}" | xargs printf '%s\0')` followed by `npm install "$@"`. This handles quoted arguments correctly and prevents word-splitting/injection. The action runs with `shell: bash` so bash features are available.

### Iteration 1

**Fixes applied:** script-injection

**Notes:**

Fixed script-injection vulnerability in hardened/action/script.sh. The __run_stylelint() function previously built a shell command string embedding INPUT_STYLELINT_INPUT, INPUT_STYLELINT_CONFIG, and INPUT_STYLELINT_IGNORE, then executed it via 'npx --no-install -c "${cmd}"' which passes the string to a shell interpreter. Replaced with POSIX-compatible set -- idiom: positional parameters are built with properly quoted individual arguments, then stylelint is invoked directly via 'npx --no-install stylelint "$@"' (no -c flag), so user-controlled values are never interpreted as shell commands.

