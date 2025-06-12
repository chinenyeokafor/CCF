FROM mcr.microsoft.com/azurelinux/base/core:3.0@sha256:91d58fce1e27dd0b711e569fdc173cfb0aec950ff399ea567723936d785388ba

COPY ./scripts/build_release.sh build_release.sh
RUN chmod +x build_release.sh && \
    ./build_release.sh
