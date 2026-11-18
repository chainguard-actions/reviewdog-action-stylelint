<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-stylelint/v1.32.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `374911c4be584df24e6da57af2d990570ef0f859`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-stylelint/v1.32.0** was hardened automatically. 5 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### script-injection (severity: high)

Rule (b): script.sh (run by the composite step in action.yml) builds a shell command string from workflow-controlled inputs and runs it with `npx --no-install -c "${cmd}"`, which passes the string to a shell. INPUT_STYLELINT_INPUT is put in unquoted (line 9: `cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"`). INPUT_STYLELINT_CONFIG and INPUT_STYLELINT_IGNORE are wrapped only in single quotes (lines 12 and 16), so a value containing `'` can break out of them. Any of these inputs can therefore inject shell metacharacters (;, |, $(...)) that the shell started by `npx -c` will run. Fix: pass the values as separate arguments instead of building a command string, e.g. `npx --no-install stylelint "$INPUT_STYLELINT_INPUT" --custom-formatter "$STYLELINT_FORMATTER" ${INPUT_STYLELINT_CONFIG:+--config="$INPUT_STYLELINT_CONFIG"} ...`.

Locations:

- `script.sh:19`
- `script.sh:9`
- `script.sh:12`
- `script.sh:16`

### script-injection (severity: high)

Rule (b): workflow-controlled input expanded without quotes: `npm install ${INPUT_PACKAGES}` (from inputs.packages). This is not an array assignment with a shellcheck directive, so the exception does not apply.

Locations:

- `script.sh:46`

### unsafe-shell (severity: high)

Remote content is piped straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL points to a fixed commit, but the script still runs without being saved to a file first. Download it to a file, then run it as a separate step.

Locations:

- `script.sh:34`

### prior-fix (severity: high)

Carried forward from this version's previous harden, which fixed it; fix it again unless the code no longer has the problem. The previous harden changed action.yml without recording a finding for it, and this analysis reported nothing there. Re-apply its security changes unless the code no longer needs them. The previous patch:
```diff
diff --git a/action.yml b/action.yml
index 08ba630..d90d6a9 100644
--- a/action.yml
+++ b/action.yml
@@ -1,5 +1,5 @@
 name: 'Run stylelint with reviewdog'
-description: '🐶 Run stylelint with reviewdog on pull requests to improve code review experience.'
+description: "\U0001F436 Run stylelint with reviewdog on pull requests to improve code review experience."
 author: 'haya14busa (reviewdog)'
 inputs:
   github_token:
@@ -48,6 +48,23 @@ inputs:
 runs:
   using: 'composite'
   steps:
     - run: $GITHUB_ACTION_PATH/script.sh
       shell: bash
       env:

```

Locations:

- `action.yml`

### prior-fix (severity: high)

Carried forward from this version's previous harden, which fixed it; fix it again unless the code no longer has the problem. The previous harden changed script.sh without recording a finding for it, and this analysis reported nothing there. Re-apply its security changes unless the code no longer needs them. The previous patch:
```diff
diff --git a/script.sh b/script.sh
index f44a805..93be244 100755
--- a/script.sh
+++ b/script.sh
@@ -1,4 +1,4 @@
-#!/bin/sh
+#!/bin/bash
 
 TEMP_PATH="$(mktemp -d)"
 PATH="${TEMP_PATH}:$PATH"
@@ -6,17 +6,25 @@ export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
 STYLELINT_FORMATTER="${GITHUB_ACTION_PATH}/stylelint-formatter-rdjson/index.js"
 
 __run_stylelint() {
-  cmd="stylelint ${INPUT_STYLELINT_INPUT} --custom-formatter ${STYLELINT_FORMATTER}"
+  # Tokenize INPUT_STYLELINT_INPUT (a whitespace-separated list of files/globs)
+  # into an array using xargs for proper quote-aware splitting.
+  stylelint_inputs=()
+  if [ -n "${INPUT_STYLELINT_INPUT}" ]; then
+    while IFS= read -r -d '' t; do stylelint_inputs+=("$t"); done \
+      < <(printf '%s' "${INPUT_STYLELINT_INPUT}" | xargs printf '%s\0')
+  fi
+
+  cmd=(stylelint "${stylelint_inputs[@]}" --custom-formatter "${STYLELINT_FORMATTER}")
 
   if [ -n "${INPUT_STYLELINT_CONFIG}" ]; then
-    cmd="${cmd} --config='${INPUT_STYLELINT_CONFIG}'"
+    cmd+=(--config="${INPUT_STYLELINT_CONFIG}")
   fi
 
   if [ -n "${INPUT_STYLELINT_IGNORE}" ]; then
-    cmd="${cmd} --ignore-pattern='${INPUT_STYLELINT_IGNORE}'"
+    cmd+=(--ignore-pattern="${INPUT_STYLELINT_IGNORE}")
   fi
 
-  npx --no-install -c "${cmd}" 2>&1
+  "${cmd[@]}" 2>&1
 }
 
 __run_reviewdog() {
@@ -32,7 +40,10 @@ __run_reviewdog() {
 cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1
 
 echo '::group:: Installing reviewdog 🐶 ... https://github.com/reviewdog/reviewdog'
-curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+INSTALL_SCRIPT="$(mktemp)"
+curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "${INSTALL_SCRIPT}"
+sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+rm -f "${INSTALL_SCRIPT}"
 echo '::endgroup::'
 
 npx --no-install -c 'stylelint --version'
@@ -44,7 +55,12 @@ fi
 
 if [ -n "${INPUT_PACKAGES}" ]; then
   echo '::group:: Running `npm install` to install input packages ...'
-  npm install ${INPUT_PACKAGES}
+  # Tokenize INPUT_PACKAGES (a whitespace-separated list) into an array
+  # using xargs for proper quote-aware splitting.
+  packages=()
+  while IFS= read -r -d '' t; do packages+=("$t"); done \
+    < <(printf '%s' "${INPUT_PACKAGES}" | xargs printf '%s\0')
+  npm install "${packages[@]}"
   echo '::endgroup::'
 fi
 

```

Locations:

- `script.sh`

## Iteration Notes

### Iteration 1

**Fixes applied:** script-injection, unsafe-shell, prior-fix

**Notes:**

script.sh: I switched the shebang to bash and stopped building a command string for `npx -c`. stylelint now runs as `npx --no-install stylelint "${cmd[@]}"`. stylelint_input is split respecting quotes (an `xargs -r true` check rejects an unmatched quote, then an xargs/sh -c printf NUL loop splits it), because upstream pasted the value into a shell string and the shell honored its quotes. Unlike upstream, the shell no longer expands the input's globs; stylelint expands them itself. --config and --ignore-pattern are each passed as one quoted argument. packages goes into an unquoted array with a shellcheck directive, so it splits and expands globs just as upstream's unquoted ${INPUT_PACKAGES} did. The reviewdog installer is downloaded to a temp file and run with `sh file -b DIR VERSION`, dropping the stdin-only `-s --`. action.yml: I quoted the script path in run:. I did not re-apply the earlier description emoji re-encoding, since it is cosmetic and not a security change.

