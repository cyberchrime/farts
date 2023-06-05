# Tasks

## Timestamps to Gray Code

Timestamps should be gray coded for clock domain crossing (CDC)


## Switch from libpcap to PCAP Next Generation

Reference: https://www.ietf.org/staging/draft-tuexen-opsawg-pcapng-02.html

**Subtasks**

Enhanced Packet Block
- Different timestamp format: High and low instead of sec and nsec
- `epb_dropcount`
- `epb_flags`: symbol_error


User Space Tool
- Section Header: Type Interface
    - Section length = specified
- Interface Description 1
- Interface Description 2
- Section Block: Type Enhanced Packet Block
    - Section length = -1
Section Block von User Space Programm


Block Total Length: 
    - static header length: 32B
    - variable Packet length, padded to 4B
    - dropcount only when not 0, 8B
    - error flags only when error occured, 4B
Prepend: static Interface ID


Two Interface Blocks or a single one?
