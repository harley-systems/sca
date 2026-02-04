# SCA Makefile - Simplified with macros
# Uses scripts/build-help.sh to generate help text

.PHONY: all clean deploy

all: sca

#------------------------------------------------------------------------------
# Helper macro: Build help for a command
# $(1) = parent (e.g., create)
# $(2) = subcommand (e.g., key) or empty for parent command
#------------------------------------------------------------------------------
define build_help
$(if $(2),build/$(1)/$(2)/help/help.txt,build/$(1)/help/help.txt): build/common/help/help.txt
	@mkdir -p $$(dir $$@)
	./scripts/build-help.sh $$@ src/$(1)$(if $(2),/$(2))/help $(if $(2),$(1),)
endef

#------------------------------------------------------------------------------
# Helper macro: Build a subcommand script
# $(1) = parent (e.g., create)
# $(2) = subcommand (e.g., key)
#------------------------------------------------------------------------------
define build_subcmd
build/$(1)/$(2)/$(1)_$(2).sh: src/$(1)/$(2)/$(1)_$(2).sh build/$(1)/$(2)/help/help.txt
	@mkdir -p $$(dir $$@)
	sed -e '/@@@HELP@@@/{r build/$(1)/$(2)/help/help.txt' -e 'd}' $$< > $$@
endef

#------------------------------------------------------------------------------
# Common help template
#------------------------------------------------------------------------------
build/common/help/help.txt: src/common/help/help.txt src/common/help/title.txt
	@mkdir -p build/common/help
	sed -e '/@@@TITLE@@@/{r src/common/help/title.txt' -e 'd}' $< > $@

#------------------------------------------------------------------------------
# Top-level sca help
#------------------------------------------------------------------------------
build/help/help.txt: build/common/help/help.txt src/help/command_title.txt \
		src/help/abstract.txt src/help/syntax.txt src/help/options.txt src/help/further_read.txt
	@mkdir -p build/help
	./scripts/build-help.sh $@ src/help

#------------------------------------------------------------------------------
# CREATE command and subcommands
#------------------------------------------------------------------------------
CREATE_SUBCMDS := key csr crt crl pub pub_ssh crt_pub_ssh

$(eval $(call build_help,create,))
$(foreach s,$(CREATE_SUBCMDS),$(eval $(call build_help,create,$(s))))
$(foreach s,$(CREATE_SUBCMDS),$(eval $(call build_subcmd,create,$(s))))

build/create/create.sh: src/create/create.sh build/create/help/help.txt \
		$(foreach s,$(CREATE_SUBCMDS),build/create/$(s)/create_$(s).sh)
	@mkdir -p build/create
	sed -e '/@@@HELP@@@/{r build/create/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(CREATE_SUBCMDS),build/create/$(s)/create_$(s).sh) >> $@

create: build/create/create.sh

#------------------------------------------------------------------------------
# DISPLAY command and subcommands
#------------------------------------------------------------------------------
DISPLAY_SUBCMDS := crt csr p12

$(eval $(call build_help,display,))
$(foreach s,$(DISPLAY_SUBCMDS),$(eval $(call build_help,display,$(s))))
$(foreach s,$(DISPLAY_SUBCMDS),$(eval $(call build_subcmd,display,$(s))))

build/display/display.sh: src/display/display.sh build/display/help/help.txt \
		$(foreach s,$(DISPLAY_SUBCMDS),build/display/$(s)/display_$(s).sh)
	@mkdir -p build/display
	sed -e '/@@@HELP@@@/{r build/display/help/help.txt' -e 'd}' \
		-e '/@@@GENERIC HELP@@@/{r build/display/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(DISPLAY_SUBCMDS),build/display/$(s)/display_$(s).sh) >> $@

display: build/display/display.sh

#------------------------------------------------------------------------------
# EXPORT command and subcommands
#------------------------------------------------------------------------------
EXPORT_SUBCMDS := crt_pub_ssh csr p12

$(eval $(call build_help,export,))
$(foreach s,$(EXPORT_SUBCMDS),$(eval $(call build_help,export,$(s))))
$(foreach s,$(EXPORT_SUBCMDS),$(eval $(call build_subcmd,export,$(s))))

build/export/export.sh: src/export/export.sh build/export/help/help.txt \
		$(foreach s,$(EXPORT_SUBCMDS),build/export/$(s)/export_$(s).sh)
	@mkdir -p build/export
	sed -e '/@@@HELP@@@/{r build/export/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(EXPORT_SUBCMDS),build/export/$(s)/export_$(s).sh) >> $@

export: build/export/export.sh

#------------------------------------------------------------------------------
# IMPORT command
#------------------------------------------------------------------------------
$(eval $(call build_help,import,))

build/import/import.sh: src/import/import.sh build/import/help/help.txt
	@mkdir -p build/import
	sed -e '/@@@HELP@@@/{r build/import/help/help.txt' -e 'd}' $< > $@

import: build/import/import.sh

#------------------------------------------------------------------------------
# INIT command and subcommands
#------------------------------------------------------------------------------
INIT_SUBCMDS := demo openssl_ca_db sca_usb_stick yubikey

