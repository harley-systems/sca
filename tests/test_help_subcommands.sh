#!/bin/bash
# every subcommand a dispatcher's case accepts is listed in the command's
# --help, and a subcommand's own further_read.txt replaces its parent's.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

src_dir="$(dirname "${tests_dir}")/src"

# command:variable the dispatcher in src/<command>/<command>.sh switches on.
# import takes no subcommand, so it has nothing to check.
dispatchers=(
  security_key:security_key_command
  create:document_type
  display:document_type
  export:document_type
  config:config_verb
  init:system
  list:list_entity
  request:entity
)

# command:name accepted only to reject it, so not listed in help
excluded=(
  init:yubikey # replaced by security_key init, see test_init_yubikey_removed.sh
)

# dispatcher_names COMMAND VARIABLE - print the arm labels of the case on
# VARIABLE, one per line. The block ends at the esac with the same indentation
# as its case, so a case nested in an arm (display matches "$1" in one) is
# skipped; labels starting with - (options like -h) are dropped as well.
dispatcher_names() {
  local command=$1 variable=$2
  awk -v var="${variable}" '
    !inside && $0 ~ "^ *case \"?\\$" var "\"? in *$" {
      inside = 1
      match($0, /^ */); indent = RLENGTH
      next
    }
    inside {
      match($0, /^ */)
      if ($1 == "esac" && RLENGTH == indent) exit
      if ($1 == "case") { nested++; next }
      if ($1 == "esac") { nested--; next }
      if (nested) next
      # an arm label line: name|name... ) with nothing after it
      if ($0 ~ /^ *[^()#;"$]+\) *$/) {
        sub(/\).*/, ""); gsub(/ /, "")
        n = split($0, labels, "|")
        for (i = 1; i <= n; i++)
          if (labels[i] != "*" && labels[i] !~ /^-/) print labels[i]
      }
    }
  ' "${src_dir}/${command}/${command}.sh"
}

# --help may need a configuration to exist
sca config create all >/dev/null 2>&1

for entry in "${dispatchers[@]}"; do
  command=${entry%%:*}
  variable=${entry#*:}
  names=$(dispatcher_names "${command}" "${variable}")
  if [ -z "${names}" ]; then
    fail "${command}: no subcommands found in the case on \$${variable}"
    continue
  fi
  help=$(sca "${command}" --help 2>&1)
  while IFS= read -r name; do
    [[ " ${excluded[*]} " == *" ${command}:${name} "* ]] && continue
    grep -qE "^ *(- +)?${name} +- " <<< "${help}" \
      || fail "sca ${command} --help does not list '${name}'"
  done <<< "${names}"
done

# a subcommand's own further_read.txt replaces its parent's
help=$(sca create key --help 2>&1)
grep -qF "sca security_key init --help" <<< "${help}" \
  || fail "sca create key --help lacks its own further read text"
grep -qF "Run 'sca create <document_type> -h'" <<< "${help}" \
  && fail "sca create key --help shows its parent's further read text"

# an empty one falls back to the parent's
help=$(sca create csr --help 2>&1)
grep -qF "Run 'sca create <document_type> -h'" <<< "${help}" \
  || fail "sca create csr --help lacks its parent's further read text"

test_done
