// sequence sorteia, driver aplica, respota no monitor
// uvm_sequence_item -> só ele pode passar pelo sequence até o drive
class aes_cipher_item extends uvm_sequence_item;

  rand aes_cmd_e   cmd;
  rand ciph_op_e   op;
  rand key_len_e   key_len;
  rand aes_state_t state_in;
  rand aes_key_t   key;       // 256 bits sempre; o DUT usa so key_len_bytes

  rand int unsigned idle_cycles;      // in_valid=LOW
  rand int unsigned out_ready_delay;  // out_ready=LOW apos out_valid

  rand aes_err_e   err; //type do erro injetado
  rand logic [2:0] err_val;   // valor sp2v invalido

  aes_state_t state_out;
  logic       alert;
 //Distribuição de probabilidade no rand, := peso para cada valor
 //:/ peso dividido entre os valores
  constraint c_cmd_dist {
    cmd dist { CMD_CRYPT          := 70,
               CMD_DEC_KEY_GEN    := 15,
               CMD_KEY_CLEAR      := 5,
               CMD_DATA_OUT_CLEAR := 5,
               CMD_CLEAR_ALL      := 5 };
  }

  constraint c_idle {
    idle_cycles dist { 0 := 60, [1:3] :/ 30, [4:10] :/ 10 };
  }

  constraint c_out_ready_delay {
    out_ready_delay dist { 0 := 50, [1:5] :/ 40, [6:20] :/ 10 };
  }

  // soft: um teste de erro sobrescreve sem conflito
  constraint c_err_default {
    soft err == ERR_NONE;
  }
  //Qualquer valor de n bits igual diferente dos que estao em {}
  constraint c_err_val {
    !(err_val inside {SP2V_HIGH, SP2V_LOW});
  }

  constraint c_err_cmd {
    (err == ERR_CRYPT)       -> (cmd == CMD_CRYPT);
    (err == ERR_DEC_KEY_GEN) -> (cmd == CMD_DEC_KEY_GEN);
  }
// Resgitra em factory -> usado em aes_sb_neg
  `uvm_object_utils(aes_cipher_item)

  function new(string name = "aes_cipher_item");
    super.new(name);
  endfunction
// da pra usar `uvm_field_int(...), mas aqui explicitei pq escolho oq quero comparar
  virtual function void do_copy(uvm_object rhs);
    aes_cipher_item rhs_;
    if (!$cast(rhs_, rhs)) `uvm_fatal("CAST", "do_copy: rhs this not a aes_cipher_item")
    super.do_copy(rhs);
    cmd             = rhs_.cmd;
    op              = rhs_.op;
    key_len         = rhs_.key_len;
    state_in        = rhs_.state_in;
    key             = rhs_.key;
    idle_cycles     = rhs_.idle_cycles;
    out_ready_delay = rhs_.out_ready_delay;
    err             = rhs_.err;
    err_val         = rhs_.err_val;
    state_out       = rhs_.state_out;
    alert           = rhs_.alert;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    aes_cipher_item rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return super.do_compare(rhs, comparer) &&
           (cmd       ==  rhs_.cmd)       &&
           (op        ==  rhs_.op)        &&
           (key_len   ==  rhs_.key_len)   &&
           (state_in  === rhs_.state_in)  &&
           (key       === rhs_.key)       &&
           (err       ==  rhs_.err)       &&
           (state_out === rhs_.state_out) &&
           (alert     === rhs_.alert);
  endfunction

  virtual function string convert2string();
    string s;
    s = $sformatf("cmd=%s op=%s key_len=%s idle=%0d out_ready_delay=%0d",
                  cmd.name(), op.name(), key_len.name(), idle_cycles, out_ready_delay);
    if (err != ERR_NONE) s = {s, $sformatf(" err=%s(%03b)", err.name(), err_val)};
    s = {s, $sformatf("\n  state_in =%s\n  key      =%s\n  state_out=%s alert=%b",
                      state_to_hex(state_in), key_to_hex(key, key_len),
                      state_to_hex(state_out), alert)};
    return s;
  endfunction

endclass