$(eval $(call build_help,init,))
$(foreach s,$(INIT_SUBCMDS),$(eval $(call build_help,init,$(s))))
$(foreach s,$(INIT_SUBCMDS),$(eval $(call build_subcmd,init,$(s))))

build/init/init.sh: src/init/init.sh build/init/help/help.txt \
		$(foreach s,$(INIT_SUBCMDS),build/init/$(s)/init_$(s).sh)
	@mkdir -p build/init
	sed -e '/@@@HELP@@@/{r build/init/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(INIT_SUBCMDS),build/init/$(s)/init_$(s).sh) >> $@

init: build/init/init.sh

#------------------------------------------------------------------------------
# REQUEST command (no subcommands)
#------------------------------------------------------------------------------
$(eval $(call build_help,request,))

build/request/request.sh: src/request/request.sh build/request/help/help.txt
	@mkdir -p build/request
	sed -e '/@@@HELP@@@/{r build/request/help/help.txt' -e 'd}' $< > $@

request: build/request/request.sh

#------------------------------------------------------------------------------
# SECURITY_KEY command and subcommands
#------------------------------------------------------------------------------
SECURITY_KEY_SUBCMDS := get_crt id info init upload verify wait_for

$(eval $(call build_help,security_key,))
$(foreach s,$(SECURITY_KEY_SUBCMDS),$(eval $(call build_help,security_key,$(s))))
$(foreach s,$(SECURITY_KEY_SUBCMDS),$(eval $(call build_subcmd,security_key,$(s))))

build/security_key/security_key.sh: src/security_key/security_key.sh build/security_key/help/help.txt \
		$(foreach s,$(SECURITY_KEY_SUBCMDS),build/security_key/$(s)/security_key_$(s).sh)
	@mkdir -p build/security_key
	sed -e '/@@@HELP@@@/{r build/security_key/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(SECURITY_KEY_SUBCMDS),build/security_key/$(s)/security_key_$(s).sh) >> $@

security_key: build/security_key/security_key.sh

#------------------------------------------------------------------------------
# APPROVE command (no subcommands)
#------------------------------------------------------------------------------
$(eval $(call build_help,approve,))

build/approve/approve.sh: src/approve/approve.sh build/approve/help/help.txt
	@mkdir -p build/approve
	sed -e '/@@@HELP@@@/{r build/approve/help/help.txt' -e 'd}' $< > $@

approve: build/approve/approve.sh

#------------------------------------------------------------------------------
# REVOKE command (no subcommands)
#------------------------------------------------------------------------------
$(eval $(call build_help,revoke,))

build/revoke/revoke.sh: src/revoke/revoke.sh build/revoke/help/help.txt
	@mkdir -p build/revoke
	sed -e '/@@@HELP@@@/{r build/revoke/help/help.txt' -e 'd}' $< > $@

revoke: build/revoke/revoke.sh

#------------------------------------------------------------------------------
# CONFIG command and subcommands
#------------------------------------------------------------------------------
# config_create has extra placeholders, so it gets a custom build rule below
CONFIG_SUBCMDS := get load reset resolve save set
CONFIG_ALL_SUBCMDS := create $(CONFIG_SUBCMDS)

$(eval $(call build_help,config,))
$(foreach s,$(CONFIG_ALL_SUBCMDS),$(eval $(call build_help,config,$(s))))
$(foreach s,$(CONFIG_SUBCMDS),$(eval $(call build_subcmd,config,$(s))))

# Custom build rule for config_create: substitutes @@@HELP@@@ plus the 4 embedded
# config/ini placeholders that get written to ~/.sca/config/ at runtime.
CONFIG_CREATE_SRC := src/config/create
build/config/create/config_create.sh: src/config/create/config_create.sh \
		build/config/create/help/help.txt \
		$(CONFIG_CREATE_SRC)/default_sca_config.sh \
		$(CONFIG_CREATE_SRC)/default_conventions.sh \
		$(CONFIG_CREATE_SRC)/default_openssl_config.ini \
		$(CONFIG_CREATE_SRC)/pkcs11_openssl_config.ini
	@mkdir -p $(dir $@)
	sed -e '/@@@HELP@@@/{r build/config/create/help/help.txt' -e 'd}' $< | \
		sed -e '/@@@DEFAULT SCA CONFIG@@@/{r $(CONFIG_CREATE_SRC)/default_sca_config.sh' -e 'd}' | \
		sed -e '/@@@DEFAULT CONVENTIONS@@@/{r $(CONFIG_CREATE_SRC)/default_conventions.sh' -e 'd}' | \
		sed -e '/@@@DEFAULT OPENSSL CONFIG@@@/{r $(CONFIG_CREATE_SRC)/default_openssl_config.ini' -e 'd}' | \
		sed -e '/@@@PKCS11 OPENSSL CONFIG@@@/{r $(CONFIG_CREATE_SRC)/pkcs11_openssl_config.ini' -e 'd}' \
		> $@

