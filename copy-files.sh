#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <upstream-version>-<revision> [--git] [--source <dir>]"
    echo "  e.g. $0 1.4-2                        # stable release, source at ../surge"
    echo "       $0 1.4-2 --git                   # pre-release snapshot"
    echo "       $0 1.4-2 --source ~/src/surge    # custom source directory"
    exit 1
}

SOURCE="../surge"

# Parse arguments
INPUT=""
GIT_VERSION=false

while [ $# -gt 0 ]; do
    case "$1" in
        --git)    GIT_VERSION=true ;;
        --source) shift; SOURCE="$1" ;;
        -*)       usage ;;
        *)        [ -n "${INPUT}" ] && usage; INPUT="$1" ;;
    esac
    shift
done

[ -z "${INPUT}" ] && usage

# Split on last '-' to get upstream and revision
UPSTREAM="${INPUT%-*}"
REVISION="${INPUT##*-}"

if [ "${UPSTREAM}" = "${INPUT}" ]; then
    echo "Error: version must be in the form <upstream>-<revision>"
    usage
fi

if [ "${GIT_VERSION}" = true ]; then
    VERSION="${UPSTREAM}~git$(date +%Y%m%d)-${REVISION}"
else
    VERSION="${INPUT}"
fi

SRCBINS="${SOURCE}/build/surge_xt_products"
SRCDATA="${SOURCE}/resources/data"

if [ ! -d "${SRCBINS}" ]; then
    echo "Error: build output not found at ${SRCBINS}"
    echo "Has the build been run in ${SOURCE}?"
    exit 1
fi
if [ ! -d "${SRCDATA}" ]; then
    echo "Error: data directory not found at ${SRCDATA}"
    exit 1
fi

PKG="surge-xt-for-rpi"
PKGDIR="${PKG}_${VERSION}"
BINDIR="${PKGDIR}/usr/bin"
TEMPLATE="template"

echo "Building package: ${PKG}_${VERSION} from ${SOURCE}"

# Bail if package directory already exists
if [ -d "${PKGDIR}" ]; then
    echo "Error: package directory ${PKGDIR} already exists"
    exit 1
fi

# Create directory structure
mkdir -p "${BINDIR}"
mkdir -p "${PKGDIR}/usr/share/surge-xt"
mkdir -p "${PKGDIR}/usr/share/doc/${PKG}"
mkdir -p "${PKGDIR}/usr/share/lintian/overrides"
mkdir -p "${PKGDIR}/DEBIAN"

# Copy data files
echo "Copying data files from ${SRCDATA}..."
cp -r "${SRCDATA}/." "${PKGDIR}/usr/share/surge-xt/"
find "${PKGDIR}/usr/share/surge-xt" -name '.DS_Store' -delete

# Copy binaries and strip them before chown
echo "Copying and stripping binaries from ${SRCBINS}..."
cp "${SRCBINS}/Surge XT"         "${BINDIR}/surge-xt"
cp "${SRCBINS}/Surge XT Effects" "${BINDIR}/surge-xt-effects"
cp "${SRCBINS}/surge-xt-cli"     "${BINDIR}/surge-xt-cli"

chmod 755 "${BINDIR}/surge-xt" "${BINDIR}/surge-xt-effects" "${BINDIR}/surge-xt-cli"
strip --strip-unneeded "${BINDIR}/surge-xt"
strip --strip-unneeded "${BINDIR}/surge-xt-effects"
strip --strip-unneeded "${BINDIR}/surge-xt-cli"

# Copy static template files
echo "Copying package metadata from template..."
cp "${TEMPLATE}/usr/share/doc/${PKG}/copyright"          "${PKGDIR}/usr/share/doc/${PKG}/copyright"
cp "${TEMPLATE}/usr/share/lintian/overrides/${PKG}"      "${PKGDIR}/usr/share/lintian/overrides/${PKG}"
gzip -9 -n -c "${TEMPLATE}/usr/share/doc/${PKG}/changelog.Debian" \
    > "${PKGDIR}/usr/share/doc/${PKG}/changelog.Debian.gz"

# Calculate installed size (in KB, excluding DEBIAN/)
INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "${PKGDIR}" | cut -f1)

# Substitute version and installed size into control template
sed \
    -e "s/@VERSION@/${VERSION}/" \
    -e "s/@INSTALLED_SIZE@/${INSTALLED_SIZE}/" \
    "${TEMPLATE}/DEBIAN/control" > "${PKGDIR}/DEBIAN/control"

# Fix ownership
echo "Setting ownership..."
sudo chown -R root:root "${PKGDIR}"

echo ""
echo "Done. Package directory: ${PKGDIR}"
echo "Changelog reminder: update ${TEMPLATE}/usr/share/doc/${PKG}/changelog.Debian before building."
echo ""
echo "Build with:"
echo "  sudo dpkg-deb --build ${PKGDIR}"
