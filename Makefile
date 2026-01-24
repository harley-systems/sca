
all: sca

common_help: src/common/help/help.txt src/common/help/title.txt
	mkdir -p build/common/help
	sed -e '/@@@TITLE@@@/{r src/common/help/title.txt' -e 'd}' \
			src/common/help/help.txt > build/common/help/help.txt

sca_help: common_help src/help/command_title.txt src/help/abstract.txt \
						src/help/syntax.txt src/help/options.txt \
						src/help/further_read.txt
	mkdir -p build/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/help/further_read.txt' -e 'd}' > \
			build/help/help.txt

sca: src/sca.sh src/run.sh sca_help create display export import init request \
			security_key approve config list test install completion common
	sed -e '/@@@HELP@@@/{r build/help/help.txt' -e 'd}' \
	  	src/sca.sh > build/sca.sh
	cat build/create/create.sh   build/display/display.sh build/export/export.sh \
		  build/import/import.sh   build/init/init.sh       build/request/request.sh \
			build/security_key/security_key.sh \
			build/approve/approve.sh build/config/config.sh   build/list/list.sh \
			build/test/test.sh 			 build/install/install.sh \
			build/completion/completion.sh build/common/common.sh src/run.sh >> build/sca.sh
	chmod 755 build/sca.sh

common: src/common/sed.sh
	mkdir -p build/common
	cat src/common/sed.sh > build/common/common.sh

create_key_help: common_help src/help/options.txt src/create/help/options.txt \
									src/create/key/help/command_title.txt \
									src/create/key/help/abstract.txt src/create/key/help/syntax.txt \
									src/create/key/help/options.txt src/create/key/help/further_read.txt
	mkdir -p build/create/key/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/key/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/create/key/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/create/key/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CREATE OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/create/key/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/key/help/help.txt

create_key: src/create/key/create_key.sh create_key_help
	mkdir -p build/create/key
	sed -e '/@@@HELP@@@/{r build/create/key/help/help.txt' -e 'd}' \
	  src/create/key/create_key.sh > build/create/key/create_key.sh

create_csr_help: common_help src/help/options.txt src/create/help/options.txt \
									src/create/csr/help/command_title.txt \
									src/create/csr/help/abstract.txt src/create/csr/help/syntax.txt \
									src/create/csr/help/options.txt src/create/csr/help/further_read.txt
	mkdir -p build/create/csr/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/csr/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/create/csr/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/create/csr/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@CREATE OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/create/csr/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/csr/help/help.txt

create_csr: src/create/csr/create_csr.sh create_csr_help
	mkdir -p build/create/csr
	sed -e '/@@@HELP@@@/{r build/create/csr/help/help.txt' -e 'd}' \
		src/create/csr/create_csr.sh > build/create/csr/create_csr.sh

create_crt_help: common_help src/help/options.txt src/create/help/options.txt \
									src/create/crt/help/command_title.txt src/create/crt/help/abstract.txt \
									src/create/crt/help/syntax.txt src/create/crt/help/options.txt \
									src/create/crt/help/further_read.txt
	mkdir -p build/create/crt/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/crt/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/create/crt/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/create/crt/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@CREATE OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/create/crt/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/crt/help/help.txt

create_crt: src/create/crt/create_crt.sh create_crt_help
	mkdir -p build/create/crt
	sed -e '/@@@HELP@@@/{r build/create/crt/help/help.txt' -e 'd}' \
			src/create/crt/create_crt.sh > build/create/crt/create_crt.sh

create_pub_help: common_help src/help/options.txt src/create/help/options.txt \
									src/create/pub/help/command_title.txt src/create/pub/help/abstract.txt \
									src/create/pub/help/syntax.txt src/create/pub/help/options.txt \
									src/create/pub/help/further_read.txt
	mkdir -p build/create/pub/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/pub/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/create/pub/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/create/pub/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@CREATE OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/create/pub/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/pub/help/help.txt

create_pub: src/create/pub/create_pub.sh create_pub_help
	mkdir -p build/create/pub
	sed -e '/@@@HELP@@@/{r build/create/pub/help/help.txt' -e 'd}' \
			src/create/pub/create_pub.sh > build/create/pub/create_pub.sh

create_pub_ssh_help: common_help src/help/options.txt src/create/help/options.txt \
											src/create/pub_ssh/help/command_title.txt src/create/pub_ssh/help/abstract.txt \
											src/create/pub_ssh/help/syntax.txt src/create/pub_ssh/help/options.txt \
											src/create/pub_ssh/help/further_read.txt
	mkdir -p build/create/pub_ssh/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/pub_ssh/help/command_title.txt' -e 'd}' \
	 		build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/create/pub_ssh/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/create/pub_ssh/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@CREATE OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/create/pub_ssh/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/pub_ssh/help/help.txt

create_pub_ssh: src/create/pub_ssh/create_pub_ssh.sh create_pub_ssh_help
	mkdir -p build/create/pub_ssh
	sed -e '/@@@HELP@@@/{r build/create/pub_ssh/help/help.txt' -e 'd}' \
			src/create/pub_ssh/create_pub_ssh.sh > build/create/pub_ssh/create_pub_ssh.sh

