// aes_env.sv: Env: agent + scoreboard + coverage
class aes_env extends uvm_env;
  `uvm_component_utils(aes_env)

  aes_env_cfg      cfg;

  aes_cipher_agent agent;
  aes_scoreboard   sb;    // null se cfg.has_scoreboard == 0
  aes_coverage     cov;   // null se cfg.has_coverage   == 0

  function new(string name = "aes_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(aes_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "aes_env_cfg 'cfg' not found in config_db")
    if (cfg.agent_cfg == null)
      `uvm_fatal("NOCFG", "cfg.agent_cfg == null: the test do cfg agent")

    // O env repassa o cfg do agent um nivel abaixo
    uvm_config_db#(aes_cipher_agent_cfg)::set(this, "agent", "cfg", cfg.agent_cfg);

    agent = aes_cipher_agent::type_id::create("agent", this);
    if (cfg.has_scoreboard) begin
      sb = aes_scoreboard::type_id::create("sb", this);
      sb.min_checked = cfg.min_checked;
    end
    if (cfg.has_coverage)
      cov = aes_coverage::type_id::create("cov", this);

    `uvm_info("ENV", {"cfg: ", cfg.convert2string()}, UVM_MEDIUM)
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (sb  != null) agent.ap.connect(sb.item_imp);
    if (cov != null) agent.ap.connect(cov.analysis_export);
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (agent.drv == null) return;   // agent passivo: nao ha driver para comparar
    if (agent.mon.num_items != agent.drv.num_driven)
      `uvm_error("CHECK", $sformatf("driver do %0d itens, monitor read %0d transactions",
                                    agent.drv.num_driven, agent.mon.num_items))
    else
      `uvm_info("CHECK", $sformatf("driver and monitor same: %0d transactions", agent.mon.num_items), UVM_LOW)
  endfunction

endclass
