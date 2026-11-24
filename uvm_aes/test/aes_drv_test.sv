// aes_drv_test.sv: aes_drv_test (FIPS + clears + aleatorio) e aes_drv_err_test (+ERR=)
class aes_drv_test extends aes_base_test;
  `uvm_component_utils(aes_drv_test)

  function new(string name = "aes_drv_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  static const string FIPS_PT = "00112233445566778899aabbccddeeff";

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env_cfg.min_checked = 7;
  endfunction

  virtual task run_seqs();
    key_len_e kl_list[3] = '{AES_128, AES_192, AES_256};
    string    key_hex[3] = '{"000102030405060708090a0b0c0d0e0f",
                             "000102030405060708090a0b0c0d0e0f1011121314151617",
                             "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"};
    string    ct_hex[3]  = '{"69c4e0d86a7b0430d8cdb78070b4c55a",
                             "dda97ca4864cdfe06eaf70a0ec0d7191",
                             "8ea2b7ca516745bfeafc49904b496089"};

    foreach (kl_list[i]) begin
      run_fips(kl_list[i], key_hex[i], ct_hex[i]);
    end

    begin
      aes_cipher_clear_seq clr = aes_cipher_clear_seq::type_id::create("clr");
      aes_cmd_e clears[3] = '{CMD_KEY_CLEAR, CMD_DATA_OUT_CLEAR, CMD_CLEAR_ALL};
      foreach (clears[i]) begin
        if (!clr.randomize() with { clear_cmd == local::clears[i]; })
          `uvm_fatal("TEST", "randomize() da clear_seq falhou")
        clr.start(env.agent.sqr);
        `uvm_info("TEST", $sformatf("%s executado", clears[i].name()), UVM_LOW)
      end
      run_fips(AES_128, key_hex[0], ct_hex[0]);
    end

    begin
      aes_cipher_rand_seq rs = aes_cipher_rand_seq::type_id::create("rs");
      if (!rs.randomize()) `uvm_fatal("TEST", "randomize() da rand_seq falhou")
      `uvm_info("TEST", $sformatf("rand_seq com %0d itens", rs.num_items), UVM_LOW)
      rs.start(env.agent.sqr);
    end
  endtask

  protected task run_fips(key_len_e kl, string k_hex, string ct_hex);
    aes_cipher_enc_seq enc = aes_cipher_enc_seq::type_id::create("enc");
    aes_cipher_dec_seq dec = aes_cipher_dec_seq::type_id::create("dec");

    enc.key_len   = kl;
    enc.key       = hex_to_key(k_hex);
    enc.plaintext = hex_to_state(FIPS_PT);
    enc.start(env.agent.sqr);

    dec.key_len    = kl;
    dec.key        = hex_to_key(k_hex);
    dec.ciphertext = hex_to_state(ct_hex);
    dec.start(env.agent.sqr);
  endtask

endclass

class aes_drv_err_test extends aes_base_test;
  `uvm_component_utils(aes_drv_err_test)

  function new(string name = "aes_drv_err_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env_cfg.min_checked = 1;   // a cifra antes do erro
  endfunction

  virtual task run_seqs();
    aes_cipher_enc_seq enc = aes_cipher_enc_seq::type_id::create("enc");
    aes_cipher_err_seq es  = aes_cipher_err_seq::type_id::create("es");
    string             err_name;
    aes_err_e          e;

    if (!enc.randomize()) `uvm_fatal("TEST", "randomize() da enc_seq falhou")
    enc.start(env.agent.sqr);

    if (!es.randomize()) `uvm_fatal("TEST", "randomize() da err_seq falhou")
    if ($value$plusargs("ERR=%s", err_name)) begin
      e = e.first();
      forever begin
        if (e.name() == err_name) break;
        if (e == e.last()) `uvm_fatal("TEST", {"+ERR desconhecido: ", err_name})
        e = e.next();
      end
      if (e == ERR_NONE) `uvm_fatal("TEST", "+ERR=ERR_NONE nao faz sentido neste teste")
      es.err = e;
    end
    `uvm_info("TEST", $sformatf("injetando %s", es.err.name()), UVM_LOW)
    es.start(env.agent.sqr);
  endtask

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    // Se monitor e DUT falhassem juntos, nada chegaria ao sb: o teste confere
    if (env.sb.n_alert_ok != 1)
      `uvm_error("TEST", $sformatf("erro injetado: scoreboard deveria ver 1 erro com alert, viu %0d",
                                   env.sb.n_alert_ok))
  endfunction
endclass