create_crt_pub_ssh_help: common_help src/help/options.txt src/create/help/options.txt \
													src/create/crt_pub_ssh/help/command_title.txt src/create/crt_pub_ssh/help/abstract.txt \
													src/create/crt_pub_ssh/help/syntax.txt src/create/crt_pub_ssh/help/options.txt \
													src/create/crt_pub_ssh/help/further_read.txt
	mkdir -p build/create/crt_pub_ssh/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/crt_pub_ssh/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/create/crt_pub_ssh/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/create/crt_pub_ssh/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@CREATE OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/create/crt_pub_ssh/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/crt_pub_ssh/help/help.txt

create_crt_pub_ssh: src/create/crt_pub_ssh/create_crt_pub_ssh.sh create_crt_pub_ssh_help
	mkdir -p build/create/crt_pub_ssh
	sed -e '/@@@HELP@@@/{r build/create/crt_pub_ssh/help/help.txt' -e 'd}' \
			src/create/crt_pub_ssh/create_crt_pub_ssh.sh > build/create/crt_pub_ssh/create_crt_pub_ssh.sh


create_help: common_help src/help/options.txt \
							src/create/help/command_title.txt src/create/help/abstract.txt \
							src/create/help/syntax.txt src/create/help/options.txt \
							src/create/help/further_read.txt
	mkdir -p build/create/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/create/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/create/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/create/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/create/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/create/help/further_read.txt' -e 'd}' > \
			build/create/help/help.txt

create: src/create/create.sh create_help create_key create_csr create_crt \
					create_pub create_pub_ssh create_crt_pub_ssh
	mkdir -p build/create
	sed -e '/@@@HELP@@@/{r build/create/help/help.txt' -e 'd}' \
			src/create/create.sh > build/create/create.sh
	cat build/create/key/create_key.sh 					build/create/csr/create_csr.sh \
			build/create/crt/create_crt.sh 					build/create/pub/create_pub.sh \
			build/create/pub_ssh/create_pub_ssh.sh 	build/create/crt_pub_ssh/create_crt_pub_ssh.sh \
			>> build/create/create.sh

display_crt_help: common_help src/help/options.txt src/display/help/options.txt \
									src/display/crt/help/command_title.txt \
									src/display/crt/help/abstract.txt src/display/crt/help/syntax.txt \
									src/display/crt/help/options.txt src/display/crt/help/further_read.txt
	mkdir -p build/display/crt/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/display/crt/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/display/crt/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/display/crt/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CREATE OPTIONS@@@/{r src/display/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/display/crt/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/display/help/further_read.txt' -e 'd}' > \
			build/display/crt/help/help.txt

display_crt: src/display/crt/display_crt.sh display_crt_help
	mkdir -p build/display/crt
	sed -e '/@@@HELP@@@/{r build/display/crt/help/help.txt' -e 'd}' \
	  src/display/crt/display_crt.sh > build/display/crt/display_crt.sh


display_csr_help: common_help src/help/options.txt src/display/help/options.txt \
									src/display/csr/help/command_title.txt \
									src/display/csr/help/abstract.txt src/display/csr/help/syntax.txt \
									src/display/csr/help/options.txt src/display/csr/help/further_read.txt
	mkdir -p build/display/csr/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/display/csr/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/display/csr/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/display/csr/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@DISPLAY OPTIONS@@@/{r src/display/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/display/csr/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/display/help/further_read.txt' -e 'd}' > \
			build/display/csr/help/help.txt

display_csr: src/display/csr/display_csr.sh display_csr_help
	mkdir -p build/display/csr
	sed -e '/@@@HELP@@@/{r build/display/csr/help/help.txt' -e 'd}' \
	  src/display/csr/display_csr.sh > build/display/csr/display_csr.sh

display_help: common_help src/help/options.txt \
								src/display/help/command_title.txt src/display/help/abstract.txt \
								src/display/help/syntax.txt src/display/help/options.txt \
								src/display/help/further_read.txt
	mkdir -p build/display/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/display/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/display/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/display/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/display/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/display/help/further_read.txt' -e 'd}' > \
			build/display/help/help.txt

display_generic_help: common_help src/help/options.txt src/display/help/options.txt \
												src/display/generic_help/command_title.txt src/display/generic_help/abstract.txt \
												src/display/generic_help/syntax.txt \
												src/display/generic_help/further_read.txt
	mkdir -p build/display/generic_help
	sed -e '/@@@COMMAND TITLE@@@/{r src/display/generic_help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/display/generic_help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/display/generic_help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@DISPLAY OPTIONS@@@/{r src/display/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/display/generic_help/further_read.txt' -e 'd}' > \
			build/display/generic_help/generic_help.txt

display: src/display/display.sh display_help display_generic_help display_crt \
					display_csr
	mkdir -p build/display
	sed -e '/@@@HELP@@@/{r build/display/help/help.txt' -e 'd}' \
			src/display/display.sh | \
			sed -e '/@@@GENERIC HELP@@@/{r build/display/generic_help/generic_help.txt' -e 'd}' > \
			build/display/display.sh
	cat build/display/crt/display_crt.sh build/display/csr/display_csr.sh \
			>> build/display/display.sh


