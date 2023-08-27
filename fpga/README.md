# FPGA Development

## Structure

```
fpga
├── common
├── fpga: files required for 
├── ip: build directory
├── lib: external libraries (as submodules)
├── rtl: RTL implementation
├── syn: synthesis scripts
└── tb: testbenches
```

## Build

The FPGA implementation can be built with a simple

```
$ make
```

Note: When running in a Podman/Docker container, run instead

```
$ LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1 make
``
