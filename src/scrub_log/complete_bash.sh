_sca_scrub_log_complete() {
  local scrub_log_index=$1
  local file_index=$((scrub_log_index+1))

  while [[ ${COMP_WORDS[$file_index]} == -* ]]; do
    if [ "$COMP_CWORD" == "$file_index" ]; then
      mapfile -t suggestions < <(compgen -W "-h --help" -- "$current_word")
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    file_index=$((file_index+1))
  done

  if [ "$COMP_CWORD" == "$file_index" ]; then
    mapfile -t suggestions < <(compgen -f -- "$current_word")
  fi
}