export_crt_pub_ssh_help: common_help src/help/options.txt src/export/help/options.txt \
									src/export/crt_pub_ssh/help/command_title.txt \
									src/export/crt_pub_ssh/help/abstract.txt src/export/crt_pub_ssh/help/syntax.txt \
									src/export/crt_pub_ssh/help/options.txt src/export/crt_pub_ssh/help/further_read.txt
	mkdir -p build/export/crt_pub_ssh/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/export/crt_pub_ssh/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/export/crt_pub_ssh/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/export/crt_pub_ssh/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@EXPORT OPTIONS@@@/{r src/export/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/export/crt_pub_ssh/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/export/help/further_read.txt' -e 'd}' > \
			build/export/crt_pub_ssh/help/help.txt

export_crt_pub_ssh: src/export/crt_pub_ssh/export_crt_pub_ssh.sh export_crt_pub_ssh_help
	mkdir -p build/export/crt_pub_ssh
	sed -e '/@@@HELP@@@/{r build/export/crt_pub_ssh/help/help.txt' -e 'd}' \
	  src/export/crt_pub_ssh/export_crt_pub_ssh.sh > build/export/crt_pub_ssh/export_crt_pub_ssh.sh

export_csr_help: common_help src/help/options.txt src/export/help/options.txt \
									src/export/csr/help/command_title.txt \
									src/export/csr/help/abstract.txt src/export/csr/help/syntax.txt \
									src/export/csr/help/options.txt src/export/csr/help/further_read.txt
	mkdir -p build/export/csr/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/export/csr/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/export/csr/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/export/csr/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@EXPORT OPTIONS@@@/{r src/export/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/export/csr/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/export/help/further_read.txt' -e 'd}' > \
			build/export/csr/help/help.txt

export_csr: src/export/csr/export_csr.sh export_csr_help
	mkdir -p build/export/csr
	sed -e '/@@@HELP@@@/{r build/export/csr/help/help.txt' -e 'd}' \
	  src/export/csr/export_csr.sh > build/export/csr/export_csr.sh

export_help: common_help src/help/options.txt \
							src/export/help/command_title.txt src/export/help/abstract.txt \
							src/export/help/syntax.txt src/export/help/options.txt \
							src/export/help/further_read.txt
	mkdir -p build/export/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/export/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/export/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/export/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/export/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/export/help/further_read.txt' -e 'd}' > \
			build/export/help/help.txt

export: src/export/export.sh export_help export_csr export_crt_pub_ssh
	mkdir -p build/export
	sed -e '/@@@HELP@@@/{r build/export/help/help.txt' -e 'd}' \
			src/export/export.sh > build/export/export.sh
	cat build/export/csr/export_csr.sh build/export/crt_pub_ssh/export_crt_pub_ssh.sh \
			>> build/export/export.sh

import_help: common_help src/help/options.txt \
							src/import/help/command_title.txt src/import/help/abstract.txt \
							src/import/help/syntax.txt src/import/help/options.txt \
							src/import/help/further_read.txt
	mkdir -p build/import/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/import/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/import/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/import/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/import/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/import/help/further_read.txt' -e 'd}' > \
			build/import/help/help.txt

import: src/import/import.sh import_help
	mkdir -p build/import
	sed -e '/@@@HELP@@@/{r build/import/help/help.txt' -e 'd}' \
			src/import/import.sh > build/import/import.sh

init_demo_help: common_help src/help/options.txt src/init/help/options.txt \
									src/init/demo/help/command_title.txt \
									src/init/demo/help/abstract.txt src/init/demo/help/syntax.txt \
									src/init/demo/help/options.txt src/init/demo/help/further_read.txt
	mkdir -p build/init/demo/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/init/demo/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/init/demo/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/init/demo/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@INIT OPTIONS@@@/{r src/init/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/init/demo/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/init/help/further_read.txt' -e 'd}' > \
			build/init/demo/help/help.txt

init_demo: src/init/demo/init_demo.sh init_demo_help
	mkdir -p build/init/demo
	sed -e '/@@@HELP@@@/{r build/init/demo/help/help.txt' -e 'd}' \
			src/init/demo/init_demo.sh > build/init/demo/init_demo.sh

init_sca_usb_stick_help: common_help src/help/options.txt src/init/help/options.txt \
									src/init/sca_usb_stick/help/command_title.txt \
									src/init/sca_usb_stick/help/abstract.txt src/init/sca_usb_stick/help/syntax.txt \
									src/init/sca_usb_stick/help/options.txt src/init/sca_usb_stick/help/further_read.txt
	mkdir -p build/init/sca_usb_stick/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/init/sca_usb_stick/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/init/sca_usb_stick/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/init/sca_usb_stick/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@INIT OPTIONS@@@/{r src/init/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/init/sca_usb_stick/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/init/help/further_read.txt' -e 'd}' > \
			build/init/sca_usb_stick/help/help.txt

