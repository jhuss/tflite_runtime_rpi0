# based on https://github.com/lukechilds/dockerpi


### Build stage for qemu-system-arm

FROM debian:stable-slim AS qemu-builder
ARG QEMU_VERSION=6.1.0
ENV QEMU_TARBALL="qemu-${QEMU_VERSION}.tar.xz"
WORKDIR /qemu

# Install packages
RUN apt-get update
RUN apt-get -y install pkg-config wget gpg

# Pull source
RUN wget "https://download.qemu.org/${QEMU_TARBALL}"

# Verify signatures
RUN wget "https://download.qemu.org/${QEMU_TARBALL}.sig"
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys CEACC9E15534EBABB82D3FA03353C9CEF108B584
RUN gpg --verify "${QEMU_TARBALL}.sig" "${QEMU_TARBALL}"

# Build source
RUN tar xvf "${QEMU_TARBALL}"
# These seem to be the only deps actually required for a successful build
RUN apt-get -y install python build-essential libglib2.0-dev libpixman-1-dev ninja-build
# These don't seem to be required but are specified here: https://wiki.qemu.org/Hosts/Linux
RUN apt-get -y install libfdt-dev zlib1g-dev
# Not required or specified anywhere but supress build warnings
RUN apt-get -y install flex bison
RUN "qemu-${QEMU_VERSION}/configure" --static --target-list=arm-softmmu,aarch64-softmmu
RUN make -j$(nproc)
RUN strip "arm-softmmu/qemu-system-arm" "aarch64-softmmu/qemu-system-aarch64" "qemu-img"


#### Build stage for fatcat

FROM debian:stable-slim AS fatcat-builder
ARG FATCAT_VERSION=v1.1.1
ARG FATCAT_CHECKSUM="5574f715f62a9feda7fffc8099f8bca7134ff4f1274bb1bc0db96a2969eea206"
ENV FATCAT_TARBALL="${FATCAT_VERSION}.tar.gz"
WORKDIR /fatcat

# Update package lists
RUN apt-get update

# Pull source
RUN apt-get -y install build-essential cmake wget
RUN wget "https://github.com/Gregwar/fatcat/archive/${FATCAT_TARBALL}"
RUN echo "${FATCAT_CHECKSUM}  ${FATCAT_TARBALL}" | sha256sum -c

# Extract source tarball
RUN tar xvf "${FATCAT_TARBALL}"

# Build source
RUN cmake fatcat-* -DCMAKE_CXX_FLAGS='-static'
RUN make -j$(nproc)


### Build the dockerpi VM

FROM busybox:1.34 AS dockerpi-vm

ARG FILESYSTEM_IMAGE_URL="http://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-11-08/2021-10-30-raspios-bullseye-armhf-lite.zip"
ARG FILESYSTEM_IMAGE_CHECKSUM="008d7377b8c8b853a6663448a3f7688ba98e2805949127a1d9e8859ff96ee1a9"

COPY --from=qemu-builder /qemu/arm-softmmu/qemu-system-arm /usr/local/bin/qemu-system-arm
COPY --from=qemu-builder /qemu/aarch64-softmmu/qemu-system-aarch64 /usr/local/bin/qemu-system-aarch64
COPY --from=qemu-builder /qemu/qemu-img /usr/local/bin/qemu-img
COPY --from=fatcat-builder /fatcat/fatcat /usr/local/bin/fatcat

# Pull OS image
ADD $FILESYSTEM_IMAGE_URL /filesystem.zip
RUN echo "$FILESYSTEM_IMAGE_CHECKSUM  /filesystem.zip" | sha256sum -c

# Expand OS image
ARG GIB_IN_BYTES="1073741824"
ARG IMAGE_PATH="/filesystem.img"
ARG FAT_PATH="/fat.img"
ARG FAT_FOLDER="/fat"

RUN unzip /filesystem.zip
RUN mv -- /*.img ${IMAGE_PATH}
RUN rm /filesystem.zip
RUN image_size_in_bytes=$(qemu-img info --output json ${IMAGE_PATH} | grep "virtual-size" | awk '{print $2}' | sed 's/,//') && \
    new_size_in_gib=$((($image_size_in_bytes / ($GIB_IN_BYTES * 8) + 1) * 8)) && \
    echo "Rounding image size up to ${new_size_in_gib}GiB so it's a multiple of 2GiB..." && \
    qemu-img resize ${IMAGE_PATH} "${new_size_in_gib}G"

# Extracting boot filesystem
RUN fdisk -l ${IMAGE_PATH} | awk "/^[^ ]*1/{print \"dd if=${IMAGE_PATH} of=${FAT_PATH} bs=512 skip=\"\$4\" count=\"\$6}" | sh
RUN mkdir -p "${FAT_FOLDER}"
RUN fatcat -x "${FAT_FOLDER}" "${FAT_PATH}"

ADD ./bootvm.sh /bootvm.sh
