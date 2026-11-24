// aes_base_test.sv: Teste base: cfgs + env, reset, IDLE, run_seqs(), PASSED/FAILED
class aes_base_test extends uvm_test;

  `uvm_component_utils(aes_base_test)

  virtual aes_cipher_if vif;

  aes_cipher_agent_cfg agent_cfg;
  aes_env_cfg          env_cfg;
  aes_env              env;
  aes_txn_logger       logger;   // TEMPORARIO (so imprime)

  time test_timeout = 1ms;

  function new(string name = "aes_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual aes_cipher_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "virtual interface 'vif' nao encontrada no config_db")
    end

    agent_cfg     = aes_cipher_agent_cfg::type_id::create("agent_cfg");
    agent_cfg.vif = vif;
    configure_agent(agent_cfg);

    env_cfg           = aes_env_cfg::type_id::create("env_cfg");
    env_cfg.agent_cfg = agent_cfg;
    configure_env(env_cfg);

    // env.sb/env.agent so existem apos o build_phase do env: mudar via cfg
    uvm_config_db#(aes_env_cfg)::set(this, "env", "cfg", env_cfg);

    env    = aes_env::type_id::create("env", this);
    logger = aes_txn_logger::type_id::create("logger", this);

    uvm_top.set_timeout(test_timeout, 0);
  endfunction

  virtual function void configure_agent(aes_cipher_agent_cfg cfg);
    cfg.is_active = UVM_ACTIVE;
  endfunction

  virtual function void configure_env(aes_env_cfg cfg);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    env.agent.ap.connect(logger.analysis_export);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "aes_base_test: inicio");

    @(posedge vif.rst_n);
    `uvm_info("TEST", "reset liberado", UVM_LOW)
    repeat (5) @(posedge vif.clk);
    check_idle();

    run_seqs();   // vazio aqui; os testes filhos colocam as sequences

    repeat (5) @(posedge vif.clk);
    phase.drop_objection(this, "aes_base_test: fim");
  endtask

  // Os testes filhos sobrescrevem
  virtual task run_seqs();
  endtask

  protected task check_idle();
    if (vif.mon_cb.in_ready !== SP2V_HIGH) begin
      `uvm_error("TEST", $sformatf("DUT nao esta em IDLE: in_ready=%0b", vif.mon_cb.in_ready))
    end else begin
      `uvm_info("TEST", "DUT em IDLE (in_ready=SP2V_HIGH)", UVM_LOW)
    end
    if (vif.mon_cb.alert !== 1'b0) begin
      `uvm_error("TEST", $sformatf("alert inesperado: alert=%0b", vif.mon_cb.alert))
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    int n_err = srv.get_severity_count(UVM_ERROR) + srv.get_severity_count(UVM_FATAL);
    super.report_phase(phase);
    if (n_err == 0) `uvm_info("RESULT", "*** TEST PASSED ***", UVM_NONE)
    else            `uvm_info("RESULT", $sformatf("*** TEST FAILED (%0d erros) ***", n_err), UVM_NONE)
  endfunction

endclass
