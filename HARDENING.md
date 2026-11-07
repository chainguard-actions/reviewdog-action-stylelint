<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.34.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-stylelint/v1.34.0** was hardened automatically. 3 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### script-injection (severity: high)

Rule (b): script.sh puts workflow inputs into one command string and hands it to a shell with `npx --no-install -c "${cmd}"`. The string is built as `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"`, then `--config='${INPUT_STYLELINT_CONFIG}'` and `--ignore-pattern='${INPUT_STYLELINT_IGNORE}'` are added. The single quotes don't help: a value containing a single quote can close them, and stylelint_input isn't quoted at all. Either way the shell would read characters like ;, | or $(...) from the input as commands.

Locations:

- `script.sh:19`
- `script.sh:9`
- `script.sh:12`
- `script.sh:16`

### script-injection (severity: high)

Rule (b): `npm install ${INPUT_PACKAGES}` expands the workflow-controlled packages input without double quotes. The shell then splits the value into words and expands glob characters, so the input can add extra arguments or options to npm install.

Locations:

- `script.sh:47`

### unsafe-shell (severity: high)

Remote content is piped straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/<sha>/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL is pinned to a commit, but the script runs without being saved to a file and checked first.

Locations:

- `script.sh:35`

## Iteration Notes

### Iteration 1

**Fixes applied:** script-injection, unsafe-shell

**Notes:**

All changes are in script.sh. Nothing was run, so these changes are untested.

1. **stylelint command (script-injection):** the script no longer builds one command string and passes it to `npx -c`. stylelint now runs as `npx --no-install stylelint "${cmd_args[@]}"`, with each argument kept separate.
   - `stylelint_input` is split the way upstream's shell split it, honouring quotes, using the `xargs -r` split that never evaluates anything. An unmatched quote now makes the stylelint step fail.
   - `--config=` and `--ignore-pattern=` are each passed as one double-quoted argument.

2. **Shebang:** changed from `#!/bin/sh` to `#!/usr/bin/env bash` so the script can use arrays. This is safe because it is a composite action that runs on the runner itself, where bash is installed, not in a container.

3. **`npm install ${INPUT_PACKAGES}` (script-injection):** the packages input is now read into an array with `read -r -d '' -a` and passed as `"${pkg_args[@]}"`. It still splits on whitespace like upstream, but no longer expands globs.

4. **reviewdog installer (unsafe-shell):** the installer, still at the same pinned commit, is now saved to a temp file, checked to be non-empty, run with `sh "$f" -b "$TEMP_PATH" "$REVIEWDOG_VERSION"`, then deleted. I dropped the `-s --` from the old pipe form. As before, a failed download doesn't stop the script.

**Behaviour changes:**
- Upstream's shell could expand glob patterns in `stylelint_input` itself. Now stylelint always receives the pattern unexpanded and matches it itself. That handles `**` correctly, but results could differ from upstream in edge cases.
- stylelint is now started as `npx --no-install stylelint <args>` instead of through `npx -c`. With npm 7 or later, anything after the command name should go to stylelint, but I haven't confirmed this on older npm versions.

### Iteration 1

**Fixes applied:** publish-gate

**Notes:**

script.sh had been corrupted by earlier overlapping edits (the reviewdog install block and the npm install block were spliced together mid-line), causing a stray `fi`. Reconstructed: install script downloaded to file then run with `sh "$INSTALL_SCRIPT" -b "$TEMP_PATH" "$REVIEWDOG_VERSION"` (no '--'), restored `if [ $? -ne 0 ]` npm install block, and the INPUT_PACKAGES install uses a whitespace split via `read -r -d '' -a ... || true` inside the existing guard.

