_sca_complete() {
  # completion environment variables
  #  COMP_WORDS: an array of all the words typed after the name of the program the
  #     compspec belongs to (words in the current command line)
  #  COMP_CWORD: an index of the COMP_WORDS array pointing to the word the current
  #     cursor is at - in other words, the index of the word the cursor was when
  #     the tab key was pressed. So COMP_WORDS[COMP_CWORD] is the current word
  #  COMP_LINE: the current command line

  # the command being completed - will be sca
  local command_completed=$1
  # the current word being completed
  local current_word=$2
  # previous word on the command line
  local previous_word=$3

  # so the above should be equivalent to :
  # current_word="${COMP_WORDS[COMP_CWORD]}"
  # previous_word="${COMP_WORDS[COMP_CWORD-1]}"


  local suggestions
  # index of the sca verb on the command line. we set it initially to 1, but
  # search for the proper value as there may be some parameters specified.
  local sca_verb_index=1

  # default config file fullname
  #local config_file=/etc/ssl/sca.config
  local config_file=~/.sca/config/sca.config

  if [ DEBUG = true ]; then
    tput sc         # Save cursor position
    tput cup 0 100   # Move to row 6 col 11
    printf %100s
    tput cup 0 100   # Move to row 6 col 11
    echo "command_completed:'${command_completed}' current_word:'${current_word}' previous_word:'${previous_word}' compwords length:${#COMP_WORDS[@]} comp_cword:$COMP_CWORD"
  fi

  # find the sca verb index on the command line by skipping over any options
  # that are specified on the command line
  while [[ ${COMP_WORDS[$sca_verb_index]} == -* ]]; do
    # ${COMP_WORDS[$sca_verb_index]} is an option

    if [ DEBUG = true ]; then
      tput cup $sca_verb_index 100   # Move to row 6 col 11
      printf %100s
      tput cup $sca_verb_index 100   # Move to row 6 col 11
      echo "sca_verb_index:'$sca_verb_index' compwords[sca_verb_index]:'${COMP_WORDS[$sca_verb_index]}'"
    fi

    # in case the cursor is at the current $sca_verb_index word, return
    # sca options as completion suggestions
    if [ $COMP_CWORD == $sca_verb_index ]; then
      if [ DEBUG = true ]; then
        echo "curor is at current $sca_verb_index. providing completions"
        tput rc # Restore cursor position
      fi
      suggestions=($(compgen -W "-h --help -v --verbose -d --detailed-verbose -c --config-file" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi

    # the cursor is not on the current $sca_verb_index

    # check if current option at $sca_verb_index is the configuration file option
    if [ ${COMP_WORDS[$sca_verb_index]} == --config-file ] || [ ${COMP_WORDS[$sca_verb_index]} == -c ]; then
      # the currently processed option at $sca_verb_index is the configuration file option
      if [ DEBUG = true ]; then
        echo "currently processed option at $sca_verb_index is the configuration file option"
      fi

      # check if the cursor is now on the next option to process. in other words
      # check if the following option at $sca_verb_index+1 is the current word
      if [  $((sca_verb_index+1)) == $COMP_CWORD ]; then

        # cursor is now on the next option to process, after the -c option. completing...

        if [ DEBUG = true ]; then
          echo "following option at $sca_verb_index+1 is the current word. completing..."
        fi
        configs=$(sca list configs)
        if [ DEBUG = true ]; then
          echo "configs:${configs}"
          tput rc # Restore cursor position
        fi
        suggestions=($(compgen -W "$configs" -- "$current_word"))
        COMPREPLY=("${suggestions[@]}")
        return
      else

        # following option at $sca_verb_index+1 is not the current word.

        # check if the configuration file has been already specified after the
        # current option at $sca_verb_index
        if [ $((sca_verb_index+1)) -lt ${#COMP_WORDS[@]} ]; then

          # the configuration file has been already specified after the
          # current option

          config_file=${COMP_WORDS[$((sca_verb_index+1))]}

          sca_verb_index=$((sca_verb_index+1))
          if [ DEBUG = true ]; then
            echo "config_file:'${config_file}'"
          fi
        fi
      fi
    fi
    sca_verb_index=$((sca_verb_index+1))
  done

  if [ DEBUG = true ]; then
    tput rc # Restore cursor position
  fi

  if [ -z "${COMP_WORDS[${sca_verb_index}]}" ]; then
    suggestions=($(compgen -W "create display export import init install list request security_key approve config completion test" -- "$current_word"))
  else
    case "${COMP_WORDS[${sca_verb_index}]}" in
      create)
        _sca_create_complete ${sca_verb_index}
        ;;
      display)
        _sca_display_complete ${sca_verb_index}
        ;;
      export)
        _sca_export_complete ${sca_verb_index}
        ;;
      import)
        _sca_import_complete ${sca_verb_index}
        ;;
      init)
        _sca_init_complete ${sca_verb_index}
        ;;
      install)
        _sca_install_complete ${sca_verb_index}
        ;;
      list)
        _sca_list_complete ${sca_verb_index}
        ;;
      request)
        _sca_request_complete ${sca_verb_index}
        ;;
      security_key)
        _sca_security_key_complete ${sca_verb_index}
        ;;
      approve)
        _sca_approve_complete ${sca_verb_index}
        ;;
      config)
        _sca_config_complete ${sca_verb_index}
        ;;
      completion)
        _sca_completion_complete ${sca_verb_index}
        ;;
      test)
        _sca_test_complete ${sca_verb_index}
        ;;
      *)
        suggestions=($(compgen -W "create display export import init install list request security_key approve config completion test" -- "$current_word"))
        ;;
    esac
  fi
  #local suggestions=($(compgen -W "$(fc -l -50 | sed 's/\t//')" -- "${COMP_WORDS[1]}"))
  #local suggestions=($(compgen -W "create display export import init request approve config" -- "${COMP_WORDS[1]}"))
  #local suggestions=($(compgen -W "create display export import init request approve config" -- "$current_word"))
  COMPREPLY=("${suggestions[@]}")
}
function pos
{
    local CURPOS
    read -sdR -p $'\E[6n' CURPOS
    CURPOS=${CURPOS#*[} # Strip decoration characters <ESC>[
    echo "${CURPOS}"    # Return position in "row;col" format
}
function row
{
    local COL
    local ROW
    IFS=';' read -sdR -p $'\E[6n' ROW COL
    echo "${ROW#*[}"
}
function col
{
    local COL
    local ROW
    IFS=';' read -sdR -p $'\E[6n' ROW COL
    echo "${COL}"
}
DEBUG=false
complete -F _sca_complete sca
