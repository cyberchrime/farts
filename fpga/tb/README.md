# Testbenches

## Prerequisites

To run the testbenches, a functional installation of
Icarus Verilog and Python3 with pip is required.

## Setup

```
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run a simulation

To run a simulation, `cd` into the module's directory and run

```
make
```

To print a waveform for gtkwave, run

```
make WAVES=1
```
