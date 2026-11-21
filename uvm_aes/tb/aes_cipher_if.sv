`timescale 1ns/1ps

interface aes_cipher_if (
  input logic clk,
  input logic rst_n
);
  import aes_pkg::*;

  sp2v_e in_valid;    // TB  -> DUT
  sp2v_e in_ready;    // DUT -> TB
  sp2v_e out_valid;   // DUT -> TB
  sp2v_e out_ready;   // TB  -> DUT

  logic     cfg_valid;
  ciph_op_e op;
  key_len_e key_len;
  sp2v_e    crypt;
  sp2v_e    dec_key_gen;
  logic     key_clear;
  logic     data_out_clear;

  sp2v_e    crypt_out;
  sp2v_e    dec_key_gen_out;
  logic     key_clear_out;
  logic     data_out_clear_out;

  logic     alert;

  logic [3:0][3:0][7:0] state_init;
  logic     [7:0][31:0] key_init;
  logic [3:0][3:0][7:0] state_out;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output in_valid, out_ready;
    output cfg_valid, op, key_len, crypt, dec_key_gen, key_clear, data_out_clear;
    output state_init, key_init;
    input  in_ready, out_valid;
  endclocking

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
