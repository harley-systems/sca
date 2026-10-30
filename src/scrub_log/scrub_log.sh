################################################################################
# redact secrets from a log file that is already written
#
# the code no longer logs a pin or a management key, but a log written by an
# older version can still hold them. this runs the same redact_secrets() that
# log() applies to new lines over the whole file, so there is one set of
# patterns to maintain.
#
# parameters
#   file
#     the log file to scrub. optional. defaults to the sca log file.
#
scrub_log() {

  # read the options
  local OPTS
  OPTS=$(getopt -o h --long help -n 'scrub_log' -- "$@")
  if [ $? != 0 ] ; then error "failed parsing options. use sca scrub_log -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        scrub_log_help
        return
        ;;
      -- )
        shift
        break
        ;;
      * )
        break
        ;;
    esac
  done

  # read the parameters
  local file=${1:-${log_file}}

  log_detailed "scrub_log: start (file=${file})"

  if [ ! -f "${file}" ]; then
    error "scrub_log: the log file '${file}' doesn't exist." 1
  fi

  # if the log is a symlink, scrub the file it points to. replacing the link
  # itself would leave the secrets in the real file.
  local real_file
  real_file=$(readlink -f -- "${file}") \
    || error "scrub_log: failed resolving the path of '${file}'." 1
  [ "${real_file}" != "${file}" ] && log_detailed "scrub_log: '${file}' resolves to '${real_file}'"
  file=${real_file}

  # write the scrubbed copy next to the original and move it over, so an
  # interrupted run never leaves a half-written log. the copy is created 0600.
  local scrubbed_file
  scrubbed_file=$(umask 077; mktemp "${file}.XXXXXX") \
    || error "scrub_log: failed creating a temporary file next to '${file}'." 1
  if ! redact_secrets < "${file}" > "${scrubbed_file}"; then
    rm -f "${scrubbed_file}"
    error "scrub_log: failed redacting '${file}'. the file was left unchanged." 1
  fi

  if cmp -s "${file}" "${scrubbed_file}"; then
    rm -f "${scrubbed_file}"
    chmod 600 "${file}"
    echo "no secrets found in ${file}."
  else
    # a hard-linked log has to be rewritten in place, so every name of it sees
    # the redaction. otherwise move the copy over it, which is atomic.
    local link_count
    link_count=$(stat -c %h "${file}" 2>/dev/null || stat -f %l "${file}" 2>/dev/null)
    if [ "${link_count:-1}" -gt 1 ]; then
      log_detailed "scrub_log: '${file}' has ${link_count} hard links, rewriting it in place"
      if ! { chmod 600 "${file}" && cat "${scrubbed_file}" > "${file}"; }; then
        error "scrub_log: failed writing the redacted log to '${file}'. the redacted copy is in '${scrubbed_file}'." 1
      fi
      rm -f "${scrubbed_file}"
    elif ! mv -f "${scrubbed_file}" "${file}"; then
      rm -f "${scrubbed_file}"
      error "scrub_log: failed replacing '${file}' with the redacted copy. the file was left unchanged." 1
    fi
    echo "secrets redacted from ${file}."
  fi

  log_detailed "scrub_log: finish (file=${file})"
}
scrub_log_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
