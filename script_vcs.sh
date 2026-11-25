#!/bin/bash
# Compila e roda o testbench_minimo.sv (aes_cipher_core) com o RTL interno
# de aes/rtl e as dependencias minimas do OpenTitan em uvm_aes/deps/opentitan.

export TMPDIR=/tmp

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AES_RTL="$ROOT/aes/rtl"
OT_DEPS="$ROOT/uvm_aes/deps/opentitan"
OUT="$ROOT/sim_minimo"

mkdir -p "$OUT"
cd "$OUT" || exit 1

echo "Compilando com Synopsys VCS..."

vcs -sverilog -full64 -debug_access+all -kdb -lca \
  -timescale=1ns/1ps \
  -xlrm uniq_prior_final \
  -top tb_minimo_vcs \
  +incdir+"$OT_DEPS/prim/rtl" \
  "$OT_DEPS/prim/rtl/prim_util_pkg.sv" \
  "$OT_DEPS/prim/rtl/prim_trivium_pkg.sv" \
  "$OT_DEPS/entropy_src/rtl/entropy_src_pkg.sv" \
  "$OT_DEPS/csrng/rtl/csrng_reg_pkg.sv" \
  "$OT_DEPS/csrng/rtl/csrng_pkg.sv" \
  "$OT_DEPS/edn/rtl/edn_pkg.sv" \
  "$AES_RTL/aes_reg_pkg.sv" \
  "$AES_RTL/aes_pkg.sv" \
  "$AES_RTL/aes_sbox_canright_pkg.sv" \
  "$OT_DEPS/prim_generic/rtl/prim_buf.sv" \
  "$OT_DEPS/prim_generic/rtl/prim_flop.sv" \
  "$OT_DEPS/prim_generic/rtl/prim_flop_en.sv" \
  "$OT_DEPS/prim_generic/rtl/prim_xor2.sv" \
  "$OT_DEPS/prim/rtl/prim_sec_anchor_buf.sv" \
  "$OT_DEPS/prim/rtl/prim_sparse_fsm_flop.sv" \
  "$OT_DEPS/prim/rtl/prim_trivium.sv" \
  "$AES_RTL/aes_sel_buf_chk.sv" \
  "$AES_RTL/aes_prng_masking.sv" \
  "$AES_RTL/aes_sbox_lut.sv" \
  "$AES_RTL/aes_sbox_canright.sv" \
  "$AES_RTL/aes_sbox_canright_masked.sv" \
  "$AES_RTL/aes_sbox_canright_masked_noreuse.sv" \
  "$AES_RTL/aes_sbox_dom.sv" \
  "$AES_RTL/aes_sbox.sv" \
  "$AES_RTL/aes_sub_bytes.sv" \
  "$AES_RTL/aes_shift_rows.sv" \
  "$AES_RTL/aes_mix_single_column.sv" \
  "$AES_RTL/aes_mix_columns.sv" \
  "$AES_RTL/aes_key_expand.sv" \
  "$AES_RTL/aes_cipher_control_fsm.sv" \
  "$AES_RTL/aes_cipher_control_fsm_p.sv" \
  "$AES_RTL/aes_cipher_control_fsm_n.sv" \
  "$AES_RTL/aes_cipher_control.sv" \
  "$AES_RTL/aes_cipher_core.sv" \
  "$ROOT/testbench_minimo.sv" \
  -l build.log

if [ $? -eq 0 ]; then
    echo "Compilação bem-sucedida. Rodando simulação..."
    ./simv -l sim.log
else
    echo "Erro na compilação. Veja $OUT/build.log e corrija o código."
    exit 1
fi
