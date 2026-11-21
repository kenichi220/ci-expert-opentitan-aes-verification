// -----------------------------------------------------------------------------
// files.f: lista de arquivos do uvm_aes para o VCS (vcs -f files.f)
//
// As variaveis ${...} sao expandidas pelo VCS a partir do ambiente; o Makefile
// as exporta:
//   OT_DEPS      = uvm_aes/deps/opentitan   (prim_* e pacotes do OpenTitan)
//   AES_RTL      = aes/rtl                  (RTL do AES, sem copia)
//   UVM_AES_ROOT = uvm_aes                  (nosso TB)
//
// ORDEM IMPORTA para pacotes: um pacote precisa ser compilado antes de quem o
// importa. Modulos podem vir em qualquer ordem.
// -----------------------------------------------------------------------------

// ---- Diretorios de `include --------------------------------------------------
+incdir+${OT_DEPS}/prim/rtl
+incdir+${UVM_AES_ROOT}/tb
+incdir+${UVM_AES_ROOT}/test

// ---- Pacotes do OpenTitan (dependencias de tipos) ----------------------------
${OT_DEPS}/prim/rtl/prim_util_pkg.sv
${OT_DEPS}/prim/rtl/prim_trivium_pkg.sv
${OT_DEPS}/entropy_src/rtl/entropy_src_pkg.sv
${OT_DEPS}/csrng/rtl/csrng_reg_pkg.sv
${OT_DEPS}/csrng/rtl/csrng_pkg.sv
${OT_DEPS}/edn/rtl/edn_pkg.sv

// ---- Pacotes do AES ----------------------------------------------------------
${AES_RTL}/aes_reg_pkg.sv
${AES_RTL}/aes_pkg.sv
${AES_RTL}/aes_sbox_canright_pkg.sv

// ---- Primitivas (implementacao generica, para simulacao) ---------------------
${OT_DEPS}/prim_generic/rtl/prim_buf.sv
${OT_DEPS}/prim_generic/rtl/prim_flop.sv
${OT_DEPS}/prim_generic/rtl/prim_flop_en.sv
${OT_DEPS}/prim_generic/rtl/prim_xor2.sv
${OT_DEPS}/prim/rtl/prim_sec_anchor_buf.sv
${OT_DEPS}/prim/rtl/prim_sparse_fsm_flop.sv
${OT_DEPS}/prim/rtl/prim_trivium.sv

// ---- RTL do aes_cipher_core --------------------------------------------------
// As S-Boxes mascaradas nao sao usadas (SecMasking=0, LUT), mas o aes_sbox as
// referencia em ramos de generate, entao entram na compilacao.
${AES_RTL}/aes_sel_buf_chk.sv
${AES_RTL}/aes_prng_masking.sv
${AES_RTL}/aes_sbox_lut.sv
${AES_RTL}/aes_sbox_canright.sv
${AES_RTL}/aes_sbox_canright_masked.sv
${AES_RTL}/aes_sbox_canright_masked_noreuse.sv
${AES_RTL}/aes_sbox_dom.sv
${AES_RTL}/aes_sbox.sv
${AES_RTL}/aes_sub_bytes.sv
${AES_RTL}/aes_shift_rows.sv
${AES_RTL}/aes_mix_single_column.sv
${AES_RTL}/aes_mix_columns.sv
${AES_RTL}/aes_key_expand.sv
${AES_RTL}/aes_cipher_control_fsm.sv
${AES_RTL}/aes_cipher_control_fsm_p.sv
${AES_RTL}/aes_cipher_control_fsm_n.sv
${AES_RTL}/aes_cipher_control.sv
${AES_RTL}/aes_cipher_core.sv

// ---- Testbench ---------------------------------------------------------------
// A interface vem antes dos pacotes UVM que usam "virtual aes_cipher_if".
${UVM_AES_ROOT}/tb/aes_cipher_if.sv
${UVM_AES_ROOT}/test/aes_test_pkg.sv
${UVM_AES_ROOT}/tb/tb_top.sv
