#!/bin/bash
# make must rebuild a command's generated help when any help source it is
# built from changes, and must not rebuild it when nothing changed. Builds a
# copy of the tree in the temporary HOME, so the real build/ is never touched.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

repo="$(dirname "${tests_dir}")"
tree="${HOME}/tree"
mkdir -p "${tree}"
cp -R "${repo}/Makefile" "${repo}/src" "${tree}/"
# linked, not copied: the temporary folder may be mounted noexec
ln -s "${repo}/scripts" "${tree}/scripts"
# backdate the sources so an edit below is always newer than the build output
find "${tree}/Makefile" "${tree}/src" -exec touch -d '2000-01-01' {} +

build() {
  make -C "${tree}" -s sca >/dev/null 2>&1 || fail "make failed"
}

# up_to_date TARGET - make has nothing to do for TARGET
up_to_date() {
  make -C "${tree}" -q "$1" >/dev/null 2>&1
}

# check_rebuilds FILE TARGET - appending a marker to FILE rebuilds TARGET and
# the marker reaches build/sca.sh
check_rebuilds() {
  local file=$1 target=$2 marker
  marker="marker-$(basename "$(dirname "$(dirname "${file}")")")-$(basename "${file}" .txt)"
  up_to_date "${target}" || fail "${target} out of date before editing ${file}"
  echo "${marker}" >> "${tree}/${file}"
  up_to_date "${target}" && fail "${target} not invalidated by ${file}"
  build
  grep -q "${marker}" "${tree}/build/sca.sh" \
    || fail "edit to ${file} did not reach build/sca.sh"
}

build
assert_file_exists "${tree}/build/sca.sh" "initial build"

# nothing changed: no generated help is rebuilt
up_to_date build/create/help/help.txt || fail "create help rebuilt with no changes"
up_to_date build/create/key/help/help.txt || fail "create key help rebuilt with no changes"

# every help source of a subcommand and a top-level command
for source in command_title abstract syntax options; do
  check_rebuilds "src/create/key/help/${source}.txt" build/create/key/help/help.txt
done
for source in command_title abstract syntax options further_read; do
  check_rebuilds "src/display/help/${source}.txt" build/display/help/help.txt
done

# a subcommand's further_read.txt is only used when its parent has none, so it
# is a prerequisite but its edit may not show up in the output
up_to_date build/create/key/help/help.txt || fail "create key help out of date"
touch "${tree}/src/create/key/help/further_read.txt"
up_to_date build/create/key/help/help.txt \
  && fail "create key help not invalidated by its further_read.txt"
build

# the parent's options.txt and further_read.txt are read for subcommands
touch "${tree}/src/create/help/options.txt"
up_to_date build/create/key/help/help.txt \
  && fail "create key help not invalidated by parent options.txt"
build
check_rebuilds src/create/help/further_read.txt build/create/key/help/help.txt

# src/help/options.txt is read for every command
touch "${tree}/src/help/options.txt"
up_to_date build/create/key/help/help.txt \
  && fail "create key help not invalidated by src/help/options.txt"
up_to_date build/display/help/help.txt \
  && fail "display help not invalidated by src/help/options.txt"
build

test_done
