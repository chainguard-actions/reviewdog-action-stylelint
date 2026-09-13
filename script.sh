#!/bin/bash

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
STYLELINT_FORMATTER="${GITHUB_ACTION_PATH}/stylelint-formatter-rdjson/index.js"

__run_stylelint() {
  # Tokenize INPUT_STYLELINT_INPUT (a whitespace-separated list of files/globs)
  # into an array using xargs for proper quote-aware splitting.
  stylelint_inputs=()
  if [ -n "${INPUT_STYLELINT_INPUT}" ]; then
    while IFS= read -r -d '' t; do stylelint_inputs+=("$t"); done \
      < <(printf '%s' "${INPUT_STYLELINT_INPUT}" | xargs printf '%s\0')
  fi

  cmd=(stylelint "${stylelint_inputs[@]}" --custom-formatter "${STYLELINT_FORMATTER}")

  if [ -n "${INPUT_STYLELINT_CONFIG}" ]; then
    cmd+=(--config="${INPUT_STYLELINT_CONFIG}")
  fi

  if [ -n "${INPUT_STYLELINT_IGNORE}" ]; then
    cmd+=(--ignore-pattern="${INPUT_STYLELINT_IGNORE}")
  fi

  "${cmd[@]}" 2>&1
}

__run_reviewdog() {
  reviewdog -f=rdjson \
            -name="${INPUT_NAME}" \
            -reporter="${INPUT_REPORTER}" \
            -level="${INPUT_LEVEL}" \
            -filter-mode="${INPUT_FILTER_MODE}" \
            -fail-level="${INPUT_FAIL_LEVEL}" \
            -fail-on-error="${INPUT_FAIL_ON_ERROR}"
}

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

echo '::group:: Installing reviewdog 🐶 ... https://github.com/reviewdog/reviewdog'
INSTALL_SCRIPT="$(mktemp)"
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "${INSTALL_SCRIPT}"
sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
rm -f "${INSTALL_SCRIPT}"
echo '::endgroup::'

npx --no-install -c 'stylelint --version'
if [ $? -ne 0 ]; then
  echo '::group:: Running `npm install` to install stylelint ...'
  npm install
  echo '::endgroup::'
fi

if [ -n "${INPUT_PACKAGES}" ]; then
  echo '::group:: Running `npm install` to install input packages ...'
  # Tokenize INPUT_PACKAGES (a whitespace-separated list) into an array
  # using xargs for proper quote-aware splitting.
  packages=()
  while IFS= read -r -d '' t; do packages+=("$t"); done \
    < <(printf '%s' "${INPUT_PACKAGES}" | xargs printf '%s\0')
  npm install "${packages[@]}"
  echo '::endgroup::'
fi

echo "stylelint version: $(npx --no-install -c 'stylelint --version')"

echo '::group:: Running stylelint with reviewdog 🐶 ...'
stylelint_results=$(__run_stylelint)

# stylelint exit codes are documented here:
# https://stylelint.io/user-guide/cli/#exit-codes
stylelint_rc=$?
if [ $stylelint_rc -ne 0 ] && [ $stylelint_rc -ne 2 ]; then
  echo 'stylelint failed'
  echo "${stylelint_results}"
  echo '::endgroup::'
  exit $stylelint_rc
fi

echo "${stylelint_results}" | __run_reviewdog

reviewdog_rc=$?
echo '::endgroup::'
exit $reviewdog_rc
