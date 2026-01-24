#!/bin/bash
################################################################################
# simple ca - main entry method
#
# parameters
#   verb
#     the verb (action) you want to run
#     allowed values are:
#       - create
#       - display
#       - export
#       - import
#       - init
#       - install
#       - request
#       - security_key
#       - approve
#       - config
#       - list
#       - completion
#       - test
sca() {
  export config_file
  export conventions_file
  export log_file=~/.sca/log

  # OPTS=`getopt -o vdhc: --long verbose,detailed-verbose,help,config-file: -n 'sca' -- "$@"`
  # if [ $? != 0 ] ; then error "failed parsing options. use sca -h for help." 1; fi
  while true; do
    case "$1" in
      -v | --verbose )
        verbosity=v
        shift
        ;;
      -d | --detailed-verbose )
        verbosity=vv
        shift
        ;;
      -h | --help )
        sca_help
        return
        ;;
      -c | --config-file )
        config_file="$2"; shift; shift
        ;;
#      -s | --stack-size ) STACK_SIZE="$2"; shift; shift ;;
      -- )
        shift
        break
        ;;
      * )
        break
        ;;
    esac
  done
  verb=$1

  [ -f ${log_file} ] && touch ${log_file}

  log_detailed "sca: start (verb=${verb})"

  # if sca_conf_folder not set, use the default /etc/ssl/ location
  [ -z ${sca_conf_folder} ] && sca_conf_folder=~/.sca/config/

  # if config file was not provided use the default location
  if [ -z ${config_file} ]; then
    log_detailed "sca: no config file specified. defaulting to sca.config"
    config_file=${sca_conf_folder}sca.config
  fi

  # check if config file was specified in relative form
  # relative form assumes either
  #   ${sca_conf_folder}
  #   ${demo_folder}
  # as a parent folder for the config file. so we test both of them and if file
  # is found we use it. the ${sca_conf_folder} has precedance.
  log_detailed "sca: sca_conf_folder ${sca_conf_folder} sca_conf_folder_default ${sca_conf_folder_default}  demo_folder ${demo_folder} demo_folder_default ${demo_folder_default}"
  if [ -f ${sca_conf_folder}${config_file} ]; then
    config_file=${sca_conf_folder}${config_file}
    log_detailed "sca: the ${config_file} found in ${sca_conf_folder} folder. using ${config_file} ."
  else
    if [ -z ${demo_folder} ] && [ -f ${sca_conf_folder}sca.config ]; then
        # pre-load default sca.config do resolve default demo
        log_detailed "sca: preloading ${sca_conf_folder}sca.config to resolve demo_folder"
        . ${sca_conf_folder}sca.config
        demo_folder=$demo_folder_default
    fi
    if [ -f ${demo_folder}${config_file} ]; then
      config_file=${demo_folder}${config_file}
      log_detailed "sca: the ${config_file} found in ${demo_folder} folder. using ${config_file}."
    fi
  fi
  # if conventions file was not provided use the default location
  if [ -z ${conventions_file} ]; then
    conventions_file=${sca_conf_folder}sca.conventions
    log_detailed "sca: conventions file was not provided. assuming  $conventions_file"
  fi

  # fail if sca_config is not present, otherwise load it
  if [ ! -f ${config_file} ]; then
    if [ ! -z $verb ] && [ $verb != config ] && [ ! -z $2 ] && [ $2 != create ]; then
      error "the sca configuration file ${config_file} doesn't
exist. if this is the first time run, make sure to run

  sudo sca config create all

otherwise,
- check the sca_conf_folder environment variable.
- run 'sca config create -h' to read on sca configuration
- for general info on sca run 'sca -h'
exiting.

" 1
    fi
    log_detailed "sca: configuration file ${config_file} doesn't exist but creating it now."
  else
    log_detailed "sca: ${config_file} found. loading config from it."
    config_load ${config_file} ${conventions_file}
  fi

  log_detailed "sca: OPTS=${OPTS}"
  # eval set -- "$OPTS"

  case "$verb" in
    create|display|export|import|init|request|security_key|approve|config|list|completion|install|test)
      shift
      log_detailed "sca: calling function for the verb $verb "$@""
      if [ $verb == 'export' ]; then eval ${verb}_ "${@@Q}"; else eval $verb "${@@Q}"; fi
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$verb' for first argument - the command.
        supported commands are 'create' 'display' 'export' 'import' 'init' 'install'
        'request' 'security_key' 'approve' 'completion' 'test'.
____EOM
      error "$message" 1
      ;;
  esac
  log_detailed "sca:  finish (verb=${verb})"
  return 0
}
sca_help() {
  echo "
@@@HELP@@@
  "
}
################################################################################
# error reporting and failing
#
# parameters
#   message
#     message to display
#   exit_code
#     exit code to use when exiting the program
#
error() {
  message=$1
  exit_code=$2
  >&2 echo $1
  exit $2
}
################################################################################
# resolve relative subfolder
#
# parameters
#   - result (relative subfolder) environment variable name
#   - reference parent folder - fullpath relative to which we return the result
#   - file full path
# returns
#   the file name without the path
# example call
# get_relative_subfolder subca_files_folder_suffix ${key_folder} ${subca_crt_file}
get_relative_subfolder() {
   local __resultvar=$1
   local __ref_parent_folder=$2
   local __file_fullpath=$3
   log_extreemly_detailed "get_relative_subfolder start (__resultvar=${__resultvar},__ref_parent_folder=${__ref_parent_folder},__file_fullpath=${__file_fullpath})"
   local __base_name=$(basename $__file_fullpath)
   local folder_suffix=${__file_fullpath:${#__ref_parent_folder}:`expr ${#__file_fullpath} - ${#__ref_parent_folder} - ${#__base_name}`}
   eval $__resultvar="'$folder_suffix'"
   log_extreemly_detailed "get_relative_subfolder finish (__resultvar=${__resultvar},__ref_parent_folder=${__ref_parent_folder},__file_fullpath=${__file_fullpath})"
}
log_extreemly_detailed() {
  message="${@}"
  [[ $verbosity == vvv* ]] && log "${message}"
}
log_detailed() {
  message="${@}"
  [[ $verbosity == vv* ]] && log "${message}"
}
log_verbose() {
  message="${@}"
  [[ $verbosity == v* ]] && log "${message}"
}
log() {
  message="${@}"
  echo "${message}" >> ${log_file}
}
