# Structure

```
sw
├── build: build configs and files
│   ├── conf: local configs
└── sources : Layers
    ├── meta-openembedded: external lib
    ├── meta-sniffer: sniffer-specific files
    ├── meta-xilinx: external lib
    ├── meta-xilinx-tools: external lib
    └── poky: external lib
```


# Development

To start software development, `source` the file `setupsdk` as follows:

```
$ source setupsdk
```

Afterwards, you may find the following commands useful:

- `bitbake core-image-minimal`: build the whole image
- `bitbake -c menuconfig virtual/kernel`: configure the Linux kernel
- `bitbake -c devshell sniffer-module`: start a development shell for the kernel module
- `bitbake -c clean sniffer-module`: delete the kernel module from the workspace
- `bitbake sniffer-module`: build the kernel module
