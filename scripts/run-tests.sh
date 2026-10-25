#!/bin/bash
################################################################################
# run every tests/test_*.sh and report which ones failed
#
# each test file sources tests/lib.sh, which gives it its own temporary HOME.
# exits non-zero if any test file fails.

cd "$(dirname "$0")/.." || exit 2

passed=0
failed=()
for test_file in tests/test_*.sh; do
  [ -f "${test_file}" ] || continue
  echo "${test_file}"
  if bash "${test_file}"; then
    passed=$((passed + 1))
  else
    failed+=("${test_file}")
  fi
done

echo
echo "${passed} passed, ${#failed[@]} failed"
for test_file in "${failed[@]}"; do
  echo "  failed: ${test_file}"
done
[ ${#failed[@]} -eq 0 ]