init_sca_usb_stick: src/init/sca_usb_stick/init_sca_usb_stick.sh init_sca_usb_stick_help
	mkdir -p build/init/sca_usb_stick
	sed -e '/@@@HELP@@@/{r build/init/sca_usb_stick/help/help.txt' -e 'd}' \
			src/init/sca_usb_stick/init_sca_usb_stick.sh > build/init/sca_usb_stick/init_sca_usb_stick.sh

init_openssl_ca_db_help: common_help src/help/options.txt src/init/help/options.txt \
									src/init/openssl_ca_db/help/command_title.txt \
									src/init/openssl_ca_db/help/abstract.txt src/init/openssl_ca_db/help/syntax.txt \
									src/init/openssl_ca_db/help/options.txt src/init/openssl_ca_db/help/further_read.txt
	mkdir -p build/init/openssl_ca_db/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/init/openssl_ca_db/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/init/openssl_ca_db/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/init/openssl_ca_db/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@INIT OPTIONS@@@/{r src/init/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/init/openssl_ca_db/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/init/help/further_read.txt' -e 'd}' > \
			build/init/openssl_ca_db/help/help.txt

init_openssl_ca_db: src/init/openssl_ca_db/init_openssl_ca_db.sh init_openssl_ca_db_help
	mkdir -p build/init/openssl_ca_db
	sed -e '/@@@HELP@@@/{r build/init/openssl_ca_db/help/help.txt' -e 'd}' \
			src/init/openssl_ca_db/init_openssl_ca_db.sh > build/init/openssl_ca_db/init_openssl_ca_db.sh

init_yubikey_help: common_help src/help/options.txt src/init/help/options.txt \
									src/init/yubikey/help/command_title.txt \
									src/init/yubikey/help/abstract.txt src/init/yubikey/help/syntax.txt \
									src/init/yubikey/help/options.txt src/init/yubikey/help/further_read.txt
	mkdir -p build/init/yubikey/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/init/yubikey/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/init/yubikey/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/init/yubikey/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@INIT OPTIONS@@@/{r src/init/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/init/yubikey/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/init/help/further_read.txt' -e 'd}' > \
			build/init/yubikey/help/help.txt

init_yubikey: src/init/yubikey/init_yubikey.sh init_yubikey_help
	mkdir -p build/init/yubikey
	sed -e '/@@@HELP@@@/{r build/init/yubikey/help/help.txt' -e 'd}' \
			src/init/yubikey/init_yubikey.sh > build/init/yubikey/init_yubikey.sh

init_help: common_help src/help/options.txt \
						src/init/help/command_title.txt src/init/help/abstract.txt \
						src/init/help/syntax.txt src/init/help/options.txt \
						src/init/help/further_read.txt
	mkdir -p build/init/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/init/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/init/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/init/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/init/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/init/help/further_read.txt' -e 'd}' > \
			build/init/help/help.txt

init: src/init/init.sh init_help init_demo init_sca_usb_stick init_openssl_ca_db \
				init_yubikey
	mkdir -p build/init
	sed -e '/@@@HELP@@@/{r build/init/help/help.txt' -e 'd}' \
			src/init/init.sh > build/init/init.sh
	cat build/init/demo/init_demo.sh 										build/init/sca_usb_stick/init_sca_usb_stick.sh \
			build/init/openssl_ca_db/init_openssl_ca_db.sh 	build/init/yubikey/init_yubikey.sh \
			>> build/init/init.sh

install_help: common_help src/help/options.txt \
						src/install/help/command_title.txt src/install/help/abstract.txt \
						src/install/help/syntax.txt src/install/help/options.txt \
						src/install/help/further_read.txt
	mkdir -p build/install/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/install/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/install/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/install/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/install/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/install/help/further_read.txt' -e 'd}' > \
			build/install/help/help.txt

install: src/install/install.sh install_help
	mkdir -p build/install
	sed -e '/@@@HELP@@@/{r build/install/help/help.txt' -e 'd}' \
			src/install/install.sh > build/install/install.sh

request_help: common_help src/help/options.txt \
								src/request/help/command_title.txt src/request/help/abstract.txt \
								src/request/help/syntax.txt src/request/help/options.txt \
								src/request/help/further_read.txt
	mkdir -p build/request/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/request/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/request/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/request/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/request/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/request/help/further_read.txt' -e 'd}' > \
			build/request/help/help.txt

request: src/request/request.sh request_help
	mkdir -p build/request
	sed -e '/@@@HELP@@@/{r build/request/help/help.txt' -e 'd}' \
			src/request/request.sh > build/request/request.sh

security_key_get_crt_help: common_help src/help/options.txt src/security_key/help/options.txt \
									src/security_key/get_crt/help/command_title.txt \
									src/security_key/get_crt/help/abstract.txt src/security_key/get_crt/help/syntax.txt \
									src/security_key/get_crt/help/options.txt src/security_key/get_crt/help/further_read.txt
	mkdir -p build/security_key/get_crt/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/security_key/get_crt/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/security_key/get_crt/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/security_key/get_crt/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@SECURITY_KEY OPTIONS@@@/{r src/security_key/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/security_key/get_crt/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/security_key/help/further_read.txt' -e 'd}' > \
			build/security_key/get_crt/help/help.txt

