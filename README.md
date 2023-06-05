# FARTS is A Real Time Sniffer (FaRTS)


## About

FARTS, a recursive acronym for *FARTS is A Real-Time Sniffer*, is a 
Ethernet sniffer dedicated for real time (RT) applications like EtherCAT.
It can simply be plugged in between two (RT) Ethernet devices
to monitor all traffic transferred in between them, while introducing
a very constant delay of only 1μs.

On EtherCAT, it was successfully tested with a cycle time of 100μs.

The used hardware is comprised by a Digilent/Avnet ZedBoard,
which was extended by a Avnet AES-FMC-NETW1-G Network Expansion board.

All software and gateware sources are publicly available and can
be used by anyone under the GPLv3 license. Please also note the
licenses of the subprojects.


## Requirements

- PC running a Linux based OS (other OSes are untested)
- Podman or Docker
- Vivado 2022.1 (newer versions may work, but are untested)
- Digilent/Avnet ZedBoard 
- Avnet AES-FMC-NETW1-G Network Expansion board


## Structure

```
├── docker : Code to setup a docker container
├── fpga : FPGA related code
└── sw : Software
```


## Setup

First, install Vivado from
from https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2022-1.html
This guide assumes it is installed to `/opt`.

First, setup the repository:

```
git clone --recurse-submodules https://github.com/cyberchrime/farts.git
cd farts
```

Afterwards, setup the container. For `Podman`, use

```
podman build -t sniffer docker
podman run -ti --userns=keep-id -v=/opt/Xilinx:/opt/Xilinx:Z -v=.:/home/sniffer/ws:Z --rm sniffer:latest
```

When using docker, use these commands instead:

```
docker build -t sniffer docker
docker run -ti -v=/opt/Xilinx:/opt/Xilinx -v=${PWD}:/home/sniffer/ws--rm sniffer:latest
```

## Build

Once you entered the shell inside the container,
you can build it with make (without parallelisation). No need to use
`-j`, as all executed commands (Vivado and BitBake) already make heavy use
of parallelisation. Execute

```
LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1 make

```

If you'd like to use Vivado with a GUI, run `xhost +` on your host machine.


## Install

The build results are contained in `sw/build/tmp-glibc/deploy/images/zedboard-zynq7/

Prepare a SD-Card by formatting it as follows:

- At the beginning, 4MB of free space
- Then FAT32 formatted first partition (500MB) named BOOT
- remaining space ext4 formatted and named RootFS

Finally, mount the SD card and run the following commands to install the software:

```
mkdir -p /<mnt-path>/BOOT/boot/extlinux
cp boot.bin /<mnt-path>/BOOT/
cp extlinux.conf /<mnt-path>/BOOT/boot/extlinux/
cp system.dtb /<mnt-path>/BOOT/boot
cp zImage /<mnt-path>/BOOT/boot
tar xf core-image-minimal-zedboard-zynq7.tar.gz -C /<mnt-path>/RootFS
```


