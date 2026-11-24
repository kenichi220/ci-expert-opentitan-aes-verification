typedef enum {
  K_ENC,    // CMD_CRYPT, CIPH_FWD
  K_DEC,    // CMD_CRYPT, CIPH_INV
  K_DKG,    // CMD_DEC_KEY_GEN
  K_KCLR,   // CMD_KEY_CLEAR
  K_DCLR,   // CMD_DATA_OUT_CLEAR
  K_ACLR    // CMD_CLEAR_ALL
} aes_kind_e;

typedef enum {
  DEC_NO_KEY,        // sem dec_key_gen desde o reset / ultimo key_clear
  DEC_KL_DIFF,       // dec_key_gen foi com outro key_len
  DEC_SAME_KEY,      // key_init == chave do dec_key_gen
  DEC_OTHER_KEY_INIT
} aes_dec_ctx_e;

typedef enum {
  KEY_FIRST,
  KEY_SAME,
  KEY_NEW_SAME_KL,
  KEY_NEW_KL
} aes_key_chg_e;

// Estado proprio coverage independente do scoreboard
class aes_coverage extends uvm_subscriber #(aes_cipher_item);
  `uvm_component_utils(aes_coverage)

  protected bit       dec_valid;
  protected string    dec_key_s;     // chave do dec_key_gen (hex, so bytes usados)
  protected key_len_e dec_kl;
  protected bit       key_seen;
  protected string    last_key_s;    // ultima chave carregada (cifra ou dec_key_gen)
  protected key_len_e last_kl;

  int unsigned n_sampled;
  int unsigned n_err_sampled;

  covergroup cg_crypt with function sample(ciph_op_e op, key_len_e kl,
                                           aes_dec_ctx_e dec_ctx, aes_key_chg_e key_chg);
    option.per_instance = 1;

    cp_op: coverpoint op;
    cp_kl: coverpoint kl;

    x_op_kl: cross cp_op, cp_kl;

    cp_dec_ctx: coverpoint dec_ctx iff (op == CIPH_INV);

    cp_key_chg: coverpoint key_chg iff (op == CIPH_FWD) {
      ignore_bins first = {KEY_FIRST};
    }
  endgroup

  covergroup cg_seq with function sample(aes_kind_e kind);
    option.per_instance = 1;

    cp_kind: coverpoint kind;

    // (A => B): A numa amostra e B na seguinte
    cp_trans: coverpoint kind {
      bins enc_enc   = (K_ENC  => K_ENC);   // mesma op seguida
      bins dec_dec   = (K_DEC  => K_DEC);
      bins enc_dec   = (K_ENC  => K_DEC);   // troca de direcao
      bins dec_enc   = (K_DEC  => K_ENC);
      bins dkg_dec   = (K_DKG  => K_DEC);   // decifra "classica"
      bins dkg_enc   = (K_DKG  => K_ENC);   // cifra logo apos gerar chave de decifra
      bins dkg_dkg   = (K_DKG  => K_DKG);
      bins kclr_dec  = (K_KCLR => K_DEC);   // decifra apos key_clear
      bins kclr_enc  = (K_KCLR => K_ENC);
      bins kclr_dkg  = (K_KCLR => K_DKG);   // gerar chave de novo apos limpar
      bins dclr_enc  = (K_DCLR => K_ENC);   // nova cifra apos limpar a saida
      bins aclr_enc  = (K_ACLR => K_ENC);
      bins enc_dclr  = (K_ENC  => K_DCLR);  // limpar logo apos um resultado
    }
  endgroup

  covergroup cg_timing with function sample(aes_kind_e kind, int unsigned idle,
                                            int unsigned bp);
    option.per_instance = 1;

    cp_idle: coverpoint idle {
      bins b2b   = {0};          // in_valid logo no ciclo seguinte
      bins curto = {[1:3]};
      bins longo = {[4:$]};      // $ = maior valor possivel
    }
    cp_bp: coverpoint bp {
      bins sem   = {0};
      bins curto = {[1:5]};
      bins longo = {[6:$]};
    }
    cp_kind: coverpoint kind {
      bins enc   = {K_ENC};
      bins dec   = {K_DEC};
      bins outro = {K_DKG, K_KCLR, K_DCLR, K_ACLR};
    }
    x_kind_bp: cross cp_kind, cp_bp;
  endgroup

  covergroup cg_err with function sample(aes_err_e err);
    option.per_instance = 1;
    cp_err: coverpoint err {
      ignore_bins none = {ERR_NONE};
    }
  endgroup

  function new(string name = "aes_coverage", uvm_component parent = null);
    super.new(name, parent);
    // Covergroup embutido: criado no construtor
    cg_crypt  = new();
    cg_seq    = new();
    cg_timing = new();
    cg_err    = new();
    cg_crypt.set_inst_name({get_full_name(), ".cg_crypt"});
    cg_seq.set_inst_name({get_full_name(), ".cg_seq"});
    cg_timing.set_inst_name({get_full_name(), ".cg_timing"});
    cg_err.set_inst_name({get_full_name(), ".cg_err"});
  endfunction

  virtual function void write(aes_cipher_item t);
    aes_kind_e    kind;
    aes_dec_ctx_e dec_ctx = DEC_NO_KEY;
    aes_key_chg_e key_chg = KEY_FIRST;
    string        key_s;

    if (t.err != ERR_NONE) begin
      n_err_sampled++;
      cg_err.sample(t.err);
      return;     // DUT fica em ERROR: nao ha "proxima transacao"
    end

    n_sampled++;
    kind  = kind_of(t);
    key_s = key_to_hex(t.key, t.key_len);

    case (kind)
      K_ENC: begin
        key_chg = key_change(key_s, t.key_len);
        cg_crypt.sample(t.op, t.key_len, dec_ctx, key_chg);
      end
      K_DEC: begin
        if (!dec_valid)                dec_ctx = DEC_NO_KEY;
        else if (dec_kl != t.key_len)  dec_ctx = DEC_KL_DIFF;
        else if (dec_key_s == key_s)   dec_ctx = DEC_SAME_KEY;
        else                           dec_ctx = DEC_OTHER_KEY_INIT;
        cg_crypt.sample(t.op, t.key_len, dec_ctx, key_chg);
      end
      K_DKG: begin
        void'(key_change(key_s, t.key_len));
        dec_valid = 1'b1;
        dec_key_s = key_s;
        dec_kl    = t.key_len;
      end
      K_KCLR, K_ACLR: dec_valid = 1'b0;
      default: ;
    endcase

    cg_seq.sample(kind);
    cg_timing.sample(kind, t.idle_cycles, t.out_ready_delay);
  endfunction

  protected function aes_kind_e kind_of(aes_cipher_item t);
    case (t.cmd)
      CMD_CRYPT:          return (t.op == CIPH_INV) ? K_DEC : K_ENC;
      CMD_DEC_KEY_GEN:    return K_DKG;
      CMD_KEY_CLEAR:      return K_KCLR;
      CMD_DATA_OUT_CLEAR: return K_DCLR;
      default:            return K_ACLR;
    endcase
  endfunction

  protected function aes_key_chg_e key_change(string key_s, key_len_e kl);
    aes_key_chg_e r;
    if (!key_seen)              r = KEY_FIRST;
    else if (kl != last_kl)     r = KEY_NEW_KL;
    else if (key_s != last_key_s) r = KEY_NEW_SAME_KL;
    else                        r = KEY_SAME;
    key_seen   = 1'b1;
    last_key_s = key_s;
    last_kl    = kl;
    return r;
  endfunction

  virtual function void report_phase(uvm_phase phase);
    string s;
    super.report_phase(phase);
    s = $sformatf("\n  itens      : %0d (+ %0d with error)", n_sampled, n_err_sampled);
    s = {s, $sformatf("\n  cg_crypt   %6.2f %%", cg_crypt.get_inst_coverage())};
    s = {s, $sformatf("\n    op x key_len        %6.2f %%", cg_crypt.x_op_kl.get_inst_coverage())};
    s = {s, $sformatf("\n    contex decipher    %6.2f %%", cg_crypt.cp_dec_ctx.get_inst_coverage())};
    s = {s, $sformatf("\n    switch key     %6.2f %%", cg_crypt.cp_key_chg.get_inst_coverage())};
    s = {s, $sformatf("\n  cg_seq     %6.2f %%", cg_seq.get_inst_coverage())};
    s = {s, $sformatf("\n    types               %6.2f %%", cg_seq.cp_kind.get_inst_coverage())};
    s = {s, $sformatf("\n    transations         %6.2f %%", cg_seq.cp_trans.get_inst_coverage())};
    s = {s, $sformatf("\n  cg_timing  %6.2f %%", cg_timing.get_inst_coverage())};
    s = {s, $sformatf("\n    type x backpressure %6.2f %%", cg_timing.x_kind_bp.get_inst_coverage())};
    s = {s, $sformatf("\n  cg_err     %6.2f %%", cg_err.get_inst_coverage())};
    `uvm_info("COV", {"resumecoverage:", s}, UVM_LOW)
  endfunction

endclass
