KNOCONFIG       ::= knoconfig
prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell ${KNOCONFIG} cflags)
KNO_LDFLAGS	::= -fPIC $(shell ${KNOCONFIG} ldflags)
LEVELDB_CFLAGS  ::= 
LEVELDB_LDFLAGS ::= -lleveldb
CFLAGS		::= ${CFLAGS} ${LEVELDB_CFLAGS} ${KNO_CFLAGS} 
LDFLAGS		::= ${LDFLAGS} ${LEVELDB_LDFLAGS} ${KNO_LDFLAGS}
CMODULES	::= $(DESTDIR)$(shell ${KNOCONFIG} cmodules)
LIBS		::= $(shell ${KNOCONFIG} libs)
LIB		::= $(shell ${KNOCONFIG} lib)
INCLUDE		::= $(shell ${KNOCONFIG} include)
KNO_VERSION	::= $(shell ${KNOCONFIG} version)
KNO_MAJOR	::= $(shell ${KNOCONFIG} major)
KNO_MINOR	::= $(shell ${KNOCONFIG} minor)
PKG_RELEASE	::= $(cat ./etc/release)
DPKG_NAME	::= $(shell ./etc/dpkgname)
MKSO		::= $(CC) -shared $(CFLAGS) $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
PKG_NAME	::= leveldb
PKG_RELEASE     ::= $(shell cat etc/release)
PKG_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${PKG_RELEASE}
APKREPO         ::= $(shell ${KNOCONFIG} apkrepo)
CODENAME	::= $(shell ${KNOCONFIG} codename)
RELSTATUS	::= $(shell ${KNOCONFIG} status)

GPGID = FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO  = $(shell which sudo)

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
			${CMODULES}/${PKG_NAME}.so.${PKG_VERSION}
	@echo === Installed ${CMODULES}/${PKG_NAME}.so.${PKG_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${PKG_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} \
		to ${PKG_NAME}.so.${PKG_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${PKG_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR} \
		to ${PKG_NAME}.so.${PKG_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${PKG_VERSION} ${CMODULES}/${PKG_NAME}.so
	@echo === Linked ${CMODULES}/${PKG_NAME}.so to ${PKG_NAME}.so.${PKG_VERSION}

clean:
	rm -f *.o *.${libsuffix}
fresh:
	make clean
	make default

debian: leveldb.c makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian

debian/changelog: debian leveldb.c makefile
	cat debian/changelog.base | \
		knomod debchangelog kno-${PKG_NAME} ${CODENAME} ${RELSTATUS} > $@.tmp
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
	make dist/debian.built

# Alpine packaging

${APKREPO}/dist/x86_64:
	@install -d $@

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/kno-${PKG_NAME}.tar: staging/alpine
	git archive --prefix=kno-${PKG_NAME}/ -o staging/alpine/kno-${PKG_NAME}.tar HEAD

dist/alpine.done: staging/alpine/APKBUILD makefile \
	staging/alpine/kno-${PKG_NAME}.tar ${APKREPO}/dist/x86_64
	cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum && \
		abuild -P ${APKREPO} && \
		touch ../../$@

alpine: dist/alpine.done

.PHONY: alpine