security_key_get_crt: src/security_key/get_crt/security_key_get_crt.sh security_key_get_crt_help
	mkdir -p build/security_key/get_crt
	sed -e '/@@@HELP@@@/{r build/security_key/get_crt/help/help.txt' -e 'd}' \
			src/security_key/get_crt/security_key_get_crt.sh > build/security_key/get_crt/security_key_get_crt.sh

security_key_id_help: common_help src/help/options.txt src/security_key/help/options.txt \
									src/security_key/id/help/command_title.txt \
									src/security_key/id/help/abstract.txt src/security_key/id/help/syntax.txt \
									src/security_key/id/help/options.txt src/security_key/id/help/further_read.txt
	mkdir -p build/security_key/id/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/security_key/id/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/security_key/id/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/security_key/id/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@SECURITY_KEY OPTIONS@@@/{r src/security_key/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/security_key/id/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/security_key/help/further_read.txt' -e 'd}' > \
			build/security_key/id/help/help.txt

security_key_id: src/security_key/id/security_key_id.sh security_key_id_help
	mkdir -p build/security_key/id
	sed -e '/@@@HELP@@@/{r build/security_key/id/help/help.txt' -e 'd}' \
src/security_key/id/security_key_id.sh > build/security_key/id/security_key_id.sh


security_key_init_help: common_help src/help/options.txt src/security_key/help/options.txt \
									src/security_key/init/help/command_title.txt \
									src/security_key/init/help/abstract.txt src/security_key/init/help/syntax.txt \
									src/security_key/init/help/options.txt src/security_key/init/help/further_read.txt
	mkdir -p build/security_key/init/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/security_key/init/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/security_key/init/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/security_key/init/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@SECURITY_KEY OPTIONS@@@/{r src/security_key/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/security_key/init/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/security_key/help/further_read.txt' -e 'd}' > \
			build/security_key/init/help/help.txt

security_key_init: src/security_key/init/security_key_init.sh security_key_init_help
	mkdir -p build/security_key/init
	sed -e '/@@@HELP@@@/{r build/security_key/init/help/help.txt' -e 'd}' \
		src/security_key/init/security_key_init.sh > build/security_key/init/security_key_init.sh

security_key_upload_help: common_help src/help/options.txt src/security_key/help/options.txt \
									src/security_key/upload/help/command_title.txt \
									src/security_key/upload/help/abstract.txt src/security_key/upload/help/syntax.txt \
									src/security_key/upload/help/options.txt src/security_key/upload/help/further_read.txt
	mkdir -p build/security_key/upload/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/security_key/upload/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/security_key/upload/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/security_key/upload/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@SECURITY_KEY OPTIONS@@@/{r src/security_key/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/security_key/upload/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/security_key/help/further_read.txt' -e 'd}' > \
			build/security_key/upload/help/help.txt

security_key_upload: src/security_key/upload/security_key_upload.sh security_key_upload_help
	mkdir -p build/security_key/upload
	sed -e '/@@@HELP@@@/{r build/security_key/upload/help/help.txt' -e 'd}' \
src/security_key/upload/security_key_upload.sh > build/security_key/upload/security_key_upload.sh

security_key_wait_for_help: common_help src/help/options.txt src/security_key/help/options.txt \
									src/security_key/wait_for/help/command_title.txt \
									src/security_key/wait_for/help/abstract.txt src/security_key/wait_for/help/syntax.txt \
									src/security_key/wait_for/help/options.txt src/security_key/wait_for/help/further_read.txt
	mkdir -p build/security_key/wait_for/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/security_key/wait_for/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/security_key/wait_for/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/security_key/wait_for/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@SECURITY_KEY OPTIONS@@@/{r src/security_key/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/security_key/wait_for/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/security_key/help/further_read.txt' -e 'd}' > \
			build/security_key/wait_for/help/help.txt

security_key_wait_for: src/security_key/wait_for/security_key_wait_for.sh security_key_wait_for_help
	mkdir -p build/security_key/wait_for
	sed -e '/@@@HELP@@@/{r build/security_key/wait_for/help/help.txt' -e 'd}' \
src/security_key/wait_for/security_key_wait_for.sh > build/security_key/wait_for/security_key_wait_for.sh

security_key_help: common_help src/help/options.txt \
						src/security_key/help/command_title.txt src/security_key/help/abstract.txt \
						src/security_key/help/syntax.txt src/security_key/help/options.txt \
						src/security_key/help/further_read.txt
	mkdir -p build/security_key/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/security_key/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/security_key/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/security_key/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/security_key/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/security_key/help/further_read.txt' -e 'd}' > \
			build/security_key/help/help.txt

security_key: src/security_key/security_key.sh security_key_help security_key_get_crt security_key_id security_key_init \
				security_key_upload security_key_wait_for
	mkdir -p build/security_key
	sed -e '/@@@HELP@@@/{r build/security_key/help/help.txt' -e 'd}' \
			src/security_key/security_key.sh > build/security_key/security_key.sh
	cat build/security_key/get_crt/security_key_get_crt.sh 	build/security_key/id/security_key_id.sh \
			build/security_key/init/security_key_init.sh 				build/security_key/upload/security_key_upload.sh \
			build/security_key/wait_for/security_key_wait_for.sh \
			>> build/security_key/security_key.sh

