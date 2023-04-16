# FaRTS is a Real Time Sniffer (FaRTS)

## Structure

```
├── docker : Code to setup a docker container
├── fpga : FPGA related code
└── sw : Software
```

## Possible Setup

Two possibilities are provided to build the sniffer distribution:
One approach running on a native Linux OS, the other one
inside a Docker container.

Note: There is an issue with Vivado running in Docker environments, requiring
to preload a udev library. That means, when building the FPGA implementation,
precede the command with `LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1`. See the 
following link for more details:
https://support.xilinx.com/s/question/0D54U00005Sgst2SAB/failed-batch-mode-execution-in-linux-docker-running-under-windows-host?language=en_US

Please note: Vivado 2022.1 is huge. The archive (~75GB) must be downloaded to your host.
Afterwards, it is copied into the docker context (another 75GB), before it is unpacked
in the docker context (estimated: another 75GB). The installation itself probably takes
50GB, so installing Vivado in a docker container temporarily requires a total 
disk space of 3*75+50 = 275GB.

## Native OS toolchain

Using a native Linux (tested: Ubuntu 20.04 LTS) host is the 
recommended approach for building as it requires less disk space.

1. Download and install Vivado 2022.1 from https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2022-1.html
2. Setup Yocto as described in https://docs.yoctoproject.org/3.4.4/singleindex.html
3. Source Xilinx' settings64.sh
4. Start building with `make`

## Docker toolchain

Alternatively, you may use the toolchain with docker.
Please not that a archive file of Vivado 2022.1 must be download
prior to installation so that it can be installed in the
docker image. Make sure to have at least 300 GB of free space
on your disk (see the note above). Installation may take some
time (2 hours), depending on your machine configuration.

1. Download the Xilinx Unified Installer 2022.1 SFD 
   from https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2022-1.html
2. Place the downloaded tar.gz archive in the `docker` directory

Then execute the following commands:

```
cd docker
docker build -t sniffer .
docker compose create 
docker start docker-Sniffing-Sniffer-1
docker attach docker-Sniffing-Sniffer-1
```

Once you entered the shell inside the container,
you can build it with make (without parallelisation). No need to use,
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


