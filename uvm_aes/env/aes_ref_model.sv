// aes_ref_model.sv: Ref model: DPI + estado da chave de decifra + predict()
import "DPI-C" function int aes_ref_crypt(input  int           decrypt,
                                          input  int           key_len,
                                          input  byte unsigned key[32],
                                          input  byte unsigned data_in[16],
                                          output byte unsigned data_out[16]);

typedef enum {
  PRED_CHECK,      // exp e valido: comparar com o DUT
  PRED_NO_RESULT,
  PRED_UNKNOWN     // o modelo nao consegue prever (ver "why")
} aes_pred_e;

class aes_ref_model extends uvm_object;
  `uvm_object_utils(aes_ref_model)

  bit       dec_key_valid;   // 0 apos reset e apos key_clear
  aes_key_t dec_key;         // chave (de CIFRA) usada no ultimo dec_key_gen
  key_len_e dec_key_len;     // key_len usado no ultimo dec_key_gen

  function new(string name = "aes_ref_model");
    super.new(name);
  endfunction

  virtual function aes_state_t cipher(ciph_op_e op, key_len_e kl, aes_key_t key,
                                      aes_state_t din);
    aes_block_t     bin, bout;
    aes_key_bytes_t kb;
    int             rc;

    bin = state_to_bytes(din);
    kb  = key_to_bytes(key);
    rc  = aes_ref_crypt((op == CIPH_INV), key_len_bytes(kl), kb, bin, bout);
    if (rc != 0)
      `uvm_fatal("REF", $sformatf("aes_ref_crypt retornou %0d (key_len=%s)", rc, kl.name()))
    return bytes_to_state(bout);
  endfunction

  // Atualiza o estado; decifra usa a chave do ultimo dec_key_gen, nao t.key
  virtual function aes_pred_e predict(aes_cipher_item t, output aes_state_t exp,
                                      output string why);
    exp = '0;
    why = "";

    case (t.cmd)
      CMD_DEC_KEY_GEN: begin
        dec_key_valid = 1'b1;
        dec_key       = t.key;
        dec_key_len   = t.key_len;
        why = "dec_key_gen: state_out nao e resultado";
        return PRED_NO_RESULT;
      end
      CMD_KEY_CLEAR, CMD_CLEAR_ALL: begin
        dec_key_valid = 1'b0;
        why = "key_clear: state_out nao e resultado";
        return PRED_NO_RESULT;
      end
      CMD_DATA_OUT_CLEAR: begin
        why = "data_out_clear: checado a parte (nao pode vazar o resultado anterior)";
        return PRED_NO_RESULT;
      end
      default: ;   // CMD_CRYPT: segue abaixo
    endcase

    if (t.op == CIPH_FWD) begin
      exp = cipher(CIPH_FWD, t.key_len, t.key, t.state_in);
      return PRED_CHECK;
    end

    if (t.op != CIPH_INV) begin
      why = $sformatf("op invalido (%b)", t.op);
      return PRED_UNKNOWN;
    end

    if (!dec_key_valid) begin
      why = "decifra sem dec_key_gen valido (reset ou key_clear depois do ultimo)";
      return PRED_UNKNOWN;
    end
    if (dec_key_len != t.key_len) begin
      why = $sformatf("decifra com key_len=%s, mas o dec_key_gen foi com %s",
                      t.key_len.name(), dec_key_len.name());
      return PRED_UNKNOWN;
    end
    exp = cipher(CIPH_INV, t.key_len, dec_key, t.state_in);
    return PRED_CHECK;
  endfunction

endclass
