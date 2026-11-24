//DUT x ref model, alert, vazamento no data_out_clear
class aes_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(aes_scoreboard)

  uvm_analysis_imp #(aes_cipher_item, aes_scoreboard) item_imp;

  aes_ref_model ref_model;

  // Menos comparacoes que isso = falha (evita PASSED sem trafego)
  int unsigned min_checked = 0;

  int unsigned n_items;        // transacoes recebidas
  int unsigned n_match;        // state_out == previsto
  int unsigned n_mismatch;     // state_out != previsto
  int unsigned n_unknown;      // decifra que o modelo nao sabe prever
  int unsigned n_no_result;    // dec_key_gen / clears
  int unsigned n_leak_checks;  // data_out_clear conferidos
  int unsigned n_alert_ok;     // erro injetado -> alert=1 (esperado)
  int unsigned n_alert_bad;    // erro sem alert, ou alert sem erro
  int unsigned n_by_kl[key_len_e];  // comparacoes por key_len
  int unsigned n_by_op[ciph_op_e];

  protected aes_state_t last_result; //resultado para vhecar vazamento
  protected bit         last_result_valid;

  function new(string name = "aes_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_imp  = new("item_imp", this);
    ref_model = aes_ref_model::type_id::create("ref_model");
  endfunction
  // Isso aquise pa nós vai ter problema depois e vai ter que trocar
  virtual function void write(aes_cipher_item t);
    aes_state_t exp;
    string      why;
    aes_pred_e  pred;

    n_items++;

    if (t.err != ERR_NONE) begin
      if (t.alert === 1'b1) begin
        n_alert_ok++;
        `uvm_info("SB", $sformatf("%s -> alert=1 (waited)", t.err.name()), UVM_MEDIUM)
      end else begin
        n_alert_bad++;
        `uvm_error("SB_ALERT", {"wait error but DUT NO UP alert:\n", t.convert2string()})
      end
      return;
    end

    if (t.alert !== 1'b0) begin
      n_alert_bad++;
      `uvm_error("SB_ALERT", {"alert with no error injection:\n", t.convert2string()})
      return;
    end

    if (t.cmd inside {CMD_DATA_OUT_CLEAR, CMD_CLEAR_ALL}) check_no_leak(t);

    pred = ref_model.predict(t, exp, why);
    case (pred)
      PRED_CHECK:     compare(t, exp);
      PRED_NO_RESULT: n_no_result++;
      PRED_UNKNOWN: begin
        n_unknown++;
        `uvm_info("SB", {"no cmp: ", why}, UVM_HIGH)
      end
    endcase
  endfunction

  protected function void compare(aes_cipher_item t, aes_state_t exp);
    n_by_kl[t.key_len]++;
    n_by_op[t.op]++;
    if (t.state_out === exp) begin
      n_match++;
      `uvm_info("SB", $sformatf("OK %s %s: %s", t.op.name(), t.key_len.name(),
                                state_to_hex(exp)), UVM_HIGH)
    end else begin
      n_mismatch++;
      `uvm_error("SB_MISMATCH", $sformatf("%s %s\n  expected =%s\n  obtained   =%s\n  item: %s",
                 t.op.name(), t.key_len.name(), state_to_hex(exp),
                 state_to_hex(t.state_out), t.convert2string()))
    end
    last_result       = t.state_out;
    last_result_valid = 1'b1;
  endfunction

  // Saida apos clear: sem X/Z e diferente do ultimo resultado
  protected function void check_no_leak(aes_cipher_item t);
    n_leak_checks++;
    if ($isunknown(t.state_out))
      `uvm_error("SB_LEAK", $sformatf("%s: state_out com X/Z: %h", t.cmd.name(), t.state_out))
    else if (last_result_valid && t.state_out === last_result)
      `uvm_error("SB_LEAK", $sformatf("%s: state_out is the final = error %s",
                 t.cmd.name(), state_to_hex(last_result)))
    else
      `uvm_info("SB", $sformatf("%s: no leakedg (out=%s)", t.cmd.name(),
                                state_to_hex(t.state_out)), UVM_HIGH)
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (n_match + n_mismatch < min_checked)
      `uvm_error("SB_CHECK", $sformatf("so %0d cmp, the test wait: %0d",
                                       n_match + n_mismatch, min_checked))
  endfunction

  virtual function void report_phase(uvm_phase phase);
    string s;
    super.report_phase(phase);
    s = $sformatf("\n   transactions get : %0d", n_items);
    s = {s, $sformatf("\n  cmp OK         : %0d", n_match)};
    s = {s, $sformatf("\n  cmp ERRADAS    : %0d", n_mismatch)};
    foreach (n_by_op[o]) s = {s, $sformatf("\n    %-19s : %0d", o.name(), n_by_op[o])};
    foreach (n_by_kl[k]) s = {s, $sformatf("\n    %-19s : %0d", k.name(), n_by_kl[k])};
    s = {s, $sformatf("\n  no foreseen       : %0d (decipher dec_key_gen ok)", n_unknown)};
    s = {s, $sformatf("\n  no result         : %0d (dec_key_gen / clears)", n_no_result)};
    s = {s, $sformatf("\n  data_out_clear check: %0d", n_leak_checks)};
    s = {s, $sformatf("\n  alert expected : %0d", n_alert_ok)};
    s = {s, $sformatf("\n  alert problems   : %0d", n_alert_bad)};
    `uvm_info("SB", {"resume scoreboard:", s}, UVM_LOW)
  endfunction

endclass
