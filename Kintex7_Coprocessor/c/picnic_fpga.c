#include "picnic_fpga.h"
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>

static unsigned char LDPRIVKEY[16] = "\x60\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char KEY_HEAD_L1[16] = "\xc3\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char KEY_HEAD_L5[16] = "\xc3\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char PUB_HEAD_L1[16] = "\xa0\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char PUB_HEAD_L5[16] = "\xa0\x00\x00\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char SIGN[16] = "\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char VERIFY[16] = "\x30\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char MSG_HEAD[16] = "\x23\x00\x00\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char MSG_HEAD_VER[16] = "\x20\x00\x00\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char SUCCESS[16] = "\xE0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
static unsigned char FAILURE[16] = "\xF0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

static int pdi_fd = -1;
static int pdo_fd = -1;
static int sdi_fd = -1;

static int check_open()
{
  return (pdi_fd == -1) && (pdo_fd == -1) && (sdi_fd == -1);
}

static void reset_fd()
{
  pdi_fd = -1;
  pdo_fd = -1;
  sdi_fd = -1;
}

static inline int readFPGA(int fd, unsigned char* buf, size_t size)
{
  size_t already_read = 0;
  size_t offset = 0;

  while(already_read != size)
  {
    size_t to_read = size - already_read;

    // if (offset)
    // {
    //   ssize_t off = lseek(fd, offset, SEEK_SET);
    //   if ((size_t)off != offset)
    //     return OFFSET_ERROR;
    // }

    ssize_t rc = read(fd, buf, to_read);
    if (rc < 0)
      return READ_ERROR;

    buf += rc;
    already_read += rc;
    offset += rc;
  }
  return NO_ERROR;
}

static inline int writeFPGA(int fd, unsigned char* buf, size_t size)
{
  size_t already_written = 0;
  size_t offset = 0;

  while(already_written != size)
  {
    size_t to_write = size - already_written;

    // if (offset)
    // {
    //   ssize_t off = lseek(fd, offset, SEEK_SET);
    //   if ((size_t)off != offset)
    //     return OFFSET_ERROR;
    // }

    ssize_t rc = write(fd, buf, to_write);
    if (rc < 0)
      return WRITE_ERROR;

    buf += rc;
    already_written += rc;
    offset += rc;
  }
  return NO_ERROR;
}

int init_picnic_fpga_mapname(char* pdi, char* pdo, char* sdi)
{
  if (!check_open())
    return ERR_ALREADY_OPEN;

  pdi_fd = open(pdi, O_RDWR);
  pdo_fd = open(pdo, O_RDWR);
  sdi_fd = open(sdi, O_RDWR);
  if (pdi_fd < 0 || pdo_fd < 0 || sdi_fd < 0)
  {
    release_picnic_fpga();
    return ERR_OPEN_FAILED;
  }

  return NO_ERROR;
}

int init_picnic_fpga_verify_mapname(char* pdi, char* pdo)
{
  if (!check_open())
    return ERR_ALREADY_OPEN;

  pdi_fd = open(pdi, O_RDWR);
  pdo_fd = open(pdo, O_RDWR);
  if (pdi_fd < 0 || pdo_fd < 0)
  {
    release_picnic_fpga();
    return ERR_OPEN_FAILED;
  }

  return NO_ERROR;
}

int init_picnic_fpga()
{
  return init_picnic_fpga_mapname(PDI_FILE, PDO_FILE, SDI_FILE);
}

int init_picnic_fpga_verify()
{
  return init_picnic_fpga_verify_mapname(PDI_FILE, PDO_FILE);
}

void release_picnic_fpga()
{
  if (pdi_fd >= 0)
    close(pdi_fd);
  if (pdo_fd >= 0)
    close(pdo_fd);
  if (sdi_fd >= 0)
    close(sdi_fd);
  reset_fd();
}

