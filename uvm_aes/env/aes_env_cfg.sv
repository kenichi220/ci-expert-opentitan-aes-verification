// config do env, junta agent ap -> socreboard and cov
class aes_env_cfg extends uvm_object;
  `uvm_object_utils(aes_env_cfg)

  aes_cipher_agent_cfg agent_cfg;

  bit has_scoreboard = 1;
  bit has_coverage   = 1;

  // Via cfg: no build_phase do teste o sb ainda nao existe
  int unsigned min_checked = 0;

  function new(string name = "aes_env_cfg");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("has_scoreboard=%0b has_coverage=%0b min_checked=%0d\n  agent_cfg: %s",
                     has_scoreboard, has_coverage, min_checked,
                     (agent_cfg == null) ? "null" : agent_cfg.convert2string());
  endfunction
endclass
