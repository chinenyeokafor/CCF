#!/bin/bash

set -ex

if [ -z "$SOURCE_DATE_EPOCH" ]; then
    echo "SOURCE_DATE_EPOCH is not set. Please set it to the commit date of CCF."
    exit 1
fi
if [ -z "$PLATFORM" ]; then
    echo "PLATFORM is not set"
    exit 1
fi
if [ -z "$COMMIT_ID" ]; then
    echo "PLATFORM is not set"
    exit 1
fi

# Install dependencies
gpg --import /etc/pki/rpm-gpg/MICROSOFT-RPM-GPG-KEY 
tdnf --snapshottime=$SOURCE_DATE_EPOCH -y update 
tdnf --snapshottime=$SOURCE_DATE_EPOCH -y install ca-certificates git

#Install dependencies for CCF build
git clone https://github.com/microsoft/CCF.git /CCF 
cd /CCF 
git checkout ${COMMIT_ID} 
sed -i '/^set /a\
tdnf() {\n\
    command tdnf --snapshottime="$SOURCE_DATE_EPOCH" "$@"\n\
}\n\
export -f tdnf\n' scripts/setup-ci.sh 
./scripts/setup-ci.sh

# Build Release
COMPILE_TARGET=${PLATFORM}
mkdir build && cd build 
cmake -GNinja -DCOMPILE_TARGET=${COMPILE_TARGET} -DCLIENT_PROTOCOLS_TEST=ON -DCMAKE_BUILD_TYPE=Release .. 
ninja -v | tee build.log

# Make .rpm devel package
cmake -L .. 2>/dev/null | grep CMAKE_INSTALL_PREFIX: | cut -d = -f 2 > /tmp/install_prefix 
cpack -V -G RPM 
INITIAL_PKG=$(ls *devel*.rpm) 
FINAL_PKG=${INITIAL_PKG//\~/_} 
if [ "$INITIAL_PKG" != "$FINAL_PKG" ]; then mv "$INITIAL_PKG" "$FINAL_PKG"; fi
sha256sum $FINAL_PKG > /rpm_devel_digest.txt

# Make.rpm package
rm -f CMakeCache.txt 
cmake -GNinja -DCOMPILE_TARGET=${COMPILE_TARGET} -DCMAKE_BUILD_TYPE=Release -DCCF_DEVEL=OFF .. 
cmake -L .. 2>/dev/null | grep CMAKE_INSTALL_PREFIX: | cut -d = -f 2 > /tmp/install_prefix 
cpack -V -G RPM 
INITIAL_PKG=$(ls *.rpm | grep -v devel) 
FINAL_PKG=${INITIAL_PKG//\~/_} 
if [ "$INITIAL_PKG" != "$FINAL_PKG" ]; then mv "$INITIAL_PKG" "$FINAL_PKG"; fi
sha256sum $FINAL_PKG > /rpm_run_digest.txt



(
find . -name "libjs_generic.*.so" -print0 | xargs -0 --no-run-if-empty  sha256sum && \
find . -name "libjs_generic.*.so" -print0 | xargs -0 --no-run-if-empty  ls -l && \
find . -name "*.a" -print0 | xargs -0 --no-run-if-empty  sha256sum  && \
find . -name "*.a" -print0 | xargs -0 --no-run-if-empty  ls -l && \
find . -name "*.rpm" -print0 | xargs -0 --no-run-if-empty  sha256sum  && \
find . -name "*.rpm" -print0 | xargs -0 --no-run-if-empty  ls -l && \
find . -name cchost -print0 | xargs -0 --no-run-if-empty  sha256sum  && \
find . -name cchost -print0 | xargs -0 --no-run-if-empty  ls -l
)  | tee /components_digest.txt


# Install package
# tdnf -y install ./*.rpm
