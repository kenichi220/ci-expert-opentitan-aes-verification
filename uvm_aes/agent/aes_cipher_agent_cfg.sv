// cfg pro driver
class aes_cipher_agent_cfg extends uvm_object;
  `uvm_object_utils(aes_cipher_agent_cfg)

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  virtual aes_cipher_if vif;

  int unsigned hs_timeout_cycles = 1000;   // limite de espera por handshake
  int unsigned alert_wait_cycles = 30;     // espera pelo alert apos um erro

  function new(string name = "aes_cipher_agent_cfg");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string vif_s = "ok";
    if (vif == null) vif_s = "null";
    return $sformatf("is_active=%s vif=%s hs_timeout_cycles=%0d alert_wait_cycles=%0d",
                     is_active.name(), vif_s, hs_timeout_cycles, alert_wait_cycles);
  endfunction
endclass
