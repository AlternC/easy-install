# regenerates the files for translations

all: locales

locales: ./en/LC_MESSAGES/alternc-easy-install.mo ./fr/LC_MESSAGES/alternc-easy-install.mo

./en/LC_MESSAGES/alternc-easy-install.mo: ./en/LC_MESSAGES/alternc-easy-install.po
	[ -r $@ ] || touch $@
	msgfmt ./en/LC_MESSAGES/alternc-easy-install.po -o ./en/LC_MESSAGES/alternc-easy-install.mo

./fr/LC_MESSAGES/alternc-easy-install.mo: ./fr/LC_MESSAGES/alternc-easy-install.po
	[ -r $@ ] || touch $@
	msgfmt ./fr/LC_MESSAGES/alternc-easy-install.po -o ./fr/LC_MESSAGES/alternc-easy-install.mo

./%/LC_MESSAGES/alternc-easy-install.po: ./alternc-easy-install.pot
	[ -r $@ ] || touch $@
	msgmerge -v -U $@ $^

./alternc-easy-install.pot: ../install.sh ../lib_installer.sh 
	[ -r $@ ] || touch $@
	xgettext --from-code=UTF-8 --force-po -j -L Shell -kmisc -kdebug -kwarn -kinfo -kask -kalert $^ -o $@ 


