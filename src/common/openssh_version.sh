################################################################################
# prints the version of the installed OpenSSH client as <major>.<minor>, taken
# from ssh -V. prints nothing when ssh is missing or isn't OpenSSH.
openssh_client_version() {
  ssh -V 2>&1 | sed -n 's/^OpenSSH_\([0-9]*\.[0-9]*\).*/\1/p'
}
################################################################################
# succeeds when the OpenSSH version given as <major>.<minor> is at least the
# given minimum, also <major>.<minor>
#
# parameters
#   version - the version to check, e.g. 8.9
#   minimum - the lowest version that passes, e.g. 8.2
openssh_version_at_least() {
  local version=$1
  local minimum=$2
  local major=${version%%.*}
  local minor=${version#*.}
  local minimum_major=${minimum%%.*}
  local minimum_minor=${minimum#*.}
  [ "$major" -gt "$minimum_major" ] || \
    { [ "$major" -eq "$minimum_major" ] && [ "$minor" -ge "$minimum_minor" ]; }
}
