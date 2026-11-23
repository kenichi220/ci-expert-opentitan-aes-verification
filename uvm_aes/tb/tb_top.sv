// interface <-> DUT
// assertion safe
// vif e run_test()
`timescale 1ns/1ps

module tb_top;
 //add UVM class and text
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  //type do RTL --> vem do OT
  import aes_pkg::*;
  //explicita os testes para o compilador
  import aes_test_pkg::*;

  localparam time CLK_PERIOD   = 10ns;  // 100 MHz
  localparam int  RST_CYCLES   = 5;

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    rst_n = 1'b0;
    repeat (RST_CYCLES) @(posedge clk);
    rst_n <= 1'b1;
  end
 // tipo         nome  .porta_da_interface(sinal_do_tb)
 //  XX           XX    (clk,rest_n) --> ordem igual ao declarado em cipher_if
  aes_cipher_if cif (.clk(clk), .rst_n(rst_n));

  // Portas do core sao arrays [NumShares] sem mask NumShares=1
  logic [3:0][3:0][7:0] state_init_sh   [1]; // unpacked 
  logic     [7:0][31:0] key_init_sh     [1];
  logic [3:0][3:0][7:0] state_out_sh    [1];
  logic [3:0][3:0][7:0] prd_clr_state_sh[1];
  logic     [7:0][31:0] prd_clr_key_sh  [1];

  //atribui valor
  assign state_init_sh[0] = cif.state_init;
  assign key_init_sh[0]   = cif.key_init;
  assign cif.state_out    = state_out_sh[0];

  // Valor de "limpeza" fixo (no chip vem do PRNG) --> colocado pois spec pede
  // para não ter o valor de cifra/decifra
  assign prd_clr_state_sh[0] = 128'h5a5a_a5a5_3c3c_c3c3_0f0f_f0f0_9696_6969;
  assign prd_clr_key_sh[0]   = {8{32'hc0de_cafe}};

  logic [3:0][3:0][7:0] data_in_mask;   // usa para maks posteriormente
  logic                 entropy_req;    // SecMasking=0, ==0
  logic                 prng_reseed_out;
  //DUT paramter
  aes_cipher_core #(
    .AES192Enable  (1'b1),
    .CiphOpFwdOnly (1'b0),
    .SecMasking    (1'b0),
    .SecSBoxImpl   (SBoxImplCanright)
  ) dut (
    .clk_i                (clk),
    .rst_ni               (rst_n),

    .in_valid_i           (cif.in_valid), //cif. tb controla via driver
    .in_ready_o           (cif.in_ready),
    .out_valid_o          (cif.out_valid),
    .out_ready_i          (cif.out_ready),

    .cfg_valid_i          (cif.cfg_valid),
    .op_i                 (cif.op),
    .key_len_i            (cif.key_len),
    .crypt_i              (cif.crypt),
    .crypt_o              (cif.crypt_out),
    .dec_key_gen_i        (cif.dec_key_gen),
    .dec_key_gen_o        (cif.dec_key_gen_out),
    .prng_reseed_i        (1'b0),             // sem PRNG de mascaras
    .prng_reseed_o        (prng_reseed_out),
    .key_clear_i          (cif.key_clear),
    .key_clear_o          (cif.key_clear_out),
    .data_out_clear_i     (cif.data_out_clear),
    .data_out_clear_o     (cif.data_out_clear_out),
    .alert_fatal_i        (1'b0),             // nenhum alerta externo
    .alert_o              (cif.alert),

    .prd_clearing_state_i (prd_clr_state_sh),
    .prd_clearing_key_i   (prd_clr_key_sh),

    .force_masks_i        (1'b0),
    .data_in_mask_o       (data_in_mask),
    .entropy_req_o        (entropy_req),
    .entropy_ack_i        (1'b0),
    .entropy_i            ('0),

    .state_init_i         (state_init_sh),
    .key_init_i           (key_init_sh),
    .state_o              (state_out_sh)
  );

  // SEC_CM: FSM em estado invalido -> alert em ate 30 ciclos (papel do top aes no chip)
  // Verif do core, valor = 30 pois é função do top controlar isso
  localparam int AlertMaxCycles = 30;
  // 3 fsm
  // Sp2VWidth == 3 
  //
  for (genvar i = 0; i < Sp2VWidth; i++) begin : gen_fsm_alert_chk
    if (SP2V_LOGIC_HIGH[i] == 1'b1) begin : gen_p
      assign dut.u_aes_cipher_control.gen_fsm[i].gen_fsm_p.u_aes_cipher_control_fsm_i.
             u_aes_cipher_control_fsm.u_state_regs.unused_assert_connected = 1'b1; // se renomear o rtl quebra
      FsmErrToAlert_A: assert property (@(posedge clk) disable iff (!rst_n)
          $rose(dut.u_aes_cipher_control.gen_fsm[i].gen_fsm_p.u_aes_cipher_control_fsm_i.
                u_aes_cipher_control_fsm.u_state_regs.unused_err_o)
          |-> ##[0:AlertMaxCycles] cif.alert)
        else `uvm_error("SEC_CM", $sformatf("FSM rail %0d em estado invalido sem alert", i))
    end else begin : gen_n
      assign dut.u_aes_cipher_control.gen_fsm[i].gen_fsm_n.u_aes_cipher_control_fsm_i.
             u_aes_cipher_control_fsm.u_state_regs.unused_assert_connected = 1'b1; //se renomear o rtl quebra
      FsmErrToAlert_A: assert property (@(posedge clk) disable iff (!rst_n)
          $rose(dut.u_aes_cipher_control.gen_fsm[i].gen_fsm_n.u_aes_cipher_control_fsm_i.
                u_aes_cipher_control_fsm.u_state_regs.unused_err_o)
          |-> ##[0:AlertMaxCycles] cif.alert)
          // se isso aqui ativar, fica em 30 cyclos indefinodo e no final tem
          // que subir um alert
        else `uvm_error("SEC_CM", $sformatf("FSM rail %0d em estado invalido sem alert", i))
    end
  end

  //pro verdi
  initial begin : waves_dump
    string fsdb_file;
    if ($value$plusargs("WAVES=%s", fsdb_file)) begin
      $fsdbDumpfile(fsdb_file);
      $fsdbDumpvars(0, tb_top, "+all");
    end
  end

  initial begin
    // vif visivel para o teste e tudo abaixo dele
    // #virtual aes_cipher_if = tipo -> get
    // null -> module não componente
    // uvm_test_top* quem tem permissão de ler
    // vif = nome
    // cif interface real do virtual
    uvm_config_db#(virtual aes_cipher_if)::set(null, "uvm_test_top*", "vif", cif);
    run_test();
  end

endmodule
