_sca_appliance_complete() {
  local appliance_verb_index=$1
  local subcommand_index=$((appliance_verb_index+1))
  while [[ ${COMP_WORDS[$subcommand_index]} == -* ]]; do
    if [ $COMP_CWORD == $subcommand_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      return
    fi
    subcommand_index=$((subcommand_index+1))
  done
  if [ -z "${COMP_WORDS[$subcommand_index]}" ]; then
    suggestions=($(compgen -W "info verify" -- "$current_word"))
  else
    case "${COMP_WORDS[$subcommand_index]}" in
      info|verify )
        _sca_appliance_platform_option_complete $subcommand_index
      ;;
      *)
        suggestions=($(compgen -W "info verify" -- "$current_word"))
      ;;
    esac
  fi
}
# the options of info and verify, and the platform names for --platform
_sca_appliance_platform_option_complete() {
  local subcommand_index=$1
  local option_index=$((subcommand_index+1))
  while [ $option_index -lt $COMP_CWORD ]; do
    if [ "${COMP_WORDS[$option_index]}" == --platform ]; then
      if [ $((option_index+1)) == $COMP_CWORD ]; then
        suggestions=($(compgen -W "@@@APPLIANCE PLATFORMS@@@" -- "$current_word"))
        return
      fi
      option_index=$((option_index+1))
    fi
    option_index=$((option_index+1))
  done
  if [ $COMP_CWORD == $option_index ]; then
    suggestions=($(compgen -W "-h --help --platform" -- "$current_word"))
  fi
}
