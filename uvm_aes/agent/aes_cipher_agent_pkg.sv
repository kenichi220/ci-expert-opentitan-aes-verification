// junta tudo do agents, converte bytes para vector 
// no geral isso aqui é um monte de função de conversão
package aes_cipher_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import aes_pkg::*;
  // aes_cmd_e all number
  // Driver coloca esses valores
  // só pra ficar mais fácil de ler no log daria para pegar tudo da interface
  // 
  typedef enum {
    CMD_CRYPT,
    CMD_DEC_KEY_GEN,
    CMD_DATA_OUT_CLEAR,
    CMD_CLEAR_ALL
  } aes_cmd_e;
  // para gerar erros de proposito
  typedef enum {
    ERR_NONE,
    ERR_IN_VALID, //sp2v com valor errado
    ERR_CRYPT, 
    ERR_DEC_KEY_GEN,
    ERR_OUT_READY,
    ERR_NO_CMD // sem comando
  } aes_err_e;

  typedef logic [3:0][3:0][7:0] aes_state_t;    // state[linha][coluna]
  typedef logic     [7:0][31:0] aes_key_t;      // key[palavra], ate 256 bits
  typedef byte unsigned         aes_block_t[16];// bloco como no FIPS-197
  typedef byte unsigned         aes_key_bytes_t[32];

  // Estado: byte FIPS b[n] -> state[n%4][n/4].
  // Chave: k[n] -> key[n/4][8*(n%4)+:8]
  // n/4 qual palavra
  // n%4 qual byte
  // 8 * (n%4) bit inicial do byte
  // +:8 pegue 8 bits a frente
  function automatic aes_state_t bytes_to_state(aes_block_t b);
    aes_state_t s;
    for (int c = 0; c < 4; c++)
      for (int r = 0; r < 4; r++)
        s[r][c] = b[r + 4*c];
    return s;
  endfunction

  function automatic aes_block_t state_to_bytes(aes_state_t s);
    aes_block_t b;
    for (int c = 0; c < 4; c++)
      for (int r = 0; r < 4; r++)
        b[r + 4*c] = s[r][c];
    return b;
  endfunction
  // key em little endian
  function automatic aes_key_t bytes_to_key(aes_key_bytes_t k);
    aes_key_t key;
    for (int n = 0; n < 32; n++)
      key[n/4][8*(n%4) +: 8] = k[n];
    return key;
  endfunction

  function automatic aes_key_bytes_t key_to_bytes(aes_key_t key);
    aes_key_bytes_t k;
    for (int n = 0; n < 32; n++)
      k[n] = key[n/4][8*(n%4) +: 8];
    return k;
  endfunction

  function automatic int key_len_bytes(key_len_e kl);
    case (kl)
      AES_128: return 16;
      AES_192: return 24;
      default: return 32;
    endcase
  endfunction

  function automatic string state_to_hex(aes_state_t s);
    aes_block_t b = state_to_bytes(s);
    string str = "";
    foreach (b[i]) str = {str, $sformatf("%02x", b[i])};
    return str;
  endfunction

  function automatic string key_to_hex(aes_key_t key, key_len_e kl);
    aes_key_bytes_t k = key_to_bytes(key);
    string str = "";
    for (int n = 0; n < key_len_bytes(kl); n++) str = {str, $sformatf("%02x", k[n])};
    return str;
  endfunction

  function automatic aes_state_t hex_to_state(string h);
    aes_block_t b;
    if (h.len() != 32) `uvm_fatal("HEX", $sformatf("hex_to_state: 32 char, do: %0d", h.len()))
    foreach (b[i]) b[i] = h.substr(2*i, 2*i+1).atohex();
    return bytes_to_state(b);
  endfunction

  function automatic aes_key_t hex_to_key(string h);
    aes_key_bytes_t k = '{default: 0};
    if (!(h.len() inside {32, 48, 64}))
      `uvm_fatal("HEX", $sformatf("hex_to_key: 32/48/64 char, do: %0d", h.len()))
    for (int n = 0; n < h.len()/2; n++) k[n] = h.substr(2*n, 2*n+1).atohex();
    return bytes_to_key(k);
  endfunction

  // Ordem: quem eh usado antes de quem usa
  `include "aes_cipher_item.sv"
  `include "aes_cipher_agent_cfg.sv"
  `include "aes_cipher_sequencer.sv"
  `include "aes_cipher_driver.sv"
  `include "aes_cipher_monitor.sv"
  `include "aes_cipher_agent.sv"
  `include "aes_cipher_seq_lib.sv"

endpackage
