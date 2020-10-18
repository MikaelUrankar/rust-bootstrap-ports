PORTNAME=	rust
PORTVERSION=	1.47.0
CATEGORIES=	lang
MASTER_SITES=	https://static.rust-lang.org/dist/:rust \
		LOCAL/tobik:armbase \
		LOCAL/tobik:base \
		https://download.freebsd.org/ftp/releases/arm64/11.3-RELEASE/base.txz?dummy=/:base_aarch64 \
		https://download.freebsd.org/ftp/releases/i386/11.3-RELEASE/base.txz?dummy=/:base_i386 \
		https://download.freebsd.org/ftp/snapshots/powerpc/powerpc64/13.0-CURRENT/base.txz?dummy=/:base_powerpc64_elfv2 \
		https://download.freebsd.org/ftp/snapshots/powerpc/powerpc64le/13.0-CURRENT/base.txz?dummy=/:base_powerpc64le

PKGNAMESUFFIX=	-bootstrap
DISTNAME=	${PORTNAME}c-${PORTVERSION}-src
DISTFILES=	rust/${DISTNAME}${EXTRACT_SUFX}:rust \
		FreeBSD-11.3-RELEASE-arm64${EXTRACT_SUFX}:base_aarch64 \
		FreeBSD-11.3-RELEASE-arm-armv6${EXTRACT_SUFX}:armbase \
		FreeBSD-12.1-RELEASE-arm-armv7${EXTRACT_SUFX}:armbase \
		FreeBSD-11.3-RELEASE-i386${EXTRACT_SUFX}:base_i386 \
		FreeBSD-13.0-CURRENT-powerpc64-elfv2${EXTRACT_SUFX}:base_powerpc64_elfv2 \
		FreeBSD-13.0-CURRENT-powerpc64le${EXTRACT_SUFX}:base_powerpc64le
EXTRACT_ONLY=	rust/rustc-${PORTVERSION}-src.tar.xz

		#https://download.freebsd.org/ftp/releases/amd64/11.3-RELEASE/base.txz?dummy=/:base_amd64 \
		#FreeBSD-11.3-RELEASE-amd64${EXTRACT_SUFX}:base_amd64 \

MAINTAINER=	rust@FreeBSD.org
COMMENT=	Create bootstrap compilers for building lang/rust

LICENSE=	APACHE20 MIT
LICENSE_COMB=	dual
LICENSE_FILE_APACHE20=	${WRKSRC}/LICENSE-APACHE
LICENSE_FILE_MIT=	${WRKSRC}/LICENSE-MIT

ONLY_FOR_ARCHS=	amd64
ONLY_FOR_ARCHS_REASON=	only for amd64

BUILD_DEPENDS=	cmake:devel/cmake \
		gmake:devel/gmake \

		#rust>=${PORTVERSION}:lang/rust

USES=		perl5 python:3.3+,build tar:xz

# for openssl-src crate
USE_PERL5=	build
PATCHDIR=	${.CURDIR}/../rust/files
# Resulting packages are not specific to amd64
NO_ARCH=	yes

_CARGO_VENDOR_DIR=	${WRKSRC}/vendor
_RUST_HOST=		x86_64-unknown-freebsd

EXTRA_PATCHES+=	${PATCHDIR}/powerpc64-elfv2 \
		${PATCHDIR}/powerpc64le

post-extract:
.for _RUST_TARGET in aarch64-unknown-freebsd armv6-unknown-freebsd armv7-unknown-freebsd i686-unknown-freebsd powerpc64-unknown-freebsd powerpc64le-unknown-freebsd
	${MKDIR} ${WRKDIR}/${_RUST_TARGET}
.endfor
	${TAR} ${EXTRACT_AFTER_ARGS} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/FreeBSD-11.3-RELEASE-arm64.tar.xz -C ${WRKDIR}/aarch64-unknown-freebsd
	${TAR} ${EXTRACT_AFTER_ARGS} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/FreeBSD-11.3-RELEASE-arm-armv6.tar.xz -C ${WRKDIR}/armv6-unknown-freebsd
	${TAR} ${EXTRACT_AFTER_ARGS} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/FreeBSD-12.1-RELEASE-arm-armv7.tar.xz -C ${WRKDIR}/armv7-unknown-freebsd
	${TAR} ${EXTRACT_AFTER_ARGS} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/FreeBSD-11.3-RELEASE-i386.tar.xz -C ${WRKDIR}/i686-unknown-freebsd
	${TAR} ${EXTRACT_AFTER_ARGS} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/FreeBSD-13.0-CURRENT-powerpc64-elfv2.tar.xz -C ${WRKDIR}/powerpc64-unknown-freebsd
	${TAR} ${EXTRACT_AFTER_ARGS} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/FreeBSD-13.0-CURRENT-powerpc64le.tar.xz -C ${WRKDIR}/powerpc64le-unknown-freebsd

