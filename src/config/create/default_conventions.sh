#################################################
# settings
#################################################
# verbosity level - none, v, vv
export verbosity=${verbosity:-$verbosity_default}
# the currently selected CA authority (short, small caps) name
export name=${name:-$name_default}
# the currently selected CA authority long (small and big caps) name
export caps_name=${caps_name:-$caps_name_default}
# the DNS domain for the currently selected CA authority
export domain=${domain:-$domain_default}
#
export ca_bits=${ca_bits:-$ca_bits_default}
#
export ca_use_security_key=${ca_use_security_key:-$ca_use_security_key_default}
#
export ca_security_key_type=${ca_security_key_type:-$ca_security_key_type_default}
#
export ca_security_key_id=${ca_security_key_id:-$ca_security_key_id_default}
#
export ca_pkcs11_id=${ca_pkcs11_id:-$ca_pkcs11_id_default}
#
export ca_yubikey_pin_policy=${ca_yubikey_pin_policy:-$ca_yubikey_pin_policy_default}
#
export ca_yubikey_touch_policy=${ca_yubikey_touch_policy:-$ca_yubikey_touch_policy_default}
# the name of the currently subca (a person trusted to issue signed certificates)
export subca=${subca:-$subca_default}
#
export subca_name=${subca_name:-$subca_name_default}
#
export subca_surname=${subca_surname:-$subca_surname_default}
#
export subca_given_name=${subca_given_name:-$subca_given_name_default}
#
export subca_initials=${subca_initials:-$subca_initials_default}
#
export subca_bits=${subca_bits:-$subca_bits_default}
#
export subca_use_security_key=${subca_use_security_key:-$subca_use_security_key_default}
#
export subca_security_key_type=${subca_security_key_type:-$subca_security_key_type_default}
#
export subca_security_key_id=${subca_security_key_id:-$subca_security_key_id_default}
#
export subca_pkcs11_id=${subca_pkcs11_id:-$subca_pkcs11_id_default}
#
export subca_yubikey_pin_policy=${subca_yubikey_pin_policy:-$subca_yubikey_pin_policy_default}
#
export subca_yubikey_touch_policy=${subca_yubikey_touch_policy:-$subca_yubikey_touch_policy_default}
# the currently selected service name
export service=${service:-$service_default}
#
export service_bits=${service_bits:-$service_bits_default}
#
export service_use_security_key=${service_use_security_key:-$service_use_security_key_default}
#
export service_use_k8s_secret=${service_use_k8s_secret:-$service_use_k8s_secret_default}
#
export service_security_key_type=${service_security_key_type:-$service_security_key_type_default}
#
export service_security_key_id=${service_security_key_id:-$service_security_key_id_default}
#
export service_pkcs11_id=${service_pkcs11_id:-$service_pkcs11_id_default}
#
export service_yubikey_pin_policy=${service_yubikey_pin_policy:-$service_yubikey_pin_policy_default}
#
export service_yubikey_touch_policy=${service_yubikey_touch_policy:-$service_yubikey_touch_policy_default}
# the currently selected host name
export host=${host:-$host_default}
#
export host_bits=${host_bits:-$host_bits_default}
#
export host_use_security_key=${host_use_security_key:-$host_use_security_key_default}
#
export host_security_key_type=${host_security_key_type:-$host_security_key_type_default}
#
export host_security_key_id=${host_security_key_id:-$host_security_key_id_default}
#
export host_pkcs11_id=${host_pkcs11_id:-$host_pkcs11_id_default}
#
export host_yubikey_pin_policy=${host_yubikey_pin_policy:-$host_yubikey_pin_policy_default}
#
export host_yubikey_touch_policy=${host_yubikey_touch_policy:-$host_yubikey_touch_policy_default}
# the currently selected user name
export user=${user:-$user_default}
#
export user_name=${user_name:-$user_name_default}
#
export user_surname=${user_surname:-$user_surname_default}
#
export user_given_name=${user_given_name:-$user_given_name_default}
#
export user_initials=${user_initials:-$user_initials_default}
#
export user_bits=${user_bits:-$user_bits_default}
#
export user_use_security_key=${user_use_security_key:-$user_use_security_key_default}
#
export user_security_key_type=${user_security_key_type:-$user_security_key_type_default}
#
export user_security_key_id=${user_security_key_id:-$user_security_key_id_default}
#
export user_pkcs11_id=${user_pkcs11_id:-$user_pkcs11_id_default}
#
export user_yubikey_pin_policy=${user_yubikey_pin_policy:-$user_yubikey_pin_policy_default}
#
export user_yubikey_touch_policy=${user_yubikey_touch_policy:-$user_yubikey_touch_policy_default}
# file name suffix to attach to CA related file names
export suffix=${suffix:-$suffix_default}
# the suffix to use in certificates for certificate authority name
export caps_suffix=${caps_suffix:-$caps_suffix_default}
#################################################
# folder settings
#################################################
#
export demo_folder=${demo_folder:-$demo_folder_default}
# the folder that is removable storage mount point for keeping the CA private
# keys and other sensitive information
export key_folder=${key_folder:-$key_folder_default}
# the folder that is removable storage mount point for keeping the offline
# ubuntu software package repository as well as communicating the keys and
# certificates between online and offline environments
export transfer_folder=${transfer_folder:-$transfer_folder_default}
# the folder in which to keep openssl configuration files and template
export sca_conf_folder=${sca_conf_folder:-$sca_conf_folder_default}

