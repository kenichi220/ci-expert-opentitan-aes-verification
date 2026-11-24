// inverso do driver, le o sinais monta um cipher item com os outputs e libera
// para o scoreboars, coverage, logger
// Ele só le, não faz request de correto ou nao
class aes_cipher_monitor extends uvm_monitor;
  `uvm_component_utils(aes_cipher_monitor)

  aes_cipher_agent_cfg  cfg;
  virtual aes_cipher_if vif;

  uvm_analysis_port #(aes_cipher_item) ap; // porta que gospe os outs

  int unsigned alert_wait_cycles;   // copiado do cfg

  int unsigned num_items;

  protected aes_cipher_item cur;       // transacao em andamento 
  protected int unsigned    gap;       // bordas -> idle_cycles
  protected int unsigned    bp;        // bordas com out_valid=HIGH e out_ready!=HIGH
  protected int unsigned    err_wait;  // bordas desde que o erro foi visto
  protected bit             dut_dead;  // alert visto: DUT em ERROR (terminal)

  function new(string name = "aes_cipher_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (cfg == null) `uvm_fatal("NOCFG", "monitor no cfg, create: aes_cipher_agent")
    vif               = cfg.vif; //tanto vif quanto alert_wait_cycles são copias da cfg
    alert_wait_cycles = cfg.alert_wait_cycles;
  endfunction

  virtual task run_phase(uvm_phase phase);
    wait (vif.rst_n === 1'b1);
    forever begin
      @(vif.mon_cb);
      sample_cycle(); // call para analisar borda
    end
  endtask

  // Uma borda: alert -> handshake de entrada -> sp2v invalido -> saida
  protected function void sample_cycle();
    aes_err_e   e;
    logic [2:0] e_val;

    if (dut_dead) return;
    if (cur == null) gap++; // conta mais uma borda

    if (vif.mon_cb.alert === 1'b1) begin
      if (cur == null) begin
        cur = capture_input();
        `uvm_info("MON", "alert no transiction at moment: item so com alert=1", UVM_MEDIUM)
      end
      finish(1'b1);
      dut_dead = 1'b1;
      `uvm_info("MON", "DUT at ERROR (alert=1)", UVM_MEDIUM)
      return;
    end

    if (vif.in_hs()) begin
      if (cur != null) begin
        if (cur.err != ERR_NONE) begin
          `uvm_info("MON", $sformatf("%s read, no alert", cur.err.name()), UVM_MEDIUM)
          finish(1'b0);
        end else begin
          `uvm_error("MON", "handshake in with transiction")
        end
      end
      cur = capture_input();
      bp  = 0;
    end

    e = find_invalid_sp2v(e_val);
    if (e != ERR_NONE) begin
      if (cur == null) cur = capture_input();   // ERR_IN_VALID: no handshake
      if (cur.err == ERR_NONE) begin
        cur.err     = e;
        cur.err_val = e_val;
        err_wait    = 0;
      end
    end

    if (cur == null) return;

    if (vif.mon_cb.out_valid === SP2V_HIGH && vif.mon_cb.out_ready !== SP2V_HIGH) bp++;

    if (vif.out_hs()) begin
      cur.state_out       = vif.mon_cb.state_out;
      cur.out_ready_delay = bp;
      finish(1'b0);
      return;
    end

    if (cur.err != ERR_NONE && ++err_wait > alert_wait_cycles) begin
      `uvm_info("MON", $sformatf("%s visto, mas sem alert em %0d ciclos",
                                 cur.err.name(), alert_wait_cycles), UVM_MEDIUM)
      finish(1'b0);
    end
  endfunction

  protected function aes_cipher_item capture_input();
    aes_cipher_item it = aes_cipher_item::type_id::create("mon_item");

    it.op          = vif.mon_cb.op;
    it.key_len     = vif.mon_cb.key_len;
    it.state_in    = vif.mon_cb.state_init;
    it.key         = vif.mon_cb.key_init;
    it.err         = ERR_NONE;
    it.alert       = 1'b0;
    it.state_out   = '0;
    // Mesma definicao de idle do driver
    it.idle_cycles = (gap > 0) ? gap - 1 : 0;

    // Prioridade igual a da FSM: clear > dec_key_gen > crypt
    if (vif.mon_cb.key_clear === 1'b1 && vif.mon_cb.data_out_clear === 1'b1) it.cmd = CMD_CLEAR_ALL;
    else if (vif.mon_cb.key_clear === 1'b1)                                  it.cmd = CMD_KEY_CLEAR;
    else if (vif.mon_cb.data_out_clear === 1'b1)                             it.cmd = CMD_DATA_OUT_CLEAR;
    else if (vif.mon_cb.dec_key_gen !== SP2V_LOW)                            it.cmd = CMD_DEC_KEY_GEN;
    else if (vif.mon_cb.crypt !== SP2V_LOW)                                  it.cmd = CMD_CRYPT;
    else begin
      it.cmd = CMD_CRYPT;
      if (vif.mon_cb.in_valid === SP2V_HIGH) begin
        it.err   = ERR_NO_CMD;
        err_wait = 0;
      end
    end

    gap = 0;
    return it;
  endfunction

  protected function bit is_invalid(sp2v_e v);
    return (v !== SP2V_HIGH) && (v !== SP2V_LOW);
  endfunction

  protected function aes_err_e find_invalid_sp2v(output logic [2:0] val);
    val = '0;
    if (is_invalid(vif.mon_cb.in_valid))    begin val = vif.mon_cb.in_valid;    return ERR_IN_VALID;    end
    if (is_invalid(vif.mon_cb.crypt))       begin val = vif.mon_cb.crypt;       return ERR_CRYPT;       end
    if (is_invalid(vif.mon_cb.dec_key_gen)) begin val = vif.mon_cb.dec_key_gen; return ERR_DEC_KEY_GEN; end
    if (is_invalid(vif.mon_cb.out_ready))   begin val = vif.mon_cb.out_ready;   return ERR_OUT_READY;   end
    return ERR_NONE;
  endfunction

  protected function void finish(bit alert);
    cur.alert = alert;
    num_items++;
    `uvm_info("MON", {"transacao observada:\n", cur.convert2string()}, UVM_HIGH)
    ap.write(cur);
    cur = null;
    gap = 0;
    bp  = 0;
  endfunction

endclass
