// aes_ref_dpi.c: Wrapper DPI-C do modelo aes/model/aes.c (bytes na ordem FIPS-197)
#include "aes.h"

int aes_ref_crypt(int decrypt, int key_len, const unsigned char *key,
                  const unsigned char *data_in, unsigned char *data_out) {
  if (key_len != 16 && key_len != 24 && key_len != 32) {
    return -1;
  }
  if (decrypt) {
    return aes_decrypt_block(data_in, key, key_len, data_out);
  }
  return aes_encrypt_block(data_in, key, key_len, data_out);
}
