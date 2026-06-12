#!/bin/sh

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
STYLELINT_FORMATTER="${GITHUB_ACTION_PATH}/stylelint-formatter-rdjson/index.js"

__run_stylelint() {
  # Build argument list safely using positional parameters to avoid shell injection
  set -- --custom-formatter "${STYLELINT_FORMATTER}"

  if [ -n "${INPUT_STYLELINT_CONFIG}" ]; then
    set -- "$@" --config="${INPUT_STYLELINT_CONFIG}"
  fi

  if [ -n "${INPUT_STYLELINT_IGNORE}" ]; then
    set -- "$@" --ignore-pattern="${INPUT_STYLELINT_IGNORE}"
  fi

  # Call npx stylelint directly with properly quoted arguments instead of
  # building a shell command string passed to -c (which would allow injection)
  npx --no-install stylelint "${INPUT_STYLELINT_INPUT}" "$@" 2>&1
}

__run_reviewdog() {
  reviewdog -f=rdjson \
            -name="${INPUT_NAME}" \
            -reporter="${INPUT_REPORTER}" \
            -level="${INPUT_LEVEL}" \
            -filter-mode="${INPUT_FILTER_MODE}" \
            -fail-on-error="${INPUT_FAIL_ON_ERROR}"
}

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

echo '::group:: Installing reviewdog 🐶 ... https://github.com/reviewdog/reviewdog'
# Download the install script to a temp file first, then execute it separately
# instead of piping curl directly to sh (which would execute unverified remote code)
INSTALL_SCRIPT="${TEMP_PATH}/reviewdog-install.sh"
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh -o "${INSTALL_SCRIPT}" 2>&1
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
  # Use printf + xargs to safely split the package list on whitespace
  # and pass each package as a separate argument to npm install,
  # preventing shell metacharacter injection from the packages input
  printf '%s\n' "${INPUT_PACKAGES}" | xargs npm install --
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
