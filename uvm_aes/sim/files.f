//pacote antes de quem o importa.
+incdir+${OT_DEPS}/prim/rtl
+incdir+${UVM_AES_ROOT}/tb
+incdir+${UVM_AES_ROOT}/agent
+incdir+${UVM_AES_ROOT}/env
+incdir+${UVM_AES_ROOT}/test

${OT_DEPS}/prim/rtl/prim_util_pkg.sv
${OT_DEPS}/prim/rtl/prim_trivium_pkg.sv
${OT_DEPS}/entropy_src/rtl/entropy_src_pkg.sv
${OT_DEPS}/csrng/rtl/csrng_reg_pkg.sv
${OT_DEPS}/csrng/rtl/csrng_pkg.sv
${OT_DEPS}/edn/rtl/edn_pkg.sv

${AES_RTL}/aes_reg_pkg.sv
${AES_RTL}/aes_pkg.sv
${AES_RTL}/aes_sbox_canright_pkg.sv

${OT_DEPS}/prim_generic/rtl/prim_buf.sv
${OT_DEPS}/prim_generic/rtl/prim_flop.sv
${OT_DEPS}/prim_generic/rtl/prim_flop_en.sv
${OT_DEPS}/prim_generic/rtl/prim_xor2.sv
${OT_DEPS}/prim/rtl/prim_sec_anchor_buf.sv
${OT_DEPS}/prim/rtl/prim_sparse_fsm_flop.sv
${OT_DEPS}/prim/rtl/prim_trivium.sv

// S-Boxes mascaradas nao sao usadas, mas o aes_sbox as referencia
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

${UVM_AES_ROOT}/tb/aes_cipher_if.sv
${UVM_AES_ROOT}/agent/aes_cipher_agent_pkg.sv
${UVM_AES_ROOT}/env/aes_env_pkg.sv
${UVM_AES_ROOT}/test/aes_test_pkg.sv
${UVM_AES_ROOT}/tb/tb_top.sv
