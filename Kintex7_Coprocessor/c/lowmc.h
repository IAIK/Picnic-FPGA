#include <unistd.h>

#define PLAINFILE "/dev/xdma0_h2c_0"
#define CIPHERFILE "/dev/xdma0_c2h_0"
#define KEYFILE "/dev/xdma0_user"

#define BLOCK_BYTE 16
#define KEY_BYTE 16
#define BLOCKSIZE ((BLOCK_BYTE) * 8)
#define KEYSIZE ((KEY_BYTE) * 8)

#define ERR_ALREADY_OPEN -1
#define ERR_OPEN_FAILED -2
#define WRITE_ERROR -3
#define READ_ERROR -4
#define MEMORY_ERROR -5
#define PTHREAD_CREATE_ERROR -6
#define OFFSET_ERROR -7
#define NO_ERROR 0

int init_lowmc_mapname(char* plain, char* cipher, char* key);

int init_lowmc();

void release_lowmc();

int set_key(unsigned char* key);

int encrypt(unsigned char* plain, unsigned char* cipher, size_t num_plains);

unsigned char* alloc_key();

unsigned char* alloc_plain(size_t num_plains);

unsigned char* alloc_cipher(size_t num_ciphers);
