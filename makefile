KNOCONFIG         = knoconfig
KNOBUILD          = knobuild

prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
CMODULES	::= $(DESTDIR)$(shell ${KNOCONFIG} cmodules)
LIBS		::= $(shell ${KNOCONFIG} libs)
LIB		::= $(shell ${KNOCONFIG} lib)
INCLUDE		::= $(shell ${KNOCONFIG} include)
KNO_VERSION	::= $(shell ${KNOCONFIG} version)
KNO_MAJOR	::= $(shell ${KNOCONFIG} major)
KNO_MINOR	::= $(shell ${KNOCONFIG} minor)
PKG_VERSION     ::= $(shell cat ./version)
PKG_MAJOR       ::= $(shell cat ./version | cut -d. -f1)
FULL_VERSION    ::= ${KNO_MAJOR}.${KNO_MINOR}.${PKG_VERSION}
PATCHLEVEL      ::= $(shell u8_gitpatchcount ./version)
PATCH_VERSION   ::= ${FULL_VERSION}-${PATCHLEVEL}

PKG_NAME	::= leveldb
DPKG_NAME	::= ${PKG_NAME}_${PATCH_VERSION}

INIT_CFLAGS  	::= ${CFLAGS}
INIT_LDFLAGS 	::= ${LDFLAGS}
KNO_CFLAGS	::= -I. -fPIC $(shell ${KNOCONFIG} cflags)
KNO_LDFLAGS	::= -fPIC $(shell ${KNOCONFIG} ldflags)
LEVELDB_CFLAGS  ::= 
LEVELDB_LDFLAGS ::= -lleveldb
SUDO  		::= $(shell which sudo)


CFLAGS		  = ${INIT_CFLAGS} ${LEVELDB_CFLAGS} ${KNO_CFLAGS} 
LDFLAGS		  = ${INIT_LDFLAGS} ${LEVELDB_LDFLAGS} ${KNO_LDFLAGS}
MKSO		  = $(CC) -shared $(CFLAGS) $(LDFLAGS) $(LIBS)
SYSINSTALL        = /usr/bin/install -c
MSG		  = echo

GPGID             = FE1BC737F9F323D732AA26330620266BE5AFF294
CODENAME	::= $(shell ${KNOCONFIG} codename)
REL_BRANCH	::= $(shell ${KNOBUILD} getbuildopt REL_BRANCH current)
REL_STATUS	::= $(shell ${KNOBUILD} getbuildopt REL_STATUS stable)
REL_PRIORITY	::= $(shell ${KNOBUILD} getbuildopt REL_PRIORITY medium)
ARCH            ::= $(shell ${KNOBUILD} getbuildopt BUILD_ARCH || uname -m)
APKREPO         ::= $(shell ${KNOBUILD} getbuildopt APKREPO /srv/repo/kno/apk)
APK_ARCH_DIR      = ${APKREPO}/staging/${ARCH}

default build: ${PKG_NAME}.${libsuffix}

leveldb.o: leveldb.c makefile
	@$(CC) $(CFLAGS) -o $@ -c $<
	@$(MSG) CC "(LEVELDB)" $@
leveldb.so: leveldb.o
	@$(MKSO) $(LDFLAGS) -o $@ leveldb.o ${LDFLAGS}
	@if test ! -z "${COPY_CMODS}"; then cp $@ ${COPY_CMODS}; fi;
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
leveldb.dylib: leveldb.c makefile
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} ${LDFLAGS} -o $@ $(DYLIB_FLAGS) \
		leveldb.c
	@if test ! -z "${COPY_CMODS}"; then cp $@ ${COPY_CMODS}; fi;
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: leveldb.c
	etags -o TAGS leveldb.c

${CMODULES}:
	install -d $@

install: build ${CMODULES}
	@${SUDO} ${SYSINSTALL} ${PKG_NAME}.${libsuffix} \
			${CMODULES}/${PKG_NAME}.so.${FULL_VERSION}
	@echo === Installed ${CMODULES}/${PKG_NAME}.so.${FULL_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${FULL_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}.${PKG_MAJOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}${PKG_MAJOR} \
		to ${PKG_NAME}.so.${FULL_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${FULL_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} \
		to ${PKG_NAME}.so.${FULL_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${FULL_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR} \
		to ${PKG_NAME}.so.${FULL_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${FULL_VERSION} ${CMODULES}/${PKG_NAME}.so
	@echo === Linked ${CMODULES}/${PKG_NAME}.so to ${PKG_NAME}.so.${FULL_VERSION}

clean:
	rm -f *.o *.${libsuffix}
fresh:
	make clean
	make default

gitup gitup-trunk:
	git checkout trunk && git pull

# Debian packaging

DEBFILES=changelog.base compat control copyright dirs docs install

debian: leveldb.c makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian
	cd debian; chmod a-x ${DEBFILES}

debian/changelog: debian leveldb.c makefile
	cat debian/changelog.base | \
		knobuild debchangelog kno-${PKG_NAME} ${CODENAME} \
			${REL_BRANCH} ${REL_STATUS} ${REL_PRIORITY} \
	    > $@.tmp
	if test ! -f debian/changelog; then \
	  mv debian/changelog.tmp debian/changelog; \
	elif diff debian/changelog debian/changelog.tmp 2>&1 > /dev/null; then \
	  mv debian/changelog.tmp debian/changelog; \
	else rm debian/changelog.tmp; fi

dist/debian.built: leveldb.c makefile debian debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

dist/debian.signed: dist/debian.built
	debsign --re-sign -k${GPGID} ../kno-leveldb_*.changes && \
	touch $@

deb debs dpkg dpkgs: dist/debian.signed

dist/debian.updated: dist/debian.signed
	dupload -c ./dist/dupload.conf --nomail --to bionic ../kno-leveldb_*.changes && touch $@

update-apt: dist/debian.updated

debinstall: dist/debian.signed
	${SUDO} dpkg -i ../kno-leveldb*.deb

debclean: clean
	rm -rf ../kno-leveldb_* ../kno-leveldb-* debian dist/debian.* staging/kno-leveldb

debfresh:
	make debclean
	make dist/debian.signed

# Alpine packaging

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/kno-${PKG_NAME}.tar: staging/alpine
	git archive --prefix=kno-${PKG_NAME}/ -o staging/alpine/kno-${PKG_NAME}.tar HEAD

dist/alpine.setup: staging/alpine/APKBUILD makefile ${STATICLIBS} \
	staging/alpine/kno-${PKG_NAME}.tar
	if [ ! -d ${APK_ARCH_DIR} ]; then mkdir -p ${APK_ARCH_DIR}; fi && \
	( cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum ) && \
	touch $@

dist/alpine.done: dist/alpine.setup
	( cd staging/alpine; abuild -P ${APKREPO} ) && touch $@
dist/alpine.installed: dist/alpine.setup
	( cd staging/alpine; abuild -i -P ${APKREPO} ) && touch dist/alpine.done && touch $@


alpine: dist/alpine.done
install-alpine: dist/alpine.done

.PHONY: alpine

