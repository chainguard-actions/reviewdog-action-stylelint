<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.34.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `374911c4be584df24e6da57af2d990570ef0f859`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-stylelint/v1.34.0** was hardened automatically. 4 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### script-injection (severity: high)

Rule (b): in script.sh, __run_stylelint builds a shell command string from inputs the workflow controls: cmd="stylelint ${INPUT_STYLELINT_INPUT} ...", cmd="${cmd} --config='${INPUT_STYLELINT_CONFIG}'" and cmd="${cmd} --ignore-pattern='${INPUT_STYLELINT_IGNORE}'". It then runs the string with `npx --no-install -c "${cmd}"`, and npx -c parses it with a shell. Shell metacharacters (;, |, $(...), backticks, or a single quote that closes the '...' wrapping) in stylelint_input, stylelint_config or stylelint_ignore will therefore run arbitrary commands. Fix: build an argument array instead of a string and pass it straight to stylelint, or run it with `npx --no-install stylelint "$INPUT_STYLELINT_INPUT" ...`.

Locations:

- `script.sh:9`
- `script.sh:12`
- `script.sh:16`
- `script.sh:19`

### script-injection (severity: high)

Rule (b): in script.sh, `npm install ${INPUT_PACKAGES}` expands the workflow-controlled input inputs.packages without quotes. It is not an array assignment and has no shellcheck SC2086/SC2206 directive, so the exemption does not apply.

Locations:

- `script.sh:47`

### unsafe-shell (severity: high)

script.sh pipes remote content straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL is pinned to a commit, but the script is still run without first being saved to a file and checked.

Locations:

- `script.sh:35`

### prior-fix (severity: high)

Carried forward from this version's previous harden, which fixed it; fix it again unless the code no longer has the problem. The previous harden changed script.sh without recording a finding for it, and this analysis reported nothing there. Re-apply its security changes unless the code no longer needs them. The previous patch:
```diff
diff --git a/script.sh b/script.sh
index f44a805..6cd07b9 100755
--- a/script.sh
+++ b/script.sh
@@ -1,4 +1,4 @@
-#!/bin/sh
+#!/usr/bin/env bash
 
 TEMP_PATH="$(mktemp -d)"
 PATH="${TEMP_PATH}:$PATH"
@@ -6,17 +6,25 @@ export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
 STYLELINT_FORMATTER="${GITHUB_ACTION_PATH}/stylelint-formatter-rdjson/index.js"
 
 __run_stylelint() {
-  cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"
+  input_args=()
+  if [ -n "${INPUT_STYLELINT_INPUT}" ]; then
+    # Quote-aware split (upstream passed this through `sh -c`), without evaluation.
+    printf '%s' "${INPUT_STYLELINT_INPUT}" | xargs -r true >/dev/null || return 1
+    while IFS= read -r -d '' t; do input_args+=("$t"); done \
+      < <(printf '%s' "${INPUT_STYLELINT_INPUT}" | xargs -r sh -c 'printf "%s\0" "$@"' sh)
+  fi
+
+  cmd_args=("${input_args[@]}" --custom-formatter "${STYLELINT_FORMATTER}")
 
   if [ -n "${INPUT_STYLELINT_CONFIG}" ]; then
-    cmd="${cmd} --config='${INPUT_STYLELINT_CONFIG}'"
+    cmd_args+=("--config=${INPUT_STYLELINT_CONFIG}")
   fi
 
   if [ -n "${INPUT_STYLELINT_IGNORE}" ]; then
-    cmd="${cmd} --ignore-pattern='${INPUT_STYLELINT_IGNORE}'"
+    cmd_args+=("--ignore-pattern=${INPUT_STYLELINT_IGNORE}")
   fi
 
-  npx --no-install -c "${cmd}" 2>&1
+  npx --no-install stylelint "${cmd_args[@]}" 2>&1
 }
 
 __run_reviewdog() {
@@ -32,7 +40,13 @@ __run_reviewdog() {
 cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1
 
 echo '::group:: Installing reviewdog 🐶 ... https://github.com/reviewdog/reviewdog'
-curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+INSTALL_SCRIPT="${TEMP_PATH}/reviewdog-install.sh"
+if curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "${INSTALL_SCRIPT}" && [ -s "${INSTALL_SCRIPT}" ]; then
+  sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+else
+  echo 'Failed to download reviewdog install script'
+fi
+rm -f "${INSTALL_SCRIPT}"
 echo '::endgroup::'
 
 npx --no-install -c 'stylelint --version'
@@ -44,7 +58,9 @@ fi
 
 if [ -n "${INPUT_PACKAGES}" ]; then
   echo '::group:: Running `npm install` to install input packages ...'
-  npm install ${INPUT_PACKAGES}
+  pkg_args=()
+  read -r -d '' -a pkg_args <<< "${INPUT_PACKAGES}" || true
+  npm install "${pkg_args[@]}"
   echo '::endgroup::'
 fi
 

```

Locations:

- `script.sh`

## Iteration Notes

### Iteration 1

**Fixes applied:** script-injection, unsafe-shell, prior-fix

**Notes:**

I rewrote script.sh. It now starts with #!/usr/bin/env bash, which is safe because this is a composite action and the step already runs under shell: bash. No test runs were done after the change.

- **stylelint command:** the command is now built as an argument array and run with `npx --no-install stylelint "${cmd_args[@]}"`, so it no longer goes through `npx -c` and its shell. stylelint_input is split the way a shell would split it, respecting quotes but evaluating nothing (the xargs split plus the `xargs -r true` check for an unmatched quote, guarded so an empty value adds no argument). Config and ignore are passed as `--config=$VAR` and `--ignore-pattern=$VAR`. One change from upstream: upstream's shell could expand a glob like `**/*.css` before stylelint saw it. Now the pattern reaches stylelint as text and stylelint matches the files itself.
- **npm packages:** the packages input is split into an array with an unquoted assignment and a shellcheck SC2206 directive. That keeps upstream's whitespace split and glob behaviour, then the array is passed quoted to `npm install`.
- **reviewdog install:** the installer is saved to a temp file, checked that it isn't empty, run as `sh "$INSTALL_SCRIPT" -b "$TEMP_PATH" "$REVIEWDOG_VERSION"` (with `-s --` dropped), then deleted. If the download fails, the script prints a message and carries on, the same way upstream's pipe did.

This repeats the previous harden's patch, except for the packages split: that one now uses the unquoted array assignment rather than `read -a`, because `read -a` would not expand globs.

