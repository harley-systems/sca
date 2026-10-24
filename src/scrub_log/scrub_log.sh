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
    chmod 600 "${scrubbed_file}"
    mv -f "${scrubbed_file}" "${file}"
    echo "secrets redacted from ${file}."
  fi

  log_detailed "scrub_log: finish (file=${file})"
}
scrub_log_help() {
  echo "
@@@HELP@@@
  "
}
