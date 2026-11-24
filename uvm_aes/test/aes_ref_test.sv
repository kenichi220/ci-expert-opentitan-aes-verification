// aes_ref_test.sv: Teste do ref model sem DUT (FIPS, ida e volta, estado)
class aes_ref_test extends aes_base_test;
  `uvm_component_utils(aes_ref_test)

  aes_ref_model rm;

  function new(string name = "aes_ref_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    rm = aes_ref_model::type_id::create("rm");
    check_fips();
    check_round_trip(300);
    check_state();
    phase.drop_objection(this);
  endtask

  function void check_fips();
    key_len_e kl_list[3] = '{AES_128, AES_192, AES_256};
    string    key_hex[3] = '{"000102030405060708090a0b0c0d0e0f",
                             "000102030405060708090a0b0c0d0e0f1011121314151617",
                             "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"};
    string    ct_hex[3]  = '{"69c4e0d86a7b0430d8cdb78070b4c55a",
                             "dda97ca4864cdfe06eaf70a0ec0d7191",
                             "8ea2b7ca516745bfeafc49904b496089"};
    string    pt_hex     = "00112233445566778899aabbccddeeff";
    string    got;

    foreach (kl_list[i]) begin
      got = state_to_hex(rm.cipher(CIPH_FWD, kl_list[i], hex_to_key(key_hex[i]), hex_to_state(pt_hex)));
      if (got != ct_hex[i])
        `uvm_error("REF", $sformatf("FIPS enc %s: obtido %s, esperado %s", kl_list[i].name(), got, ct_hex[i]))
      else
        `uvm_info("REF", $sformatf("FIPS enc %s OK: %s", kl_list[i].name(), got), UVM_LOW)

      got = state_to_hex(rm.cipher(CIPH_INV, kl_list[i], hex_to_key(key_hex[i]), hex_to_state(ct_hex[i])));
      if (got != pt_hex)
        `uvm_error("REF", $sformatf("FIPS dec %s: obtido %s, esperado %s", kl_list[i].name(), got, pt_hex))
      else
        `uvm_info("REF", $sformatf("FIPS dec %s OK: %s", kl_list[i].name(), got), UVM_LOW)
    end
  endfunction

  function void check_round_trip(int n);
    aes_cipher_item it = aes_cipher_item::type_id::create("it");
    aes_state_t     ct, back;
    int             n_bad = 0;

    repeat (n) begin
      if (!it.randomize() with { cmd == CMD_CRYPT; }) `uvm_fatal("REF", "randomize() falhou")
      ct   = rm.cipher(CIPH_FWD, it.key_len, it.key, it.state_in);
      back = rm.cipher(CIPH_INV, it.key_len, it.key, ct);
      if (back !== it.state_in || ct === it.state_in) begin
        n_bad++;
        `uvm_error("REF", $sformatf("ida e volta falhou %s: in=%s ct=%s back=%s", it.key_len.name(),
                   state_to_hex(it.state_in), state_to_hex(ct), state_to_hex(back)))
      end
    end
    if (n_bad == 0) `uvm_info("REF", $sformatf("ida e volta OK em %0d blocos", n), UVM_LOW)
  endfunction

  function void check_state();
    aes_cipher_item it = aes_cipher_item::type_id::create("it");
    aes_key_t       k  = hex_to_key("2b7e151628aed2a6abf7158809cf4f3c");
    aes_state_t     pt = hex_to_state("6bc1bee22e409f96e93d7e117393172a");
    aes_state_t     ct = rm.cipher(CIPH_FWD, AES_128, k, pt);

    set_item(it, CMD_CRYPT, CIPH_INV, AES_128, k, ct);
    expect_pred("decifra apos reset", it, PRED_UNKNOWN);

    set_item(it, CMD_DEC_KEY_GEN, CIPH_FWD, AES_128, k, '0);
    expect_pred("dec_key_gen", it, PRED_NO_RESULT);
    set_item(it, CMD_CRYPT, CIPH_INV, AES_128, ~k, ct);
    expect_pred("decifra apos dec_key_gen", it, PRED_CHECK, pt);

    set_item(it, CMD_CRYPT, CIPH_INV, AES_256, k, ct);
    expect_pred("decifra com outro key_len", it, PRED_UNKNOWN);

    set_item(it, CMD_CRYPT, CIPH_FWD, AES_128, k, pt);
    expect_pred("cifra", it, PRED_CHECK, ct);

    set_item(it, CMD_KEY_CLEAR, CIPH_FWD, AES_128, k, '0);
    expect_pred("key_clear", it, PRED_NO_RESULT);
    set_item(it, CMD_CRYPT, CIPH_INV, AES_128, k, ct);
    expect_pred("decifra apos key_clear", it, PRED_UNKNOWN);
  endfunction

  protected function void set_item(aes_cipher_item it, aes_cmd_e cmd, ciph_op_e op,
                                   key_len_e kl, aes_key_t key, aes_state_t din);
    it.cmd      = cmd;
    it.op       = op;
    it.key_len  = kl;
    it.key      = key;
    it.state_in = din;
    it.err      = ERR_NONE;
  endfunction

  protected function void expect_pred(string tag, aes_cipher_item it, aes_pred_e exp_pred,
                                      aes_state_t exp_state = '0);
    aes_state_t got;
    string      why;
    aes_pred_e  p;
    p = rm.predict(it, got, why);
    if (p != exp_pred)
      `uvm_error("REF", $sformatf("%s: predict deu %s, esperado %s (%s)", tag, p.name(), exp_pred.name(), why))
    else if (p == PRED_CHECK && got !== exp_state)
      `uvm_error("REF", $sformatf("%s: previsto %s, esperado %s", tag, state_to_hex(got), state_to_hex(exp_state)))
    else
      `uvm_info("REF", $sformatf("estado: %-26s -> %s OK", tag, p.name()), UVM_LOW)
  endfunction

endclass