test_help: common_help src/help/options.txt \
								src/test/help/command_title.txt src/test/help/abstract.txt \
								src/test/help/syntax.txt src/test/help/options.txt \
								src/test/help/further_read.txt
	mkdir -p build/test/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/test/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/test/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/test/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/test/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/test/help/further_read.txt' -e 'd}' > \
			build/test/help/help.txt

test: src/test/test.sh test_help
	mkdir -p build/test
	sed -e '/@@@HELP@@@/{r build/test/help/help.txt' -e 'd}' \
			src/test/test.sh > build/test/test.sh


approve_help: common_help src/help/options.txt \
								src/approve/help/command_title.txt src/approve/help/abstract.txt \
								src/approve/help/syntax.txt src/approve/help/options.txt \
								src/approve/help/further_read.txt
	mkdir -p build/approve/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/approve/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/approve/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/approve/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/approve/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/approve/help/further_read.txt' -e 'd}' > \
			build/approve/help/help.txt

approve: src/approve/approve.sh approve_help
	mkdir -p build/approve
	sed -e '/@@@HELP@@@/{r build/approve/help/help.txt' -e 'd}' \
			src/approve/approve.sh > build/approve/approve.sh

config_create_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/create/help/command_title.txt \
									src/config/create/help/abstract.txt src/config/create/help/syntax.txt \
									src/config/create/help/options.txt src/config/create/help/further_read.txt
	mkdir -p build/config/create/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/create/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/create/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/create/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/create/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/create/help/help.txt

config_create: src/config/create/config_create.sh src/config/create/default_sca_config.sh \
								src/config/create/default_conventions.sh src/config/create/default_openssl_config.ini \
								config_create_help
	mkdir -p build/config/create
	sed -e '/@@@HELP@@@/{r build/config/create/help/help.txt' -e 'd}' \
	  src/config/create/config_create.sh | \
		sed -e '/@@@DEFAULT SCA CONFIG@@@/{r src/config/create/default_sca_config.sh' -e 'd}' | \
		sed -e '/@@@DEFAULT CONVENTIONS@@@/{r src/config/create/default_conventions.sh' -e 'd}' | \
		sed -e '/@@@DEFAULT OPENSSL CONFIG@@@/{r src/config/create/default_openssl_config.ini' -e 'd}' | \
		sed -e '/@@@PKCS11 OPENSSL CONFIG@@@/{r src/config/create/pkcs11_openssl_config.ini' -e 'd}' \
		> build/config/create/config_create.sh

config_get_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/get/help/command_title.txt \
									src/config/get/help/abstract.txt src/config/get/help/syntax.txt \
									src/config/get/help/options.txt src/config/get/help/further_read.txt
	mkdir -p build/config/get/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/get/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/get/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/get/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/get/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/get/help/help.txt

config_get: src/config/get/config_get.sh config_get_help
	mkdir -p build/config/get
	sed -e '/@@@HELP@@@/{r build/config/get/help/help.txt' -e 'd}' \
	  src/config/get/config_get.sh > build/config/get/config_get.sh



config_load_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/load/help/command_title.txt \
									src/config/load/help/abstract.txt src/config/load/help/syntax.txt \
									src/config/load/help/options.txt src/config/load/help/further_read.txt
	mkdir -p build/config/load/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/load/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/load/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/load/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/load/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/load/help/help.txt

config_load: src/config/load/config_load.sh config_load_help
	mkdir -p build/config/load
	sed -e '/@@@HELP@@@/{r build/config/load/help/help.txt' -e 'd}' \
	  src/config/load/config_load.sh > build/config/load/config_load.sh


config_reset_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/reset/help/command_title.txt \
									src/config/reset/help/abstract.txt src/config/reset/help/syntax.txt \
									src/config/reset/help/options.txt src/config/reset/help/further_read.txt
	mkdir -p build/config/reset/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/reset/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/reset/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/reset/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/reset/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/reset/help/help.txt

config_reset: src/config/reset/config_reset.sh config_reset_help
	mkdir -p build/config/reset
	sed -e '/@@@HELP@@@/{r build/config/reset/help/help.txt' -e 'd}' \
	  src/config/reset/config_reset.sh > build/config/reset/config_reset.sh


config_resolve_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/resolve/help/command_title.txt \
									src/config/resolve/help/abstract.txt src/config/resolve/help/syntax.txt \
									src/config/resolve/help/options.txt src/config/resolve/help/further_read.txt
	mkdir -p build/config/resolve/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/resolve/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/resolve/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/resolve/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/resolve/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/resolve/help/help.txt

config_resolve: src/config/resolve/config_resolve.sh config_resolve_help
	mkdir -p build/config/resolve
	sed -e '/@@@HELP@@@/{r build/config/resolve/help/help.txt' -e 'd}' \
	  src/config/resolve/config_resolve.sh > build/config/resolve/config_resolve.sh

