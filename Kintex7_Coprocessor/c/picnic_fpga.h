#pragma once

#include <unistd.h>

#define PDI_FILE "/dev/xdma0_h2c_0"
#define PDO_FILE "/dev/xdma0_c2h_0"
#define SDI_FILE "/dev/xdma0_h2c_1"

#define L1 42
#define L5 43

#define MSG_LEN 64
#define L1_SIG_LEN 34000
#define L5_SIG_LEN 132824
#define L5_BYTES_PER_SEG 65520

#define ERR_ALREADY_OPEN -1
#define ERR_OPEN_FAILED -2
#define WRITE_ERROR -3
#define READ_ERROR -4
#define UNKNOWN_VERSION -5
#define MEMORY_ERROR -6
#define NO_ERROR 0
#define OTHER_ERROR -7
#define OFFSET_ERROR -8
#define SIG_VERIFIED 1
#define SIG_FALSE 0

int init_picnic_fpga_mapname(char* pdi, char* pdo, char* sdi);

int init_picnic_fpga();

int init_picnic_fpga_verify_mapname(char* pdi, char* pdo);

int init_picnic_fpga_verify();

void release_picnic_fpga();

int picnic_fpga_set_key(unsigned char* key, int version);

int picnic_fpga_set_pub(unsigned char* pub_plain, unsigned char* pub_ciph, int version);

int picnic_fpga_sign(unsigned char* msg, unsigned char* sig, size_t* sig_length, int version);

int picnic_fpga_verify(unsigned char* msg, unsigned char* sig, size_t sig_length, int version);

unsigned char* alloc_resource(size_t size);
