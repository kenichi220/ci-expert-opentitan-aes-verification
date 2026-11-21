# Dependências do RTL (vendorizadas do OpenTitan)

Cópia **sem modificação** dos arquivos que o `aes_cipher_core` precisa e que ficam fora de
`aes/rtl/`. O objetivo é compilar o `uvm_aes` sem fusesoc/dvsim/ot-env.

- Origem: árvore OpenTitan em `fac/ci/tmp/opentitan`, commit `7ea7d36` (2026-08-25).
  O `aes/rtl` dessa árvore é idêntico ao `aes/rtl` deste repo (conferido com `diff -r`).
- Licença: Apache-2.0 (ver `LICENSE` e os cabeçalhos dos arquivos).
- `prim_generic/`: implementações genéricas (simulação) de `prim_flop`, `prim_buf`...
  No fluxo oficial, o fusesoc escolhe essas pelo "mapping" `prim_generic`.
- `edn_pkg`, `csrng_*`, `entropy_src_pkg`: só pacotes de tipos; o cipher core usa
  `edn_pkg::ENDPOINT_BUS_WIDTH` na largura da porta de entropia.

Se o RTL do AES for atualizado, refazer a cópia a partir do mesmo commit do OpenTitan.
