#!/bin/bash
# smoke test: the built sca runs and prints help
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

assert_succeeds sca --help
assert_succeeds sca config --help

test_done
