################################################################################
# the only ubuntu version id supported for the sca usb stick image and for the
# host that builds it. it has the form <major>.<minor>-<release_name>. the
# latest point release of this version is downloaded.
#
# the value is defined once, as UBUNTU_VERSION_ID in the Makefile, and
# substituted at build time here, in the help texts and in bash completion.
sca_ubuntu_version_id="@@@UBUNTU VERSION ID@@@"
################################################################################
# fails unless the given ubuntu version id is the supported one
#
# parameters
#   ubuntu_version_id - the version id to check
#   command           - the sca command to name in the error message
check_ubuntu_version_id() {
  local ubuntu_version_id=$1
  local command=$2

  if [ "$ubuntu_version_id" != "$sca_ubuntu_version_id" ]; then
    error "${command}: unsupported ubuntu version id '${ubuntu_version_id}'. the only supported ubuntu version id is '${sca_ubuntu_version_id}'." 1
  fi
}
################################################################################
# fails unless this host runs the supported ubuntu version. the sca usb stick
# packages are resolved against this host's apt sources, so they have to be the
# same release as the image.
#
# parameters
#   command           - the sca command to name in the error message
check_build_host_ubuntu_version() {
  local command=$1
  local required_version_number=${sca_ubuntu_version_id%%-*}
  local host_id=""
  local host_version_number=""

  if [ -f /etc/os-release ]; then
    host_id=$(. /etc/os-release && echo "$ID")
    host_version_number=$(. /etc/os-release && echo "$VERSION_ID")
  fi
  if [ "$host_id" != "ubuntu" ] || [ "$host_version_number" != "$required_version_number" ]; then
    error "${command}: this host runs '${host_id:-unknown} ${host_version_number:-unknown}'. building the sca usb stick requires an ubuntu ${required_version_number} host." 1
  fi
}
