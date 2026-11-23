// quais itens gerar e qual ordem
class aes_cipher_base_seq extends uvm_sequence #(aes_cipher_item);
  `uvm_object_utils(aes_cipher_base_seq)

  function new(string name = "aes_cipher_base_seq");
    super.new(name);
  endfunction
// Ler direto de um "req" depende do preenchimento do driver, checar esse
// valor é incorreto

  // local:: se o nome é igual ao campo e não for declarado como local sempre
  // da true
  protected task do_crypt(ciph_op_e p_op, key_len_e p_kl, aes_state_t p_state,
                          aes_key_t p_key, output aes_state_t p_res);
    req = aes_cipher_item::type_id::create("req");
    start_item(req);
    if (!req.randomize() with {
      cmd      == CMD_CRYPT;
      op       == local::p_op;
      key_len  == local::p_kl;
      state_in == local::p_state;
      key      == local::p_key; })
      `uvm_fatal("SEQ", "randomize() falhou em do_crypt")
    finish_item(req);
    p_res = req.state_out;   // preenchido pelo driver
  endtask

  protected task do_dec_key_gen(key_len_e p_kl, aes_key_t p_key);
    req = aes_cipher_item::type_id::create("req");
    start_item(req);
    if (!req.randomize() with { 
      cmd     == CMD_DEC_KEY_GEN;
      key_len == local::p_kl;
      key     == local::p_key; })
      `uvm_fatal("SEQ", "randomize() falhou em do_dec_key_gen")
    finish_item(req);
  endtask

  protected task do_clear(aes_cmd_e p_cmd);
    req = aes_cipher_item::type_id::create("req");
    start_item(req);
    if (!req.randomize() with { cmd == local::p_cmd; })
      `uvm_fatal("SEQ", "randomize() falhou em do_clear")
    finish_item(req);
  endtask
endclass

class aes_cipher_enc_seq extends aes_cipher_base_seq;
  `uvm_object_utils(aes_cipher_enc_seq)

  rand key_len_e   key_len;
  rand aes_state_t plaintext;
  rand aes_key_t   key;
  aes_state_t      ciphertext;   // resultado, para quem chamou

  function new(string name = "aes_cipher_enc_seq");
    super.new(name);
  endfunction

  virtual task body();
    do_crypt(CIPH_FWD, key_len, plaintext, key, ciphertext);
  endtask
endclass

class aes_cipher_dec_seq extends aes_cipher_base_seq;
  `uvm_object_utils(aes_cipher_dec_seq)

  rand key_len_e   key_len;
  rand aes_state_t ciphertext;
  rand aes_key_t   key;
  aes_state_t      plaintext;

  function new(string name = "aes_cipher_dec_seq");
    super.new(name);
  endfunction

  virtual task body();
    do_dec_key_gen(key_len, key);
    do_crypt(CIPH_INV, key_len, ciphertext, key, plaintext);
  endtask
endclass

class aes_cipher_clear_seq extends aes_cipher_base_seq;
  `uvm_object_utils(aes_cipher_clear_seq)

  rand aes_cmd_e clear_cmd;
  constraint c_clear { clear_cmd inside {CMD_KEY_CLEAR, CMD_DATA_OUT_CLEAR, CMD_CLEAR_ALL}; }

  function new(string name = "aes_cipher_clear_seq");
    super.new(name);
  endfunction

  virtual task body();
    do_clear(clear_cmd);
  endtask
endclass

class aes_cipher_rand_seq extends aes_cipher_base_seq;
  `uvm_object_utils(aes_cipher_rand_seq)

  rand int unsigned num_items;
  constraint c_num { num_items inside {[20:100]}; }

  function new(string name = "aes_cipher_rand_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_items) begin
      req = aes_cipher_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) `uvm_fatal("SEQ", "randomize() falhou em rand_seq")
      finish_item(req);
    end
  endtask
endclass

class aes_cipher_err_seq extends aes_cipher_base_seq;
  `uvm_object_utils(aes_cipher_err_seq)

  rand aes_err_e err;
  constraint c_err { err != ERR_NONE; }

  bit alert_seen;   // resultado, para quem chamou

  function new(string name = "aes_cipher_err_seq");
    super.new(name);
  endfunction

  virtual task body();
    req = aes_cipher_item::type_id::create("req");
    start_item(req);
    if (!req.randomize() with { err == local::err; })
      `uvm_fatal("SEQ", "randomize() falhou em err_seq")
    finish_item(req);
    alert_seen = req.alert;
    `uvm_info("SEQ", {"item com erro:\n", req.convert2string()}, UVM_MEDIUM)
  endtask
endclass