config_save_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/save/help/command_title.txt \
									src/config/save/help/abstract.txt src/config/save/help/syntax.txt \
									src/config/save/help/options.txt src/config/save/help/further_read.txt
	mkdir -p build/config/save/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/save/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/save/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/save/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/save/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/save/help/help.txt

config_save: src/config/save/config_save.sh config_save_help
	mkdir -p build/config/save
	sed -e '/@@@HELP@@@/{r build/config/save/help/help.txt' -e 'd}' \
	  src/config/save/config_save.sh > build/config/save/config_save.sh

config_set_help: common_help src/help/options.txt src/config/help/options.txt \
									src/config/set/help/command_title.txt \
									src/config/set/help/abstract.txt src/config/set/help/syntax.txt \
									src/config/set/help/options.txt src/config/set/help/further_read.txt
	mkdir -p build/config/set/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/set/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/config/set/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/config/set/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@CONFIG OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/config/set/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/set/help/help.txt

config_set: src/config/set/config_set.sh config_set_help
	mkdir -p build/config/set
	sed -e '/@@@HELP@@@/{r build/config/set/help/help.txt' -e 'd}' \
	  src/config/set/config_set.sh > build/config/set/config_set.sh

config_help: common_help src/help/options.txt \
							src/config/help/command_title.txt src/config/help/abstract.txt \
							src/config/help/syntax.txt src/config/help/options.txt \
							src/config/help/further_read.txt
	mkdir -p build/config/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/config/help/command_title.txt' -e 'd}' \
			build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/config/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/config/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/config/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/config/help/further_read.txt' -e 'd}' > \
			build/config/help/help.txt

config: src/config/config.sh config_help config_create config_get config_load \
					config_reset config_resolve config_save config_set
	mkdir -p build/config
	sed -e '/@@@HELP@@@/{r build/config/help/help.txt' -e 'd}' \
			src/config/config.sh > build/config/config.sh
	cat build/config/create/config_create.sh 		build/config/get/config_get.sh \
			build/config/load/config_load.sh			 	build/config/reset/config_reset.sh \
			build/config/resolve/config_resolve.sh 	build/config/save/config_save.sh \
			build/config/set/config_set.sh \
			>> build/config/config.sh



list_cas_help: common_help src/help/options.txt src/list/help/options.txt \
									src/list/cas/help/command_title.txt \
									src/list/cas/help/abstract.txt src/list/cas/help/syntax.txt \
									src/list/cas/help/options.txt src/list/cas/help/further_read.txt
	mkdir -p build/list/cas/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/cas/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/list/cas/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/list/cas/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@LIST OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/list/cas/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/cas/help/help.txt

list_cas: src/list/cas/list_cas.sh list_cas_help
	mkdir -p build/list/cas
	sed -e '/@@@HELP@@@/{r build/list/cas/help/help.txt' -e 'd}' \
			src/list/cas/list_cas.sh > build/list/cas/list_cas.sh

list_configs_help: common_help src/help/options.txt src/list/help/options.txt \
									src/list/configs/help/command_title.txt \
									src/list/configs/help/abstract.txt src/list/configs/help/syntax.txt \
									src/list/configs/help/options.txt src/list/configs/help/further_read.txt
	mkdir -p build/list/configs/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/configs/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/list/configs/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/list/configs/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@LIST OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/list/configs/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/configs/help/help.txt

list_configs: src/list/configs/list_configs.sh list_configs_help
	mkdir -p build/list/configs
	sed -e '/@@@HELP@@@/{r build/list/configs/help/help.txt' -e 'd}' \
			src/list/configs/list_configs.sh > build/list/configs/list_configs.sh

list_hosts_help: common_help src/help/options.txt src/list/help/options.txt \
									src/list/hosts/help/command_title.txt \
									src/list/hosts/help/abstract.txt src/list/hosts/help/syntax.txt \
									src/list/hosts/help/options.txt src/list/hosts/help/further_read.txt
	mkdir -p build/list/hosts/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/hosts/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/list/hosts/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/list/hosts/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@LIST OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/list/hosts/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/hosts/help/help.txt

list_hosts: src/list/hosts/list_hosts.sh list_hosts_help
	mkdir -p build/list/hosts
	sed -e '/@@@HELP@@@/{r build/list/hosts/help/help.txt' -e 'd}' \
			src/list/hosts/list_hosts.sh > build/list/hosts/list_hosts.sh

list_services_help: common_help src/help/options.txt src/list/help/options.txt \
									src/list/services/help/command_title.txt \
									src/list/services/help/abstract.txt src/list/services/help/syntax.txt \
									src/list/services/help/options.txt src/list/services/help/further_read.txt
	mkdir -p build/list/services/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/services/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/list/services/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/list/services/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@LIST OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/list/services/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/services/help/help.txt

list_services: src/list/services/list_services.sh list_services_help
	mkdir -p build/list/services
	sed -e '/@@@HELP@@@/{r build/list/services/help/help.txt' -e 'd}' \
			src/list/services/list_services.sh > build/list/services/list_services.sh

list_subcas_help: common_help src/help/options.txt src/list/help/options.txt \
									src/list/subcas/help/command_title.txt \
									src/list/subcas/help/abstract.txt src/list/subcas/help/syntax.txt \
									src/list/subcas/help/options.txt src/list/subcas/help/further_read.txt
	mkdir -p build/list/subcas/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/subcas/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/list/subcas/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/list/subcas/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@LIST OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/list/subcas/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/subcas/help/help.txt

