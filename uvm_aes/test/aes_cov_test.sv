// aes_cov_test.sv: Trafego aleatorio longo (+N=, default 500)
class aes_cov_test extends aes_base_test;
  `uvm_component_utils(aes_cov_test)

  int unsigned n_items = 500;

  function new(string name = "aes_cov_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    void'($value$plusargs("N=%d", n_items));
    // Antes do super: o base test chama set_timeout() no build_phase
    test_timeout = 10ms;
    super.build_phase(phase);
    env_cfg.min_checked = n_items / 4;
  endfunction

  virtual task run_seqs();
    aes_cipher_rand_seq rs = aes_cipher_rand_seq::type_id::create("rs");
    rs.num_items = n_items;
    `uvm_info("TEST", $sformatf("rand_seq com %0d itens", n_items), UVM_LOW)
    rs.start(env.agent.sqr);
  endtask

endclass
