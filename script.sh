#!/bin/bash

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
STYLELINT_FORMATTER="${GITHUB_ACTION_PATH}/stylelint-formatter-rdjson/index.js"

__run_stylelint() {
  # Build the stylelint command as an array to avoid shell injection
  stylelint_args=("${INPUT_STYLELINT_INPUT}" "--custom-formatter" "${STYLELINT_FORMATTER}")

  if [ -n "${INPUT_STYLELINT_CONFIG}" ]; then
    stylelint_args+=("--config=${INPUT_STYLELINT_CONFIG}")
  fi

  if [ -n "${INPUT_STYLELINT_IGNORE}" ]; then
    stylelint_args+=("--ignore-pattern=${INPUT_STYLELINT_IGNORE}")
  fi

  npx --no-install stylelint "${stylelint_args[@]}" 2>&1
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
# Download install script to a temp file before executing to avoid unsafe pipe-to-shell
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
  # Use read -ra to safely split the packages string into an array
  read -ra packages_array <<< "${INPUT_PACKAGES}"
  npm install "${packages_array[@]}"
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
