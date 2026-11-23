//Driver: item -> sinais (handshake sp2v, timing, injecao de erro)
// recebe abstraçao e gera ciclo a ciclo os sinais na interface
// unico que manda ao dut
class aes_cipher_driver extends uvm_driver #(aes_cipher_item);
  `uvm_component_utils(aes_cipher_driver) //driver parametrizado, tem simulação interna dif do item
  // recebe config do agente
  aes_cipher_agent_cfg  cfg;
  virtual aes_cipher_if vif; //virtual do cif

  int unsigned hs_timeout_cycles;
  int unsigned alert_wait_cycles;

  int unsigned num_driven; //numero de itens enviados, depois checa no monitor

  function new(string name = "aes_cipher_driver", uvm_component parent = null);
    super.new(name, parent); // env -> agent -> driver
  endfunction
  //build driver, necessita do agent
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (cfg == null) `uvm_fatal("NOCFG", "driver mp cfg: falta aes_cipher_agent")
    vif               = cfg.vif;
    hs_timeout_cycles = cfg.hs_timeout_cycles;
    alert_wait_cycles = cfg.alert_wait_cycles;
  endfunction

  virtual task run_phase(uvm_phase phase);
    drive_idle();                  // repouso ja no tempo 0 (sem X nos sp2v)
    wait (vif.rst_n === 1'b1);     // nada de handshake durante o reset
    @(vif.drv_cb);                 // alinha com a borda do clock

    forever begin
      seq_item_port.get_next_item(req);   // bloqueia ate uma sequence mandar
      `uvm_info("DRV", {"dirigindo:\n", req.convert2string()}, UVM_HIGH)
      drive_item(req);
      seq_item_port.item_done();          // libera o finish_item() da sequence
    end
  endtask
  //seta valores, se nao fica tudo XXX indefinido
  protected task drive_idle();
    vif.in_valid       = SP2V_LOW;
    vif.out_ready      = SP2V_LOW;
    vif.cfg_valid      = 1'b1;
    vif.op             = CIPH_FWD;
    vif.key_len        = AES_128;
    vif.crypt          = SP2V_LOW;
    vif.dec_key_gen    = SP2V_LOW;
    vif.key_clear      = 1'b0;
    vif.data_out_clear = 1'b0;
    vif.state_init     = '0;
    vif.key_init       = '0;
  endtask
  
  protected task drive_item(aes_cipher_item it);
    bit ok;

    it.alert     = 1'b0;
    it.state_out = '0;

    // DUT em ERROR e mata
    if (vif.drv_cb.alert === 1'b1) begin
      `uvm_warning("DRV", "DUT em ERROR (alert=1): descart")
      it.alert = 1'b1;
      return;
    end

    num_driven++;

    repeat (it.idle_cycles) @(vif.drv_cb);

    // op/key_len ficam estaveis ate o fim o DUT le durante toda a operacao
    vif.drv_cb.cfg_valid  <= 1'b1;
    vif.drv_cb.op         <= it.op;
    vif.drv_cb.key_len    <= it.key_len;
    vif.drv_cb.state_init <= it.state_in;
    vif.drv_cb.key_init   <= it.key;
    // DUT em fios
    drive_cmd(it.cmd);
    case (it.err)
      ERR_IN_VALID:    vif.drv_cb.in_valid    <= sp2v_e'(it.err_val);
      ERR_CRYPT:       vif.drv_cb.crypt       <= sp2v_e'(it.err_val);
      ERR_DEC_KEY_GEN: vif.drv_cb.dec_key_gen <= sp2v_e'(it.err_val);
      ERR_NO_CMD:      drive_no_cmd();
      default: ;
    endcase
    if (it.err != ERR_IN_VALID) vif.drv_cb.in_valid <= SP2V_HIGH;

    // Erro na entrada: segura 1 ciclo, solta e espera o alert
    if (it.err inside {ERR_IN_VALID, ERR_CRYPT, ERR_DEC_KEY_GEN, ERR_NO_CMD}) begin
      @(vif.drv_cb);
      release_input();
      wait_alert(it);
      return;
    end

    wait_in_hs(ok);
    release_input();               // in_valid e comandos voltam a LOW
    if (!ok) begin abort(it); return; end

    // delay=0: out_ready ja alto antes do resultado; delay=N: N ciclos de backpressure
    if (it.out_ready_delay > 0) begin
      wait_out_valid(ok);
      if (!ok) begin abort(it); return; end
      repeat (it.out_ready_delay - 1) @(vif.drv_cb);
    end

    if (it.err == ERR_OUT_READY) begin
      vif.drv_cb.out_ready <= sp2v_e'(it.err_val);
      @(vif.drv_cb);
      vif.drv_cb.out_ready <= SP2V_LOW;
      wait_alert(it);
      return;
    end
    vif.drv_cb.out_ready <= SP2V_HIGH;

    wait_out_hs(ok);
    vif.drv_cb.out_ready <= SP2V_LOW;
    if (!ok) begin abort(it); return; end

    // Resposta no proprio item, bom para o sequence
    it.state_out = vif.drv_cb.state_out;
    it.alert     = vif.drv_cb.alert;
  endtask

  protected task drive_cmd(aes_cmd_e cmd);
    vif.drv_cb.crypt          <= (cmd == CMD_CRYPT)       ? SP2V_HIGH : SP2V_LOW;
    vif.drv_cb.dec_key_gen    <= (cmd == CMD_DEC_KEY_GEN) ? SP2V_HIGH : SP2V_LOW;
    vif.drv_cb.key_clear      <= (cmd inside {CMD_KEY_CLEAR, CMD_CLEAR_ALL});
    vif.drv_cb.data_out_clear <= (cmd inside {CMD_DATA_OUT_CLEAR, CMD_CLEAR_ALL});
  endtask

  protected task drive_no_cmd();
    vif.drv_cb.crypt          <= SP2V_LOW;
    vif.drv_cb.dec_key_gen    <= SP2V_LOW;
    vif.drv_cb.key_clear      <= 1'b0;
    vif.drv_cb.data_out_clear <= 1'b0;
  endtask

  protected task release_input();
    vif.drv_cb.in_valid <= SP2V_LOW;
    drive_no_cmd();
  endtask

  protected task wait_in_hs(output bit ok);
    int unsigned n = 0;
    ok = 0;
    do begin
      @(vif.drv_cb);
      if (vif.drv_cb.alert === 1'b1) return;
      if (++n > hs_timeout_cycles) begin
        `uvm_error("DRV", $sformatf("timeout: handshake not execute %0d cycles", n))
        return;
      end
    end while (!(vif.drv_cb.in_valid === SP2V_HIGH && vif.drv_cb.in_ready === SP2V_HIGH));
    ok = 1;
  endtask

  protected task wait_out_hs(output bit ok);
    int unsigned n = 0;
    ok = 0;
    do begin
      @(vif.drv_cb);
      if (vif.drv_cb.alert === 1'b1) return;
      if (++n > hs_timeout_cycles) begin
        `uvm_error("DRV", $sformatf("timeout: out handshake not execute %0d cycles", n))
        return;
      end
    end while (!(vif.drv_cb.out_valid === SP2V_HIGH && vif.drv_cb.out_ready === SP2V_HIGH));
    ok = 1;
  endtask

  protected task wait_out_valid(output bit ok);
    int unsigned n = 0;
    ok = 0;
    do begin
      @(vif.drv_cb);
      if (vif.drv_cb.alert === 1'b1) return;
      if (++n > hs_timeout_cycles) begin
        `uvm_error("DRV", $sformatf("timeout: out_valid not edge %0d cycles", n))
        return;
      end
    end while (vif.drv_cb.out_valid !== SP2V_HIGH);
    ok = 1;
  endtask

  protected task wait_alert(aes_cipher_item it);
    repeat (alert_wait_cycles) begin
      @(vif.drv_cb);
      if (vif.drv_cb.alert === 1'b1) begin
        it.alert = 1'b1;
        `uvm_info("DRV", $sformatf("injection alert after injetin %s", it.err.name()), UVM_MEDIUM)
        return;
      end
    end
    `uvm_info("DRV", $sformatf("no alert %0d cycles afeter injection %s",
                               alert_wait_cycles, it.err.name()), UVM_MEDIUM)
  endtask

  protected task abort(aes_cipher_item it);
    release_input();
    vif.drv_cb.out_ready <= SP2V_LOW;
    it.alert = vif.drv_cb.alert;
    if (it.alert) `uvm_info("DRV", "transition crash: DUT high alert", UVM_MEDIUM)
  endtask

endclass
