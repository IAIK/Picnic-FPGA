#include "lowmc.h"
#include <stdlib.h>
#include <fcntl.h>
#include <pthread.h>

static int plain_fd = -1;
static int cipher_fd = -1;
static int key_fd = -1;

#define RW_MAX_SIZE 1000000

typedef struct
{
  unsigned char* cipher;
  size_t num_ciphers;
} Args;

static void* get_cipher(void* arg)
{
  size_t size = ((Args*) arg)->num_ciphers * BLOCK_BYTE;
  unsigned char* buf = ((Args*) arg)->cipher;
  size_t already_read = 0;
  size_t offset = 0;

  while(already_read != size)
  {
    size_t to_read = size - already_read;
    if (to_read > RW_MAX_SIZE)
      to_read = RW_MAX_SIZE;

    if (offset)
    {
      ssize_t off = lseek(cipher_fd, offset, SEEK_SET);
      if (off != offset)
        return (void*) OFFSET_ERROR;
    }

    ssize_t rc = read(cipher_fd, buf, to_read);
    if (rc < 0)
      return (void*) READ_ERROR;

    buf += rc;
    already_read += rc;
    offset += rc;
  }

  return (void*)NO_ERROR;
}

static int check_open()
{
  return (plain_fd == -1) && (cipher_fd == -1) && (key_fd == -1);
}

static void reset_fd()
{
  plain_fd = -1;
  cipher_fd = -1;
  key_fd = -1;
}

int init_lowmc_mapname(char* plain, char* cipher, char* key)
{
  if (!check_open())
    return ERR_ALREADY_OPEN;

  plain_fd = open(plain, O_RDWR);
  cipher_fd = open(cipher, O_RDWR | O_NONBLOCK);
  key_fd = open(key, O_RDWR | O_SYNC);
  if (plain_fd < 0 || cipher_fd < 0 || key_fd < 0)
  {
    release_lowmc();
    return ERR_OPEN_FAILED;
  }

  return NO_ERROR;
}

int init_lowmc()
{
  return init_lowmc_mapname(PLAINFILE, CIPHERFILE, KEYFILE);
}

void release_lowmc()
{
  if (plain_fd >= 0)
    close(plain_fd);
  if (cipher_fd >= 0)
    close(cipher_fd);
  if (key_fd >= 0)
    close(key_fd);
  reset_fd();
}

int set_key(unsigned char* key)
{
  for (size_t i = 0; i < 4; i++)
  {
    ssize_t rc = write(key_fd, key + i * 4, 4);
    if (rc != 4)
      return WRITE_ERROR;
  }
  return NO_ERROR;
}

int encrypt(unsigned char* plain, unsigned char* cipher, size_t num_plains)
{
  // Start reading thread
  pthread_t tid;
  Args args;
  args.cipher = cipher;
  args.num_ciphers = num_plains;
  int res = pthread_create(&tid, NULL, get_cipher, (void*)&args);
  if (res)
    return PTHREAD_CREATE_ERROR;

  // write plains
  ssize_t size = num_plains * BLOCK_BYTE;
  unsigned char* buf = plain;
  size_t already_written = 0;
  size_t offset = 0;
  while(already_written != size)
  {
    size_t to_write = size - already_written;
    if (to_write > RW_MAX_SIZE)
      to_write = RW_MAX_SIZE;

    if (offset)
    {
      ssize_t off = lseek(plain_fd, offset, SEEK_SET);
      if (off != offset)
        return OFFSET_ERROR;
    }

    ssize_t rc = write(plain_fd, buf, to_write);
    if (rc != to_write)
      return WRITE_ERROR;

    buf += rc;
    already_written += rc;
    offset += rc;
  }

  // wait for thread
  void* result;
  pthread_join(tid, &result);
  return (ssize_t)result;
}

unsigned char* alloc_key()
{
  unsigned char* mem;
  if (posix_memalign((void**)&mem, 4096, KEY_BYTE + 4096))
    return NULL;
  return mem;
}

unsigned char* alloc_plain(size_t num_plains)
{
  unsigned char* mem;
  if (posix_memalign((void**)&mem, 4096, num_plains * BLOCK_BYTE + 4096))
    return NULL;
  return mem;
}

unsigned char* alloc_cipher(size_t num_ciphers)
{
  unsigned char* mem;
  if (posix_memalign((void**)&mem, 4096, num_ciphers * BLOCK_BYTE + 4096))
    return NULL;
  return mem;
}