list_subcas: src/list/subcas/list_subcas.sh list_subcas_help
	mkdir -p build/list/subcas
	sed -e '/@@@HELP@@@/{r build/list/subcas/help/help.txt' -e 'd}' \
			src/list/subcas/list_subcas.sh > build/list/subcas/list_subcas.sh

list_users_help: common_help src/help/options.txt src/list/help/options.txt \
									src/list/users/help/command_title.txt \
									src/list/users/help/abstract.txt src/list/users/help/syntax.txt \
									src/list/users/help/options.txt src/list/users/help/further_read.txt
	mkdir -p build/list/users/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/users/help/command_title.txt' -e 'd}' \
		  build/common/help/help.txt | \
		  sed -e '/@@@ABSTRACT@@@/{r src/list/users/help/abstract.txt' -e 'd}' | \
		  sed -e '/@@@SYNTAX@@@/{r src/list/users/help/syntax.txt' -e 'd}' | \
		  sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
		  sed -e '/@@@LIST OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
		  sed -e '/@@@OPTIONS@@@/{r src/list/users/help/options.txt' -e 'd}' | \
		  sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/users/help/help.txt

list_users: src/list/users/list_users.sh list_users_help
	mkdir -p build/list/users
	sed -e '/@@@HELP@@@/{r build/list/users/help/help.txt' -e 'd}' \
			src/list/users/list_users.sh > build/list/users/list_users.sh

list_help: common_help src/help/options.txt \
						src/list/help/command_title.txt src/list/help/abstract.txt \
						src/list/help/syntax.txt src/list/help/options.txt \
						src/list/help/further_read.txt
	mkdir -p build/list/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/list/help/command_title.txt' -e 'd}' \
	 		build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/list/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/list/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/list/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/list/help/further_read.txt' -e 'd}' > \
			build/list/help/help.txt

list: src/list/list.sh list_help list_cas list_configs list_hosts list_services \
				list_subcas list_users
	mkdir -p build/list
	sed -e '/@@@HELP@@@/{r build/list/help/help.txt' -e 'd}' \
			src/list/list.sh > build/list/list.sh
	cat build/list/cas/list_cas.sh  	build/list/configs/list_configs.sh  \
	build/list/hosts/list_hosts.sh 		build/list/services/list_services.sh \
	build/list/subcas/list_subcas.sh 	build/list/users/list_users.sh \
	>> build/list/list.sh

completion_help: common_help src/help/options.txt \
						src/completion/help/command_title.txt src/completion/help/abstract.txt \
						src/completion/help/syntax.txt src/completion/help/options.txt \
						src/completion/help/further_read.txt
	mkdir -p build/completion/help
	sed -e '/@@@COMMAND TITLE@@@/{r src/completion/help/command_title.txt' -e 'd}' \
	 		build/common/help/help.txt | \
			sed -e '/@@@ABSTRACT@@@/{r src/completion/help/abstract.txt' -e 'd}' | \
			sed -e '/@@@SYNTAX@@@/{r src/completion/help/syntax.txt' -e 'd}' | \
			sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
			sed -e '/@@@OPTIONS@@@/{r src/completion/help/options.txt' -e 'd}' | \
			sed -e '/@@@FURTHER READ@@@/{r src/completion/help/further_read.txt' -e 'd}' > \
			build/completion/help/help.txt

completion: src/completion/completion.sh completion_help \
			src/approve/complete_bash.sh 		src/completion/complete_bash.sh  \
			src/config/complete_bash.sh 		src/create/complete_bash.sh \
			src/display/complete_bash.sh 		src/export/complete_bash.sh \
			src/import/complete_bash.sh			src/init/complete_bash.sh \
			src/list/complete_bash.sh				src/request/complete_bash.sh \
			src/test/complete_bash.sh				src/security_key/complete_bash.sh \
			src/complete_bash.sh
	mkdir -p build/completion
	echo "#!/bin/bash" > build/completion/completion_scripts.sh
	cat src/approve/complete_bash.sh  			src/completion/complete_bash.sh  \
			src/config/complete_bash.sh 				src/create/complete_bash.sh \
			src/display/complete_bash.sh 				src/export/complete_bash.sh \
			src/import/complete_bash.sh					src/init/complete_bash.sh \
			src/list/complete_bash.sh						src/request/complete_bash.sh \
			src/test/complete_bash.sh						src/install/complete_bash.sh \
			src/security_key/complete_bash.sh 	src/complete_bash.sh | \
			sed -e 's/'"'"'/'"'"'"'"'"'"'"'"'/g' \
			>> build/completion/completion_scripts.sh
	sed -e '/@@@HELP@@@/{r build/completion/help/help.txt' -e 'd}' \
			src/completion/completion.sh | \
			sed -e '/@@@BASH COMPLETION@@@/{r build/completion/completion_scripts.sh' -e 'd}' > \
			build/completion/completion.sh

clean:
	rm -rf build/*