build/config/config.sh: src/config/config.sh build/config/help/help.txt \
		$(foreach s,$(CONFIG_ALL_SUBCMDS),build/config/$(s)/config_$(s).sh)
	@mkdir -p build/config
	sed -e '/@@@HELP@@@/{r build/config/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(CONFIG_ALL_SUBCMDS),build/config/$(s)/config_$(s).sh) >> $@

config: build/config/config.sh

#------------------------------------------------------------------------------
# LIST command and subcommands
#------------------------------------------------------------------------------
LIST_SUBCMDS := cas configs hosts services subcas users

$(eval $(call build_help,list,))
$(foreach s,$(LIST_SUBCMDS),$(eval $(call build_help,list,$(s))))
$(foreach s,$(LIST_SUBCMDS),$(eval $(call build_subcmd,list,$(s))))

build/list/list.sh: src/list/list.sh build/list/help/help.txt \
		$(foreach s,$(LIST_SUBCMDS),build/list/$(s)/list_$(s).sh)
	@mkdir -p build/list
	sed -e '/@@@HELP@@@/{r build/list/help/help.txt' -e 'd}' $< > $@
	cat $(foreach s,$(LIST_SUBCMDS),build/list/$(s)/list_$(s).sh) >> $@

list: build/list/list.sh

#------------------------------------------------------------------------------
# TEST command
#------------------------------------------------------------------------------
$(eval $(call build_help,test,))

build/test/test.sh: src/test/test.sh build/test/help/help.txt
	@mkdir -p build/test
	sed -e '/@@@HELP@@@/{r build/test/help/help.txt' -e 'd}' $< > $@

test: build/test/test.sh

#------------------------------------------------------------------------------
# INSTALL command
#------------------------------------------------------------------------------
$(eval $(call build_help,install,))

build/install/install.sh: src/install/install.sh build/install/help/help.txt
	@mkdir -p build/install
	sed -e '/@@@HELP@@@/{r build/install/help/help.txt' -e 'd}' $< > $@

install: build/install/install.sh

#------------------------------------------------------------------------------
# COMPLETION command
#------------------------------------------------------------------------------
COMPLETION_SCRIPTS := src/approve/complete_bash.sh src/revoke/complete_bash.sh \
	src/completion/complete_bash.sh \
	src/config/complete_bash.sh src/create/complete_bash.sh src/display/complete_bash.sh \
	src/export/complete_bash.sh src/import/complete_bash.sh src/init/complete_bash.sh \
	src/list/complete_bash.sh src/request/complete_bash.sh src/test/complete_bash.sh \
	src/install/complete_bash.sh src/security_key/complete_bash.sh src/complete_bash.sh

$(eval $(call build_help,completion,))

build/completion/completion_scripts.sh: $(COMPLETION_SCRIPTS)
	@mkdir -p build/completion
	echo "#!/bin/bash" > $@
	cat $^ | sed -e "s/'/'\"\\'\"'/g" >> $@

build/completion/completion.sh: src/completion/completion.sh build/completion/help/help.txt \
		build/completion/completion_scripts.sh
	@mkdir -p build/completion
	sed -e '/@@@HELP@@@/{r build/completion/help/help.txt' -e 'd}' $< | \
		sed -e '/@@@BASH COMPLETION@@@/{r build/completion/completion_scripts.sh' -e 'd}' > $@

completion: build/completion/completion.sh

#------------------------------------------------------------------------------
# COMMON utilities
#------------------------------------------------------------------------------
build/common/common.sh: src/common/sed.sh
	@mkdir -p build/common
	cat $< > $@

common: build/common/common.sh

#------------------------------------------------------------------------------
# Main SCA script
#------------------------------------------------------------------------------
COMMANDS := create display export import init request security_key approve revoke config list test install completion common

sca: src/sca.sh src/run.sh build/help/help.txt $(COMMANDS)
	sed -e '/@@@HELP@@@/{r build/help/help.txt' -e 'd}' src/sca.sh > build/sca.sh
	cat build/create/create.sh build/display/display.sh build/export/export.sh \
		build/import/import.sh build/init/init.sh build/request/request.sh \
		build/security_key/security_key.sh build/approve/approve.sh build/revoke/revoke.sh \
		build/config/config.sh \
		build/list/list.sh build/test/test.sh build/install/install.sh \
		build/completion/completion.sh build/common/common.sh src/run.sh >> build/sca.sh
	chmod 755 build/sca.sh

#------------------------------------------------------------------------------
# Utility targets
#------------------------------------------------------------------------------
clean:
	rm -rf build/*

INSTALL_DIR ?= $(HOME)/bin
COMPLETION_DIR ?= $(HOME)/.local/share/bash-completion/completions

deploy: sca
	@mkdir -p $(INSTALL_DIR)
	cp build/sca.sh $(INSTALL_DIR)/sca
	chmod 755 $(INSTALL_DIR)/sca
	@echo "Deployed sca to $(INSTALL_DIR)/sca"
	@mkdir -p $(COMPLETION_DIR)
	$(INSTALL_DIR)/sca completion bash > $(COMPLETION_DIR)/sca
	@echo "Deployed completion to $(COMPLETION_DIR)/sca"
	@echo "To reload completion in current shell: . $(COMPLETION_DIR)/sca"
