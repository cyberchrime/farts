#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>

typedef struct pcap_hdr_s {
  uint32_t magic_number;   /* magic number */
  uint16_t version_major;  /* major version number */
  uint16_t version_minor;  /* minor version number */
  int32_t  thiszone;       /* GMT to local correction */
  uint32_t sigfigs;        /* accuracy of timestamps */
  uint32_t snaplen;        /* max length of captured packets, in octets */
  uint32_t network;        /* data link type */
} pcap_hdr_t;

int main() {
	pcap_hdr_t hdr = {0xa1b23c4d, 2, 4, -3600, 0, 2048, 1};
	int fd = 1;


	write(fd, &hdr, sizeof(hdr));
}
