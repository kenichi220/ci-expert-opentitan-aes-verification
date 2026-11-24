// aes_item_test.sv: Teste do item sem DUT (conversao, constraints, compare)
class aes_item_test extends aes_base_test;
  `uvm_component_utils(aes_item_test)

  function new(string name = "aes_item_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    check_conversion();
    check_randomization();
    check_err_injection();
    check_copy_compare();
    phase.drop_objection(this);
  endtask

  function void check_conversion();
    aes_block_t     pt, pt_back;
    aes_key_bytes_t kb;
    aes_state_t     s;
    aes_key_t       k;

    foreach (pt[i]) pt[i] = 8'h11 * i;   // 00 11 22 ... ff
    foreach (kb[i]) kb[i] = i;           // 00 01 02 ... 1f

    s = bytes_to_state(pt);
    if (s[0][0] !== 8'h00 || s[1][0] !== 8'h11 || s[0][1] !== 8'h44 || s[3][3] !== 8'hff)
      `uvm_error("CONV", $sformatf("bytes_to_state errado: %h", s))
    pt_back = state_to_bytes(s);
    if (pt_back != pt) `uvm_error("CONV", "state_to_bytes(bytes_to_state(x)) != x")
    if (state_to_hex(s) != "00112233445566778899aabbccddeeff")
      `uvm_error("CONV", $sformatf("state_to_hex = %s", state_to_hex(s)))

    k = bytes_to_key(kb);
    if (k[0] !== 32'h03020100 || k[7] !== 32'h1f1e1d1c)
      `uvm_error("CONV", $sformatf("bytes_to_key errado: k[0]=%h k[7]=%h", k[0], k[7]))
    if (key_to_hex(k, AES_128) != "000102030405060708090a0b0c0d0e0f")
      `uvm_error("CONV", $sformatf("key_to_hex = %s", key_to_hex(k, AES_128)))

    `uvm_info("CONV", "conversao bytes <-> RTL OK", UVM_LOW)
  endfunction

  function void check_randomization();
    aes_cipher_item item = aes_cipher_item::type_id::create("item");
    int n = 2000;
    int cnt_cmd[aes_cmd_e];
    int cnt_kl[key_len_e];
    int cnt_b2b = 0;

    repeat (n) begin
      if (!item.randomize()) `uvm_fatal("RAND", "randomize() falhou")
      cnt_cmd[item.cmd]++;
      cnt_kl[item.key_len]++;
      if (item.idle_cycles == 0) cnt_b2b++;
      if (item.err != ERR_NONE)        `uvm_error("RAND", "soft err==ERR_NONE nao respeitado")
      if (item.idle_cycles > 10)       `uvm_error("RAND", "idle_cycles fora do range")
      if (item.out_ready_delay > 20)   `uvm_error("RAND", "out_ready_delay fora do range")
    end

    foreach (cnt_cmd[c])
      `uvm_info("RAND", $sformatf("%-18s %5.1f%%", c.name(), 100.0*cnt_cmd[c]/n), UVM_LOW)
    foreach (cnt_kl[k])
      `uvm_info("RAND", $sformatf("%-18s %5.1f%%", k.name(), 100.0*cnt_kl[k]/n), UVM_LOW)
    `uvm_info("RAND", $sformatf("back-to-back       %5.1f%%", 100.0*cnt_b2b/n), UVM_LOW)

    if (!item.randomize() with { cmd == CMD_CRYPT; op == CIPH_INV; key_len == AES_256; })
      `uvm_fatal("RAND", "randomize() with {...} falhou")
    `uvm_info("RAND", {"exemplo com inline constraint:\n", item.convert2string()}, UVM_LOW)
  endfunction

  function void check_err_injection();
    aes_cipher_item item = aes_cipher_item::type_id::create("item_err");
    repeat (200) begin
      if (!item.randomize() with { err == ERR_CRYPT; })
        `uvm_fatal("ERR", "randomize() com err falhou")
      if (item.err_val inside {SP2V_HIGH, SP2V_LOW})
        `uvm_error("ERR", $sformatf("err_val valido gerado: %03b", item.err_val))
      if (item.cmd != CMD_CRYPT)
        `uvm_error("ERR", "c_err_cmd nao respeitado")
    end
    `uvm_info("ERR", {"injecao de erro OK, exemplo:\n", item.convert2string()}, UVM_LOW)
  endfunction

  function void check_copy_compare();
    aes_cipher_item a = aes_cipher_item::type_id::create("a");
    aes_cipher_item b;
    void'(a.randomize());
    a.state_out = '0;
    a.alert     = 1'b0;

    if (!$cast(b, a.clone())) `uvm_fatal("CMP", "clone() nao retornou aes_cipher_item")
    if (!a.compare(b)) `uvm_error("CMP", "clone deveria ser igual ao original")

    b.out_ready_delay = a.out_ready_delay + 1;   // timing: nao entra no compare
    if (!a.compare(b)) `uvm_error("CMP", "timing diferente nao deveria quebrar compare")

    b.state_out[0][0] = ~a.state_out[0][0];      // resultado diferente
    if (a.compare(b)) `uvm_error("CMP", "state_out diferente deveria quebrar compare")

    `uvm_info("CMP", "copy/clone/compare OK", UVM_LOW)
  endfunction

endclass