export pkcs11_engine=${pkcs11_engine:-$pkcs11_engine_default}
# full path to pkcs11 module library
export opensc_pkcs11_module=${opensc_pkcs11_module:-$opensc_pkcs11_module_default}

export ykcs11_module=${ykcs11_module:-$ykcs11_module_default}

#################################################
# derived settings
# below settings are derived from values of the settings above accordig to
# nameing convention described in README.md
# the full dns domain name for the CA authority
export full_domain=${name}${domain}
# the service full dns name
export service_dns_name=${service}.${fulldomain}
# prefix to use in certificates for generated common names
export common_name_prefix="${caps_name} ${caps_suffix} "
#################################################
# derived folder settings
#################################################
################################################
# ca related folders and files locations
#
export ca_files_relative_folder=${name}/
# the CA data root folder for currently selected authority (name setting)
export ca_files_folder=${key_folder}${name}/
# the prefix to use for the root ca related files (not including full path)
export ca_file_prefix=${name}${suffix}ca-
#
export ca_filename_relative_prefix=${ca_files_relative_folder}${ca_file_prefix}
# the prefix to use for the root ca related files (including full path)
export ca_filename_prefix=${ca_files_folder}${ca_file_prefix}
#
export ca_private_folder=${ca_files_folder}private/
# the prefix to use for the root ca private (secret) related files (including
# full path)
export ca_private_filename_prefix=${ca_private_folder}${ca_file_prefix}
# name of the selected root ca authority key file
export ca_key_file=${ca_private_filename_prefix}key.pem
# name of the selected root ca authority certificate file
export ca_crt_file=${ca_filename_prefix}crt.pem
#
export ca_crt_relative_file=${ca_filename_relative_prefix}crt.pem
#
export ca_crt_filename=$(basename "${ca_crt_file}")
# name of the selected root ca authority public key file
export ca_pub_file=${ca_filename_prefix}pub.pem
#
export ca_pub_filename=$(basename "${ca_pub_file}")
# name of the selected root ca authority public key file in ssh format suitable
# for ssh for example
export ca_pub_ssh_file=${ca_filename_prefix}pub.ssh
#
export ca_pub_ssh_filename=$(basename "${ca_pub_ssh_file}")
#
export ca_transfer_files_folder=${transfer_folder}${ca_files_folder_suffix}
# name of the selected subca certificate signing request file
export ca_csr_file=${ca_filename_prefix}csr.pem
# name of the selected root ca authority certificate signature request signing
# configuration file
export ca_csr_ini_file=${ca_filename_prefix}csr.ini
# name of the selected root ca authority certificate extensions configuration
# file
export ca_crt_ini_file=${ca_filename_prefix}crt.ini
#
export ca_database_file=${ca_filename_prefix}db.txt
#
export ca_new_certs_dir=${ca_files_folder}newcerts
#
export ca_serial_file=${ca_filename_prefix}srl.txt
#
export ca_rand_file=${ca_private_filename_prefix}rnd.txt
#
export ca_crl_serial_file=${ca_filename_prefix}crl-srl.txt
#
export ca_crl_file=${ca_filename_prefix}crl.pem
#
export ca_crl_relative_file=${ca_filename_relative_prefix}crl.pem
#
export ca_yubikey_key_file=${ca_private_filename_prefix}yubikey-key.txt
#
export ca_yubikey_pin_file=${ca_private_filename_prefix}yubikey-pin.txt
#
export ca_yubikey_puk_file=${ca_private_filename_prefix}yubikey-puk.txt
#
#
export ca_crl_uri=http://crl.${full_domain}/${ca_crl_relative_file}
#
export ca_crt_uri=http://crl.${full_domain}/${ca_crt_relative_file}
#
export ca_ocsp_uri=http://ocsp.${full_domain}
################################################
# subca related folders and files locations
#
export subca_files_relative_folder=${ca_files_relative_folder}${subca}/
# folder containing the subca related files
export subca_files_folder=${ca_files_folder}${subca}/
# the prefix to use for the subca related files (not including full path)
export subca_file_prefix=${name}${suffix}${subca}-subca-
#
export subca_filename_relative_prefix=${subca_files_relative_folder}${subca_file_prefix}
# the prefix to use for the subca related files (including full path)
export subca_filename_prefix=${subca_files_folder}${subca_file_prefix}
#
export subca_private_folder=${subca_files_folder}private/
# the prefix to use for the subca private (secret) related files (including
# full path)
export subca_private_filename_prefix=${subca_private_folder}${subca_file_prefix}
# name of the selected subca authority key file
export subca_key_file=${subca_private_filename_prefix}key.pem
# name of the selected subca authority certificate file
export subca_crt_file=${subca_filename_prefix}crt.pem
#
export subca_crt_relative_file=${subca_filename_relative_prefix}crt.pem
#
export subca_crt_filename=$(basename "${subca_crt_file}")
# name of the selected subca authority public key file
export subca_pub_file=${subca_filename_prefix}pub.pem
#
export subca_pub_filename=$(basename "${subca_pub_file}")
# name of the selected subca authority public key file in ssh format suitable
# for ssh for example
export subca_pub_ssh_file=${subca_filename_prefix}pub.ssh
#
export subca_pub_ssh_filename=$(basename "${subca_pub_ssh_file}")
#
export subca_transfer_files_folder=${transfer_folder}${subca_files_folder_suffix}
# name of the selected subca certificate signing request file
export subca_csr_file=${subca_filename_prefix}csr.pem
#
export subca_csr_filename=$(basename "${subca_csr_file}")
# name of the selected subca authority certificate signature request signing
# configuration file
export subca_csr_ini_file=${subca_filename_prefix}csr.ini
# name of the selected subca authority certificate extensions configuration
# file
export subca_crt_ini_file=${subca_filename_prefix}crt.ini
#
export subca_database_file=${subca_filename_prefix}db.txt
#
export subca_new_certs_dir=${subca_files_folder}newcerts
#
export subca_serial_file=${subca_filename_prefix}srl.txt
#
export subca_rand_file=${subca_private_filename_prefix}rnd.txt
#
export subca_crl_serial_file=${subca_filename_prefix}crl-srl.txt
#
export subca_crl_file=${subca_filename_prefix}crl.pem
#
export subca_crl_relative_file=${subca_filename_relative_prefix}crl.pem
#
export subca_yubikey_key_file=${subca_private_filename_prefix}yubikey-key.txt
#
export subca_yubikey_pin_file=${subca_private_filename_prefix}yubikey-pin.txt
#
export subca_yubikey_puk_file=${subca_private_filename_prefix}yubikey-puk.txt
export subca_crl_uri=http://crl.${full_domain}/${subca_crl_relative_file}
export subca_crt_uri=http://crl.${full_domain}/${subca_crt_relative_file}
#
export subca_ocsp_uri=http://ocsp.${full_domain}/${subca}
################################################
# service related folders and files locations
#
export services_root_relative_folder=${subca_files_relative_folder}services/
# folder containing the services related files
export services_root_folder=${subca_files_folder}services/
#
export service_files_relative_folder=${services_root_relative_folder}${service}/
# the prefix to use for the services related files (including full path)
export service_files_folder=${services_root_folder}${service}/
# the prefix to use for the service related files (including full path)
export service_file_prefix=${name}${suffix}${subca}-${service}-
#
export serice_filename_relative_prefix=${service_files_relative_folder}${service_file_prefix}
# the prefix to use for the service related files (including full path)
export service_filename_prefix=${service_files_folder}${service_file_prefix}
#
export service_private_folder=${service_files_folder}private/
# the prefix to use for the service private (secret) related files (including
# full path)
export service_private_filename_prefix=${service_private_folder}${service_file_prefix}
# name of the selected service key file
export service_key_file=${service_private_filename_prefix}key.pem
# name of the selected service certificate file
export service_crt_file=${service_filename_prefix}crt.pem
#
export service_crt_relative_file=${serice_filename_relative_prefix}crt.pem
#
export service_crt_filename=$(basename "${service_crt_file}")
# name of the selected user public key file
export service_pub_file=${service_filename_prefix}pub.pem
#
export service_pub_filename=$(basename "${service_pub_file}")
# name of the selected user public key file
export service_pub_ssh_file=${service_filename_prefix}pub.ssh
#
export service_pub_ssh_filename=$(basename "${service_pub_ssh_file}")
# name of the selected service certificate signing request file
export service_csr_file=${service_filename_prefix}csr.pem
#
export service_csr_filename=$(basename "${service_csr_file}")
#
export service_transfer_files_folder=${transfer_folder}${service_files_folder_suffix}
# name of the selected service certificate signature request signing
# configuration file
export service_csr_ini_file=${service_filename_prefix}csr.ini
# name of the selected service certificate extensions configuration
# file
export service_crt_ini_file=${service_filename_prefix}crt.ini
#
export service_yubikey_key_file=${service_private_filename_prefix}yubikey-key.txt
#
export service_yubikey_pin_file=${service_private_filename_prefix}yubikey-pin.txt
#
export service_yubikey_puk_file=${service_private_filename_prefix}yubikey-puk.txt
################################################
# host related folders and files locations
#
export hosts_root_relative_folder=${subca_files_relative_folder}hosts/
#
export hosts_root_folder=${subca_files_folder}hosts/
#
export host_files_relative_folder=${hosts_root_relative_folder}${host}/
#
export host_files_folder=${hosts_root_folder}${host}/
#
export host_file_prefix=${name}${suffix}${subca}-${host}-
#
export host_filename_relative_prefix=${host_files_relative_folder}${host_file_prefix}
#
export host_filename_prefix=${host_files_folder}${host_file_prefix}
#
export host_private_folder=${host_files_folder}private/
#
export host_private_filename_prefix=${host_private_folder}${host_file_prefix}
#
export host_key_file=${host_private_filename_prefix}key.pem
#
export host_crt_file=${host_filename_prefix}crt.pem
#
export host_crt_relative_file=${host_filename_relative_prefix}crt.pem
#
export host_crt_filename=$(basename "${host_crt_file}")
# name of the selected user public key file
export host_pub_file=${host_filename_prefix}pub.pem
#
export host_pub_filename=$(basename "${host_pub_file}")
# name of the selected user public key file
export host_pub_ssh_file=${host_filename_prefix}pub.ssh
#
export host_pub_ssh_filename=$(basename "${host_pub_ssh_file}")
#
export host_csr_file=${host_filename_prefix}csr.pem
#
export host_csr_filename=$(basename "${host_csr_file}")
#
export host_transfer_files_folder=${transfer_folder}${host_files_folder_suffix}
#
export host_csr_ini_file=${host_filename_prefix}csr.ini
#
export host_crt_ini_file=${host_filename_prefix}crt.ini
#
export host_yubikey_key_file=${host_private_filename_prefix}yubikey-key.txt
#
export host_yubikey_pin_file=${host_private_filename_prefix}yubikey-pin.txt
#
export host_yubikey_puk_file=${host_private_filename_prefix}yubikey-puk.txt
################################################
# user related folders and files locations
#
export users_root_relative_folder=${subca_files_relative_folder}users/
#
export users_root_folder=${subca_files_folder}users/
#
export user_files_relative_folder=${users_root_relative_folder}${user}/
#
export user_files_folder=${users_root_folder}${user}/
#
export user_file_prefix=${name}${suffix}${subca}-${user}-
#
export user_filename_relative_prefix=${users_files_relative_folder}${user_file_prefix}
#
export user_filename_prefix=${user_files_folder}${user_file_prefix}
#
export user_private_folder=${user_files_folder}private/
#
export user_private_filename_prefix=${user_private_folder}${user_file_prefix}
#
export user_key_file=${user_private_filename_prefix}key.pem
#
export user_crt_file=${user_filename_prefix}crt.pem
#
export user_crt_relative_file=${user_filename_relative_prefix}crt.pem
#
export user_crt_filename=$(basename "${user_crt_file}")
# name of the selected user public key file
export user_pub_file=${user_filename_prefix}pub.pem
#
export user_pub_filename=$(basename "${user_pub_file}")
# name of the selected user public key file in ssh format suitable
# for ssh for example
export user_pub_ssh_file=${user_filename_prefix}pub.ssh
#
export user_transfer_files_folder=${transfer_folder}${user_files_folder_suffix}
#
export user_pub_ssh_filename=$(basename "${user_pub_ssh_file}")
#
export user_csr_file=${user_filename_prefix}csr.pem
#
export user_csr_filename=$(basename "${user_csr_file}")
#
export user_csr_ini_file=${user_filename_prefix}csr.ini
#
export user_crt_ini_file=${user_filename_prefix}crt.ini
#
export user_yubikey_key_file=${user_private_filename_prefix}yubikey-key.txt
#
export user_yubikey_pin_file=${user_private_filename_prefix}yubikey-pin.txt
#
export user_yubikey_puk_file=${user_private_filename_prefix}yubikey-puk.txt
