// aes_txn_logger.sv: Logger temporario: imprime cada transacao
class aes_txn_logger extends uvm_subscriber #(aes_cipher_item);
  `uvm_component_utils(aes_txn_logger)

  aes_cipher_item last_item;          // ultima transacao recebida
  aes_cipher_item items[$];           // usado pelo aes_agent_test
  int unsigned    num_items;
  int unsigned    num_alerts;
  int unsigned    cnt_cmd[aes_cmd_e];
  int unsigned    cnt_err[aes_err_e];
  int unsigned    num_b2b;            // idle_cycles == 0
  int unsigned    num_bp;             // out_ready_delay > 0
  int unsigned    max_bp;

  function new(string name = "aes_txn_logger", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void write(aes_cipher_item t);
    string err_s = "";
    last_item = t;
    items.push_back(t);
    num_items++;
    if (t.alert) num_alerts++;
    if (t.err != ERR_NONE) cnt_err[t.err]++;
    else                   cnt_cmd[t.cmd]++;
    if (t.idle_cycles == 0) num_b2b++;
    if (t.out_ready_delay > 0) begin
      num_bp++;
      if (t.out_ready_delay > max_bp) max_bp = t.out_ready_delay;
    end

    if (t.err != ERR_NONE) err_s = {" err=", t.err.name()};
    `uvm_info("TXN", $sformatf("#%0d %-18s %s %s idle=%0d bp=%0d%s alert=%0b out=%s",
              num_items, t.cmd.name(), t.op.name(), t.key_len.name(),
              t.idle_cycles, t.out_ready_delay, err_s,
              t.alert, state_to_hex(t.state_out)), UVM_MEDIUM)
  endfunction

  virtual function void report_phase(uvm_phase phase);
    string s;
    super.report_phase(phase);
    s = $sformatf("\n  transacoes observadas : %0d\n  com alert             : %0d", num_items, num_alerts);
    foreach (cnt_cmd[c]) s = {s, $sformatf("\n  %-21s : %0d", c.name(), cnt_cmd[c])};
    foreach (cnt_err[e]) s = {s, $sformatf("\n  %-21s : %0d", e.name(), cnt_err[e])};
    s = {s, $sformatf("\n  back-to-back          : %0d\n  com backpressure      : %0d (max %0d ciclos)",
                      num_b2b, num_bp, max_bp)};
    `uvm_info("TXN", {"resumo do monitor:", s}, UVM_LOW)
  endfunction

endclass
