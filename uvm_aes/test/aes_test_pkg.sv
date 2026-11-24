// aes_test_pkg.sv: Pacote dos testes
package aes_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import aes_pkg::*;
  import aes_cipher_agent_pkg::*;
  import aes_env_pkg::*;

  `include "aes_txn_logger.sv"
  `include "aes_base_test.sv"
  `include "aes_item_test.sv"
  `include "aes_drv_test.sv"
  `include "aes_agent_test.sv"
  `include "aes_ref_test.sv"
  `include "aes_sb_test.sv"
  `include "aes_cov_test.sv"

endpackage
