// aes_agent_test.sv: Agent passivo extra: tem que ver as mesmas transacoes do ativo
class aes_agent_test extends aes_drv_test;
  `uvm_component_utils(aes_agent_test)

  aes_cipher_agent_cfg pas_cfg;
  aes_cipher_agent     agent_pas;
  aes_txn_logger       logger_pas;

  function new(string name = "aes_agent_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);   // cria agent (ativo) + logger, como sempre

    pas_cfg           = aes_cipher_agent_cfg::type_id::create("pas_cfg");
    pas_cfg.vif       = vif;
    pas_cfg.is_active = UVM_PASSIVE;
    uvm_config_db#(aes_cipher_agent_cfg)::set(this, "agent_pas", "cfg", pas_cfg);

    agent_pas  = aes_cipher_agent::type_id::create("agent_pas", this);
    logger_pas = aes_txn_logger::type_id::create("logger_pas", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent_pas.ap.connect(logger_pas.analysis_export);
  endfunction

  virtual function void check_phase(uvm_phase phase);
    int unsigned n_diff = 0;
    super.check_phase(phase);

    if (agent_pas.drv != null || agent_pas.sqr != null)
      `uvm_error("PASSIVE", "agent passivo nao deveria ter driver/sequencer")

    if (logger_pas.num_items != logger.num_items) begin
      `uvm_error("PASSIVE", $sformatf("monitor ativo viu %0d transacoes, passivo viu %0d",
                                      logger.num_items, logger_pas.num_items))
      return;
    end
    foreach (logger.items[i]) begin
      if (!logger.items[i].compare(logger_pas.items[i])) begin
        n_diff++;
        `uvm_error("PASSIVE", $sformatf("transacao #%0d difere:\n ativo  : %s\n passivo: %s", i + 1,
                   logger.items[i].convert2string(), logger_pas.items[i].convert2string()))
      end
    end
    if (n_diff == 0)
      `uvm_info("PASSIVE", $sformatf("agent passivo viu as mesmas %0d transacoes do ativo",
                                     logger.num_items), UVM_LOW)
  endfunction
endclass
