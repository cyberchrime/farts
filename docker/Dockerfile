FROM ubuntu:20.04

ARG INSTALL_FILE="Xilinx_Unified_2022.1_0420_0327.tar.gz"


# install common packages for building yocto BSPs
ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 \
    && apt-get update && apt-get -y install \
    apt-utils \
    gawk \
    wget \
    git \
    diffstat \
    unzip \
    texinfo \
    build-essential \
    chrpath \
    socat \
    cpio \
    python \
    python3 \
    python3-pip \
    python3-pexpect \
    xz-utils \
    debianutils \
    net-tools \
    iputils-ping \
    tar \
    locales \
    sudo \
    nano \
    vim \
    bc \
    rsync \
    tmux \
    libncurses5-dev \
    parted \
    dosfstools \
    mtools \
    zstd \
    lz4 \
    file \
    libtinfo5 \
    tree \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libfreetype6 \
    openjdk-17-jre \
    gcc-multilib \
    libc6-dev:i386 \
    ocl-icd-opencl-dev \
    libjpeg62-dev \
    libstdc++6:i386 \
    libgtk2.0-0:i386 \
    dpkg-dev:i386 \
    python3-pip \
    libtinfo5 \
    libncurses5 \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxrandr2 \
    libfontconfig \
    libfreetype6 \
    libgtk3.0 \
    ca-certificates curl sudo xorg dbus dbus-x11 ubuntu-gnome-default-settings gtk2-engines \
    ttf-ubuntu-font-family fonts-ubuntu-font-family-console fonts-droid-fallback lxappearance \
    && rm -rf /var/lib/apt/lists/*

# generate locales (required by bitbake's python scripts)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# add group for sniffer user
RUN groupadd -g 1000 sniffer

# add sniffer user (without password)
RUN useradd -rm -d /home/sniffer -s /bin/bash -g 1000 -G sudo,staff -u 1000 sniffer

# do not require password on sudo for users in the sudo group
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# make /opt writable for user 'sniffer'
RUN chgrp staff /opt && chmod g+w /opt 

# TODO: add repo

# switch to sniffer user and home dir as workdir
ADD --chown=1000:1000 $INSTALL_FILE /vivado-installer
COPY --chown=1000:1000 install_config.txt /vivado-installer/

USER sniffer
WORKDIR /home/sniffer

RUN /vivado-installer/Xilinx_Unified_2022.1_0420_0327/xsetup \
       --agree XilinxEULA,3rdPartyEULA \
       --batch Install \
       --config /vivado-installer/install_config.txt


SHELL ["/bin/bash", "-c"]

# create entrypoint
USER root

RUN echo 'source /opt/Xilinx/Vivado/2022.1/settings64.sh' >> /etc/bash.bashrc && \
    rm -rf /vivado-installer

COPY entrypoint.sh /bin
ENTRYPOINT ["/bin/entrypoint.sh"]

USER sniffer
