import aes_pkg::*;

module tb_minimo_vcs;
  localparam int NumShares = 1;

  logic clk_i = 0;
  logic rst_ni = 0;

  sp2v_e in_valid_i;
  sp2v_e in_ready_o;
  sp2v_e out_valid_o;
  sp2v_e out_ready_i;
  sp2v_e crypt_i;
  sp2v_e dec_key_gen_i;
  sp2v_e prng_reseed_i;

  ciph_op_e op_i;
  key_len_e key_len_i;

  logic [3:0][3:0][7:0] state_init_i [NumShares];
  logic [3:0][3:0][7:0] state_o      [NumShares];
  logic [7:0][31:0]     key_init_i   [NumShares];

  // Geração de Clock (período de 10 unidades de tempo)
  always #5 clk_i = ~clk_i;

  aes_cipher_core #(
    .SecMasking            (0),
    .SecSBoxImpl           (SBoxImplLut),
    .EnableAlertTriggerSVA (0)
  ) u_dut (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .in_valid_i       (in_valid_i),
    .in_ready_o       (in_ready_o),
    .out_valid_o      (out_valid_o),
    .out_ready_i      (out_ready_i),
    .crypt_i          (crypt_i),
    .dec_key_gen_i    (dec_key_gen_i),
    .prng_reseed_i    (prng_reseed_i),
    .key_clear_i      (SP2V_LOW),
    .data_out_clear_i (SP2V_LOW),
    .op_i             (op_i),
    .key_len_i        (key_len_i),
    .state_init_i     (state_init_i),
    .state_o          (state_o),
    .key_init_i       (key_init_i),
    .alert_fatal_i    (1'b0)
  );

  initial begin
    // "+all" força a gravação das matrizes state_init_i, state_o e key_init_i
    $fsdbDumpfile("ondas_aes.fsdb");
    $fsdbDumpvars(0, tb_minimo_vcs, "+all");

    in_valid_i    = SP2V_LOW;
    out_ready_i   = SP2V_HIGH;
    crypt_i       = SP2V_LOW;
    dec_key_gen_i = SP2V_LOW;
    prng_reseed_i = SP2V_LOW;
    op_i          = CIPH_FWD;
    key_len_i     = AES_128;
    state_init_i  = '{default:'0};
    key_init_i    = '{default:'0};

    // 1. Liberta o reset no tempo 20
    #20 rst_ni = 1;
    #20;

    // 2. No tempo 40, carrega o Vetor NIST FIPS-197 (AES-128)
    // Plaintext: 00112233445566778899aabbccddeeff
    state_init_i[0] = 128'hffeeddccbbaa99887766554433221100;

    // Key: 000102030405060708090a0b0c0d0e0f
    key_init_i[0][0] = 32'h03020100;
    key_init_i[0][1] = 32'h07060504;
    key_init_i[0][2] = 32'h0b0a0908;
    key_init_i[0][3] = 32'h0f0e0d0c;

    // 3. Pulsa in_valid_i e crypt_i para iniciar a cifra
    in_valid_i = SP2V_HIGH;
    crypt_i    = SP2V_HIGH;
    #10;
    in_valid_i = SP2V_LOW;

    // 4. Aguarda as 10 rodadas terminarem
    #200;
    
    $display("==================================================");
    $display("Entrada (state_init_i): %h", state_init_i[0]);
    $display("Saida Cifrada (state_o): %h", state_o[0]);
    $display("Esperado NIST (invertido): 5ac5b47080b7cdd830047b6ad8e0c469");
    $display("==================================================");
    #20 $finish;
  end
endmodule
