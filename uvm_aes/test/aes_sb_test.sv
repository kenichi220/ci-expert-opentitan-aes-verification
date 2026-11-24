// aes_sb_test.sv: aes_sb_neg_test: bug no ref model, o scoreboard tem que acusar
class aes_ref_model_bug extends aes_ref_model;
  `uvm_object_utils(aes_ref_model_bug)

  function new(string name = "aes_ref_model_bug");
    super.new(name);
  endfunction

  virtual function aes_state_t cipher(ciph_op_e op, key_len_e kl, aes_key_t key,
                                      aes_state_t din);
    aes_state_t r = super.cipher(op, kl, key, din);
    if (op == CIPH_FWD) r[0][0][0] = ~r[0][0][0];
    return r;
  endfunction
endclass

class aes_sb_neg_test extends aes_drv_test;
  `uvm_component_utils(aes_sb_neg_test)

  function new(string name = "aes_sb_neg_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    // Override antes de o sb criar o ref model
    aes_ref_model::type_id::set_type_override(aes_ref_model_bug::get_type());
    super.build_phase(phase);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    // SB_MISMATCH esperado aqui: rebaixado para INFO
    env.sb.set_report_severity_id_override(UVM_ERROR, "SB_MISMATCH", UVM_INFO);
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (env.sb.n_mismatch == 0)
      `uvm_error("NEG", "bug injetado no ref model e o scoreboard NAO acusou nada")
    else if (env.sb.n_mismatch != env.sb.n_by_op[CIPH_FWD])
      `uvm_error("NEG", $sformatf("esperado acusar todas as %0d cifras, acusou %0d",
                                  env.sb.n_by_op[CIPH_FWD], env.sb.n_mismatch))
    else
      `uvm_info("NEG", $sformatf("scoreboard acusou as %0d cifras com bug (e so elas)",
                                 env.sb.n_mismatch), UVM_LOW)
  endfunction
endclass