post-patch:
# Disable vendor checksums
	@${REINPLACE_CMD} 's,"files":{[^}]*},"files":{},' \
		${_CARGO_VENDOR_DIR}/*/.cargo-checksum.json

do-configure:
# Check that the running kernel has COMPAT_FREEBSD11 required by lang/rust post-ino64
	@${SETENV} CC="${CC}" OPSYS="${OPSYS}" OSVERSION="${OSVERSION}" WRKDIR="${WRKDIR}" \
		${SH} ${SCRIPTSDIR}/rust-compat11-canary.sh
	@${ECHO_CMD} '[build]' > ${WRKSRC}/config.toml
	@${ECHO_CMD} 'vendor=true' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'extended=false' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'python="${PYTHON_CMD}"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'docs=false' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'verbose=2' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'cargo-native-static=true' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'cargo="${LOCALBASE}/bin/cargo"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'rustc="${LOCALBASE}/bin/rustc"' >> ${WRKSRC}/config.toml

	@${ECHO_CMD} 'host=["aarch64-unknown-freebsd", "armv6-unknown-freebsd", "armv7-unknown-freebsd", "i686-unknown-freebsd", "powerpc64-unknown-freebsd", "powerpc64le-unknown-freebsd", "x86_64-unknown-freebsd"]' >> ${WRKSRC}/config.toml
# We're building on amd64, we cross compile for these arches
.for _RUST_TARGET in aarch64-unknown-freebsd armv6-unknown-freebsd armv7-unknown-freebsd i686-unknown-freebsd powerpc64-unknown-freebsd powerpc64le-unknown-freebsd
	@${ECHO_CMD} 'target=["${_RUST_TARGET}"]' >> ${WRKSRC}/config.toml
.endfor
	@${ECHO_CMD} '[rust]' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'channel="stable"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'default-linker="${CC}"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'deny-warnings=false' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} '[llvm]' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'link-shared=false' >> ${WRKSRC}/config.toml
.if defined(WITH_CCACHE_BUILD) && !defined(NO_CCACHE)
	@${ECHO_CMD} 'ccache="${CCACHE_BIN}"' >> ${WRKSRC}/config.toml
.else
	@${ECHO_CMD} 'ccache=false' >> ${WRKSRC}/config.toml
.endif
# https://github.com/rust-lang/rust/pull/72696#issuecomment-641517185
	@${ECHO_CMD} 'ldflags="-lz"' >> ${WRKSRC}/config.toml
.for _RUST_TARGET in aarch64-unknown-freebsd armv6-unknown-freebsd armv7-unknown-freebsd i686-unknown-freebsd powerpc64-unknown-freebsd powerpc64le-unknown-freebsd
	@${ECHO_CMD} '[target.${_RUST_TARGET}]' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'cc="${WRKDIR}/${_RUST_TARGET}-cc"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'cxx="${WRKDIR}/${_RUST_TARGET}-c++"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'linker="${WRKDIR}/${_RUST_TARGET}-cc"' >> ${WRKSRC}/config.toml
.for _key _util in ar ${AR} ranlib ${RANLIB}
	@bin="$$(which ${_util})"; \
		${ECHO_CMD} "${_key}=\"$$bin\"" >> ${WRKSRC}/config.toml
.endfor
.endfor
	@${ECHO_CMD} '[target.${_RUST_HOST}]' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'cc="${CC}"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'cxx="${CXX}"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'linker="${CC}"' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} '[dist]' >> ${WRKSRC}/config.toml
	@${ECHO_CMD} 'src-tarball=false' >> ${WRKSRC}/config.toml
.for _RUST_TARGET in aarch64-unknown-freebsd armv6-unknown-freebsd armv7-unknown-freebsd i686-unknown-freebsd powerpc64-unknown-freebsd powerpc64le-unknown-freebsd
.if ${_RUST_TARGET} == powerpc64-unknown-freebsd
	@${PRINTF} '#!/bin/sh\nexec ${CC} --sysroot=${WRKDIR}/${_RUST_TARGET} -mabi=elfv2 --target=${_RUST_TARGET} "$$@"\n' \
		> ${WRKDIR}/${_RUST_TARGET}-cc
	@${PRINTF} '#!/bin/sh\nexec ${CXX} --sysroot=${WRKDIR}/${_RUST_TARGET} -mabi=elfv2 --target=${_RUST_TARGET} -stdlib=libc++ "$$@"\n' \
		> ${WRKDIR}/${_RUST_TARGET}-c++
.elif ${_RUST_TARGET} == armv6-gnueabihf-freebsd || ${_RUST_TARGET} == armv7-gnueabihf-freebsd
.else
	@${PRINTF} '#!/bin/sh\nexec ${CC} --sysroot=${WRKDIR}/${_RUST_TARGET} --target=${_RUST_TARGET:S/unknown/gnueabihf/} "$$@"\n' \
		> ${WRKDIR}/${_RUST_TARGET}-cc
	@${PRINTF} '#!/bin/sh\nexec ${CXX} --sysroot=${WRKDIR}/${_RUST_TARGET} --target=${_RUST_TARGET:S/unknown/gnueabihf/} -stdlib=libc++ "$$@"\n' \
		> ${WRKDIR}/${_RUST_TARGET}-c++
.endif
	@${CHMOD} +x ${WRKDIR}/${_RUST_TARGET}-c*
# sanity check cross compilers.  we cannot execute the result but
# at least check that it can link a simple program before going further.
	@${PRINTF} '#include <stdio.h>\nint main(){return printf("hello\\n");}' | ${WRKDIR}/${_RUST_TARGET}-cc -o ${WRKDIR}/test-c -xc -
# produce some useful info for the build logs like what release/arch test-c is compiled for
	@cd ${WRKDIR} && ${FILE} test-c && ${READELF} -A test-c
	@${PRINTF} '#include <iostream>\nint main(){std::cout<<"hello"<<std::endl;return 0;}' | ${WRKDIR}/${_RUST_TARGET}-c++ -o ${WRKDIR}/test-c++ -xc++ -
.endfor

do-build:
	@cd ${WRKSRC} && \
		${SETENV} ${MAKE_ENV} ${PYTHON_CMD} x.py dist --jobs=${MAKE_JOBS_NUMBER} \
		cargo src/librustc library/std

.include <bsd.port.mk>
