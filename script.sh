#!/bin/sh

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
STYLELINT_FORMATTER="${GITHUB_ACTION_PATH}/stylelint-formatter-rdjson/index.js"

__run_stylelint() {
  set --
  set -- stylelint "${INPUT_STYLELINT_INPUT}" --custom-formatter "${STYLELINT_FORMATTER}"

  if [ -n "${INPUT_STYLELINT_CONFIG}" ]; then
    set -- "$@" --config="${INPUT_STYLELINT_CONFIG}"
  fi

  if [ -n "${INPUT_STYLELINT_IGNORE}" ]; then
    set -- "$@" --ignore-pattern="${INPUT_STYLELINT_IGNORE}"
  fi

  npx --no-install "$@" 2>&1
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
curl -sfL -o "${INSTALL_SCRIPT}" https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh
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
  # Split INPUT_PACKAGES on whitespace into individual package arguments.
  # Disable glob expansion (set -f) to prevent metacharacter/glob injection,
  # then restore it (set +f) immediately after the split.
  set -f
  # shellcheck disable=SC2086
  set -- ${INPUT_PACKAGES}
  set +f
  # Validate that no token looks like a flag (starts with '-') to prevent
  # argument injection (e.g. --ignore-scripts=false).
  for _pkg in "$@"; do
    case "${_pkg}" in
      -*)
        echo "Error: invalid package name '${_pkg}' (flags are not allowed in packages input)" >&2
        exit 1
        ;;
    esac
  done
  npm install "$@"
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
