`timescale 1ns/1ps // #1 == 1ns

// portas do tb_top
interface aes_cipher_if (
  input logic clk,
  input logic rst_n
);

// importa variaveis do RTL do OT
  import aes_pkg::*;

  // sp2v_e: SP2V_HIGH=3'b011, SP2V_LOW=3'b100; outro valor = erro (alert)
  sp2v_e in_valid;    // TB  -> DUT : "tenho um comando/dado valido"
  sp2v_e in_ready;    // DUT -> TB  : "estou em IDLE, posso aceitar"
  sp2v_e out_valid;   // DUT -> TB  : "state_out tem o resultado"
  sp2v_e out_ready;   // TB  -> DUT : "pode entregar, estou consumindo"

  logic     cfg_valid;       // assertions internas do DUT
  ciph_op_e op;              // CIPH_FWD / CIPH_INV 
  key_len_e key_len;         // AES_128 / AES_192 / AES_256
  sp2v_e    crypt;           // executar cifra/decifra
  sp2v_e    dec_key_gen;     // gerar chave de decifra
  logic     key_clear;       // limpar registradores de chave
  logic     data_out_clear;  // limpar registrador de saida

  sp2v_e    crypt_out;
  sp2v_e    dec_key_gen_out;
  logic     key_clear_out;
  logic     data_out_clear_out;

  logic     alert;

  logic [3:0][3:0][7:0] state_init;  // [linha][coluna][bit]
  logic     [7:0][31:0] key_init;    // 256 bits
  logic [3:0][3:0][7:0] state_out;   // resultado

  // Driver dirige 1ns apos a borda
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    inout  in_valid, out_ready;
    output cfg_valid, op, key_len, crypt, dec_key_gen, key_clear, data_out_clear;
    output state_init, key_init;
    input  in_ready, out_valid;
    input  state_out, alert;
  endclocking

  // Monitor pega logo apos a borda
  clocking mon_cb @(posedge clk);
    default input #1step;
    input in_valid, in_ready, out_valid, out_ready;
    input cfg_valid, op, key_len, crypt, dec_key_gen, key_clear, data_out_clear;
    input crypt_out, dec_key_gen_out, key_clear_out, data_out_clear_out;
    input alert;
    input state_init, key_init, state_out;
  endclocking

  function automatic bit in_hs();
    return (mon_cb.in_valid == SP2V_HIGH) && (mon_cb.in_ready == SP2V_HIGH);
  endfunction

  function automatic bit out_hs();
    return (mon_cb.out_valid == SP2V_HIGH) && (mon_cb.out_ready == SP2V_HIGH);
  endfunction

endinterface