static inline int setKey(unsigned char* key, size_t size, unsigned char* head)
{
  ssize_t rc = write(pdi_fd, LDPRIVKEY, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(sdi_fd, head, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(sdi_fd, key, size);
  if (rc != (ssize_t)size)
    return WRITE_ERROR;
  return NO_ERROR;
}

int picnic_fpga_set_key(unsigned char* key, int version)
{
  if (version == L1)
  {
    return setKey(key, 16, KEY_HEAD_L1);
  }
  else if (version == L5)
  {
    return setKey(key, 32, KEY_HEAD_L5);
  }

  return UNKNOWN_VERSION;
}

static inline int setPub(unsigned char* pub_plain, unsigned char* pub_ciph, size_t size, unsigned char* head)
{
  ssize_t rc = write(pdi_fd, head, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, pub_ciph, size);
  if (rc != (ssize_t)size)
    return WRITE_ERROR;

  rc = write(pdi_fd, pub_plain, size);
  if (rc != (ssize_t)size)
    return WRITE_ERROR;

  return NO_ERROR;
}

int picnic_fpga_set_pub(unsigned char* pub_plain, unsigned char* pub_ciph, int version)
{
  if (version == L1)
  {
    return setPub(pub_plain, pub_ciph, 16, PUB_HEAD_L1);
  }
  else if (version == L5)
  {
    return setPub(pub_plain, pub_ciph, 32, PUB_HEAD_L5);
  }

  return UNKNOWN_VERSION;
}

static inline int sign_l1(unsigned char* msg, unsigned char* sig, size_t* sig_length)
{
  ssize_t rc = write(pdi_fd, SIGN, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, MSG_HEAD, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, msg, MSG_LEN);
  if (rc != MSG_LEN)
    return WRITE_ERROR;

  unsigned char tmp[16];
  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  size_t len = (tmp[2] << 8) | tmp[3];

  rc = readFPGA(pdo_fd, sig, len);
  if (rc == READ_ERROR)
    return READ_ERROR;

  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  if (memcmp(tmp, SUCCESS, 16) != 0)
    return OTHER_ERROR;

  *sig_length = len;
  return NO_ERROR;
}

static inline int sign_l5(unsigned char* msg, unsigned char* sig, size_t* sig_length)
{
  ssize_t rc = write(pdi_fd, SIGN, 16);

  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, MSG_HEAD, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, msg, MSG_LEN);
  if (rc != MSG_LEN)
    return WRITE_ERROR;


  unsigned char fin = 0;
  size_t read_len = 0;
  size_t len = 0;
  unsigned char tmp[16];

  int runs = 0;
  do
  {
    rc = read(pdo_fd, tmp, 16);
    if (rc != 16)
      return READ_ERROR;

    len = (tmp[2] << 8) | tmp[3];
    fin = (tmp[0] & 3);

    if (fin == 3)
    {
      rc = readFPGA(pdo_fd, sig + read_len, len + 8);
      if (rc == READ_ERROR)
        return READ_ERROR;

    }
    else
    {
      rc = readFPGA(pdo_fd, sig + read_len, len);
      if (rc == READ_ERROR)
        return READ_ERROR;
    }

    read_len += len;

    runs++;
    if (runs >= 3)
      return READ_ERROR;;

  } while (fin != 3);

  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  if (memcmp(tmp, SUCCESS, 16) != 0)
    return OTHER_ERROR;

  *sig_length = read_len;
  return NO_ERROR;
}

int picnic_fpga_sign(unsigned char* msg, unsigned char* sig, size_t* sig_length, int version)
{
  if (version == L1)
  {
    return sign_l1(msg, sig, sig_length);
  }
  else if (version == L5)
  {
    return sign_l5(msg, sig, sig_length);
  }

  return UNKNOWN_VERSION;
}

static inline int verify_l5(unsigned char* msg, unsigned char* sig, size_t sig_length)
{
  ssize_t rc = write(pdi_fd, VERIFY, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, MSG_HEAD_VER, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, msg, MSG_LEN);
  if (rc != MSG_LEN)
    return WRITE_ERROR;

  unsigned char sig_head[16] = "\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

  size_t cur_len = 0;
  size_t to_send = sig_length;
  size_t offset = 0;

  while(to_send)
  {
    if (to_send > L5_BYTES_PER_SEG)
    {
      cur_len = L5_BYTES_PER_SEG;
      to_send -= L5_BYTES_PER_SEG;
      sig_head[0] = 0x40;
    }
    else
    {
      cur_len = to_send;
      to_send = 0;
      sig_head[0] = 0x43; // set fin bits
    }
    sig_head[2] = (cur_len >> 8) & 0xFF;
    sig_head[3] = cur_len & 0xFF;

    rc = write(pdi_fd, sig_head, 16);
    if (rc != 16)
      return WRITE_ERROR;

    rc = writeFPGA(pdi_fd, (sig + offset), cur_len);
    if (rc == WRITE_ERROR)
      return WRITE_ERROR;

    offset += cur_len;
  }

  unsigned char tmp[16];
  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  unsigned char r_msg[MSG_LEN];
  rc = read(pdo_fd, r_msg, MSG_LEN);
  if (rc != MSG_LEN)
    return READ_ERROR;

  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  // if (memcmp(msg, r_msg, MSG_LEN) != 0)
  //   return OTHER_ERROR;

  if (memcmp(tmp, SUCCESS, 16) == 0)
    return SIG_VERIFIED;

  if (memcmp(tmp, FAILURE, 16) == 0)
    return SIG_FALSE;

  return OTHER_ERROR;
}

static inline int verify_l1(unsigned char* msg, unsigned char* sig, size_t sig_length)
{
  ssize_t rc = write(pdi_fd, VERIFY, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, MSG_HEAD_VER, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = write(pdi_fd, msg, MSG_LEN);
  if (rc != MSG_LEN)
    return WRITE_ERROR;

  unsigned char sig_head[16] = "\x43\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
  sig_head[2] = (sig_length >> 8) & 0xFF;
  sig_head[3] = sig_length & 0xFF;

  rc = write(pdi_fd, sig_head, 16);
  if (rc != 16)
    return WRITE_ERROR;

  rc = writeFPGA(pdi_fd, sig, sig_length);
  if (rc == WRITE_ERROR)
    return WRITE_ERROR;

  unsigned char tmp[16];
  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  unsigned char r_msg[MSG_LEN];
  rc = read(pdo_fd, r_msg, MSG_LEN);
  if (rc != MSG_LEN)
    return READ_ERROR;

  rc = read(pdo_fd, tmp, 16);
  if (rc != 16)
    return READ_ERROR;

  // if (memcmp(msg, r_msg, MSG_LEN) != 0)
  //   return OTHER_ERROR;

  if (memcmp(tmp, SUCCESS, 16) == 0)
    return SIG_VERIFIED;

  if (memcmp(tmp, FAILURE, 16) == 0)
    return SIG_FALSE;

  return OTHER_ERROR;
}

int picnic_fpga_verify(unsigned char* msg, unsigned char* sig, size_t sig_length, int version)
{
  if (version == L1)
  {
    return verify_l1(msg, sig, sig_length);
  }
  else if (version == L5)
  {
    return verify_l5(msg, sig, sig_length);
  }

  return UNKNOWN_VERSION;
}

unsigned char* alloc_resource(size_t size)
{
  unsigned char* mem;
  if (posix_memalign((void**)&mem, 4096, size + 4096))
    return NULL;
  return mem;
}
