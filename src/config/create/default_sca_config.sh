#################################################
# settings
# default value for verbosity level - none, v, vv
export verbosity_default=none

################################################################################
# CA SETTINGS
################################################################################
#
export name_default=harley
#
export caps_name_default=Harley Systems
#
export domain_default=.systems
#
export ca_bits_default=2048
#
export ca_use_security_key_default=true
#
export ca_security_key_type_default=yubikey
# security_key_id identifies the hardware security key.
# For YubiKeys (when ykman is installed): use the decimal hardware serial number
#   from ykman info, grep Serial (stable, does not change with cert uploads).
# For other smart cards: use the hex digits of the card serial from
#   opensc-tool (CHUID format, e.g. 4C-35-1D-D2-5B-DE).
export ca_security_key_id_default="5414483"
# yubico-piv-tool help explains the slots enumeration
# -s, --slot=ENUM          What key slot to operate on  (possible
#                            values="9a", "9c", "9d", "9e", "82",
#                            "83", "84", "85", "86", "87", "88",
#                            "89", "8a", "8b", "8c", "8d", "8e",
#                            "8f", "90", "91", "92", "93", "94",
#                            "95", "f9")
#
#      9a is for PIV Authentication
#      9c is for Digital Signature (PIN always checked)
#      9d is for Key Management
#      9e is for Card Authentication (PIN never checked)
#      82-95 is for Retired Key Management
#      f9 is for Attestation
# mapping between pkcs slot number and yubico slot number
# ykcs11 PKCS#11 ID to YubiKey slot mapping:
# 01 - 9a (PIV Authentication)
# 02 - 9c (Digital Signature)
# 03 - 9d (Key Management)
# 04 - 9e (Card Authentication)
# 05 - 82 (Retired Key 1)
# 06 - 83 (Retired Key 2)
# ...
# 18 - 95 (Retired Key 20)
# 19 - f9 (PIV Attestation)
export ca_pkcs11_id_default="05"
# yubico-piv-tool help explains the pin-policy enumeration
# --pin-policy=ENUM    Set pin policy for action generate or import-key.
#                        Only available on YubiKey 4  (possible
#                        values="never", "once", "always")
export ca_yubikey_pin_policy_default=always
# --touch-policy=ENUM  Set touch policy for action generate, import-key or
# set-mgm-key. Only available on YubiKey 4 (possible values="never", "always",
# "cached")
export ca_yubikey_touch_policy_default=always
################################################################################
# SUBCA SETTINGS
################################################################################
#
export subca_default=aharon
#
export subca_name_default=Aharon
#
export subca_surname_default=Haravon
#
export subca_given_name_default=Aharon
#
export subca_initials_default=A.H.
#
export subca_bits_default=2048
#
export subca_use_security_key_default=true
#
export subca_security_key_type_default=yubikey
#
export subca_security_key_id_default="5414483"
# 9c is for Digital Signature (PIN always checked)
export subca_pkcs11_id_default="02"
#export subca_pkcs11_id_default="pkcs11:model=PKCS%2315%20emulated;manufacturer=piv_II;serial=f6907938c58b8aeb;token=PIV%20Card%20Holder%20pin%20%28PIV_II%29;id=%01;object=PIV%20AUTH%20pubkey;type=public"
#export subca_pkcs11_id_default="pkcs11:serial=f6907938c58b8aeb;id=%02;type=public"
#
export subca_yubikey_pin_policy_default=once
#
export subca_yubikey_touch_policy_default=always
################################################################################
# SERVICE SETTINGS
################################################################################
#
export service_default=vpn
#
export service_bits_default=2048
#
export service_use_security_key_default=false
#
export service_use_k8s_secret_default=true
#
export service_security_key_type_default=
#
export service_security_key_id_default="5414483"
#
export service_pkcs11_id_default="05"
#
export service_yubikey_pin_policy_default=never
#
export service_yubikey_touch_policy_default=never
################################################################################
# HOST SETTINGS
################################################################################
#
export host_default=black
#
export host_bits_default=2048
#
export host_use_security_key_default=false
#
export host_security_key_type_default=yubikey
#
export host_security_key_id_default="5414483"
#
export host_pkcs11_id_default="06"
#
export host_yubikey_pin_policy_default=never
#
export host_yubikey_touch_policy_default=never
################################################################################
# USER SETTINGS
################################################################################
#
export user_default=aharon
#
export user_name_default=Aharon
#
export user_surname_default=Haravon
#
export user_given_name_default=Aharon
#
export user_initials_default=A.H.
#
export user_bits_default=2048
#
export user_use_security_key_default=false
#
export user_security_key_type_default=yubikey
#
export user_security_key_id_default="5414483"
# 9a is for PIV Authentication (ykcs11 ID: 01)
export user_pkcs11_id_default="01"
#
export user_yubikey_pin_policy_default=never
#
export user_yubikey_touch_policy_default=always
#
export suffix_default=-
#
export caps_suffix_default=""
#
#################################################
# folder settings
#
export demo_folder_default=~/.sca/demo/
#
export key_folder_default=~/.sca/keys/
#
export transfer_folder_default=~/.sca/transfer/
# the folder in which to keep openssl configuration files and template
#export sca_conf_folder_default=/etc/ssl/
export sca_conf_folder_default=~/.sca/config/
################################################
# library files locations
# full path to pkcs11 engine library (libp11 engine_pkcs11.so)
export pkcs11_engine_default=/usr/lib/x86_64-linux-gnu/engines-3/pkcs11.so
# full path to pkcs11 module library
export opensc_pkcs11_module_default=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
#
export ykcs11_module_default=/usr/lib/x86_64-linux-gnu/libykcs11.so
