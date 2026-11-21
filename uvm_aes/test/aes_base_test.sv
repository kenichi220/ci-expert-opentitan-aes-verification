class aes_base_test extends uvm_test;

  `uvm_component_utils(aes_base_test)

  virtual aes_cipher_if vif;

  time test_timeout = 1ms;

  function new(string name = "aes_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual aes_cipher_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "virtual interface 'vif' nao encontrada no config_db")
    end

    uvm_top.set_timeout(test_timeout, 0);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "aes_base_test: inicio");

    drive_idle();  // next to driver

    @(posedge vif.rst_n);
    `uvm_info("TEST", "reset liberado", UVM_LOW)
    repeat (5) @(posedge vif.clk);

    if (vif.mon_cb.in_ready !== SP2V_HIGH) begin
      `uvm_error("TEST", $sformatf("DUT nao esta em IDLE: in_ready=%0b", vif.mon_cb.in_ready))
    end else begin
      `uvm_info("TEST", "DUT em IDLE (in_ready=SP2V_HIGH)", UVM_LOW)
    end
    if (vif.mon_cb.alert !== 1'b0) begin
      `uvm_error("TEST", $sformatf("alert inesperado: alert=%0b", vif.mon_cb.alert))
    end

    phase.drop_objection(this, "aes_base_test: fim");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    int n_err = srv.get_severity_count(UVM_ERROR) + srv.get_severity_count(UVM_FATAL);
    super.report_phase(phase);
    if (n_err == 0) `uvm_info("RESULT", "*** TEST PASSED ***", UVM_NONE)
    else            `uvm_info("RESULT", $sformatf("*** TEST FAILED (%0d erros) ***", n_err), UVM_NONE)
  endfunction

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

endclass
