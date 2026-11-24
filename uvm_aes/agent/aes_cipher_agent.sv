class aes_cipher_agent extends uvm_agent;
  `uvm_component_utils(aes_cipher_agent)

  aes_cipher_agent_cfg cfg;

  aes_cipher_sequencer sqr;   // null se passivo
  aes_cipher_driver    drv;   // null se passivo
  aes_cipher_monitor   mon;

  uvm_analysis_port #(aes_cipher_item) ap;

  function new(string name = "aes_cipher_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(aes_cipher_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "aes_cipher_agent_cfg 'cfg' not found in config_db")
    if (cfg.vif == null)
      `uvm_fatal("NOVIF", "cfg.vif == null: test/env make interface")

    is_active = cfg.is_active;

    mon = aes_cipher_monitor::type_id::create("mon", this);
    mon.cfg = cfg;

    if (get_is_active() == UVM_ACTIVE) begin
      sqr = aes_cipher_sequencer::type_id::create("sqr", this);
      drv = aes_cipher_driver::type_id::create("drv", this);
      drv.cfg = cfg;
    end

    `uvm_info("AGENT", {"cfg: ", cfg.convert2string()}, UVM_MEDIUM)
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ap = mon.ap;
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
