# Plano — TB UVM próprio para o AES (Trilha C: aes_ctr)

Ambiente: OpenTitan + Synopsys VCS, cluster PGMicro/UFRGS.

---

## Setup de sessão (relembrando)

```bash
source ~/ot-env.sh     # REPO_TOP, venv, module load vcs/verdi
```

Conteúdo do `~/ot-env.sh` (cluster, `$HOME = /home/ciexpert/kenichi.brumati`):

```bash
export REPO_TOP=$HOME/ci-expert/verif/opentitan
export SCRATCH_ROOT=$HOME/scratch

# limpa proxies inválidos herdados do shell
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

# ferramentas Synopsys
module load vcs/W-2024.09-SP2-3
module load verdi/W-2024.09-SP2-6
# module load designcompiler/W-2024.09-SP5-4   # descomenta p/ síntese

# python venv do repo
mkdir -p "$SCRATCH_ROOT"
cd "$REPO_TOP" || return 1
source "$REPO_TOP/.venv/bin/activate" || return 1

echo "REPO_TOP  = $REPO_TOP"
echo "python    = $(python -V 2>&1)"
echo "dvsim     = $(command -v dvsim || echo AUSENTE)"
echo "vcs       = $(command -v vcs   || echo AUSENTE)"
echo "verdi     = $(command -v verdi || echo AUSENTE)"
echo "licença   = ${SNPSLMD_LICENSE_FILE:-NAO-SETADA}"
```

O `my_dv/` precisa estar dentro desse clone (`$REPO_TOP/hw/ip/aes/my_dv`). O `Makefile`
usa `REPO_TOP ?=`, então o valor exportado pelo script tem precedência.
O clone local (notebook) fica em `~/fac/ci/opentitan`; sincronizar com `rsync` antes de rodar.

Rodar sempre com `source ~/ot-env.sh` (não `./ot-env.sh` — subshell não persiste).

Sanity do ambiente, TB oficial do repo:

```bash
dvsim $REPO_TOP/hw/ip/aes/dv/aes_masked_sim_cfg.hjson --tool vcs -i aes_smoke
```

---

## Escolha do DUT (Trilha C)

O `aes` top tem TL-UL, EDN, alertas, keymgr sideload e shadow reset (`rtl/aes.sv:42-71`).
Escrever agente TL-UL do zero é projeto por si só.

Versão anterior deste plano usava `aes_cipher_core` (Trilha A). Backup em
`~/fac/ci/backup_my_dv_cipher_core/`.

Candidatos da Trilha C (ver `~/fac/ci/aes_rtl_ordem_leitura.tex`):

| Alvo | Interface | Esforço | Quando |
|---|---|---|---|
| `aes_ctr` (+ `aes_ctr_fsm{,_p,_n}`) | `incr_i/ready_o`, `inc32_i`, `ctr_i/ctr_o/ctr_we_o`, `alert_o` (`rtl/aes_ctr.sv:10-23`) | pequeno, modelo trivial | **agora** |
| `aes_ghash_wrap` (+ `aes_ghash`) | valid/ready, GF(2^128), mascarado | grande, precisa modelo GHASH | depois do CTR |
| `aes_ctrl_reg_shadowed` / `_gcm_` | escrita dupla, erros de update/storage | médio | depois |
| `aes_prng_clearing` | req/ack de entropia, reseed | médio, checar reseed, não valor | depois |
| `aes_reg_top` | TL-UL + RAL | reusar `hw/dv/sv/tl_agent` + `csr_testplan` | no fim, já no top |

Decisão: `aes_ctr`. Handshake sp2v simples, sem parâmetros, modelo de referência é `+1`.

### Como o `aes_ctr` funciona (resumo p/ o TB)

- **Não guarda o contador.** Lê `ctr_i` (= `iv_q` do `aes_core`) e devolve `ctr_o` + `ctr_we_o`.
  O TB precisa do registrador IV no harness (`tb.sv`, cópia de `aes_core.sv:374`).
- 128 bits = 8 slices de 16 bits (`SliceSizeCtr=16`, `NumSlicesCtr=8`, `aes_pkg.sv:18-23`).
- `CTR_IDLE` (`ready=HIGH`) + `incr=HIGH` → `CTR_INCR` por 8 ciclos, 1 slice por ciclo,
  carry propagado em `ctr_carry_q` → volta a `CTR_IDLE` (`aes_ctr_fsm.sv:63-97`).
- `inc32=HIGH` (GCM): carry zerado após slice 1 → só os 32 bits baixos incrementam
  (wrap em 2^32). `inc32=LOW` (CTR): inc128.
- Ordem de bytes: contador big-endian; byte 0 de `ctr_i` é o mais significativo
  (`aes_rev_order_byte`, `aes_ctr.sv:26,78,214`).
- `incr` no RTL real é pulso de 1 ciclo (`CTRL_LOAD`, `aes_control_fsm.sv:601`).
- Erros: `inc32_i`/`incr_i` com valor sp2v inválido → `sp_enc_err`; rails `_p`/`_n`
  divergindo → `mr_err`. Ambos → `CTR_ERROR` terminal, `alert_o=1`.

---

## Fase 1 — estrutura de diretório

```
my_dv/
├── tb/aes_ctr_if.sv          interface + clocking blocks + porta de carga do IV
├── tb/tb.sv                  top: clk/rst, registrador IV, DUT, config_db
├── agent/ctr_item.sv         transação: inc32, load_iv, ctr_in, ctr_out
├── agent/ctr_driver.sv       carrega IV, espera ready, pulsa incr
├── agent/ctr_monitor.sv      amostra incr aceito E fim do incremento
├── agent/ctr_sequencer.sv    typedef de uvm_sequencer
├── agent/ctr_agent.sv        + ctr_agent_cfg.sv
├── env/ctr_scoreboard.sv     compara DUT vs modelo SV (+1 com byte swap)
├── env/ctr_cov.sv            covergroups
├── env/my_ctr_env.sv         + my_ctr_env_cfg.sv
├── seq_lib/ctr_base_seq.sv   + ctr_rand_seq.sv
├── tests/ctr_base_test.sv    + ctr_smoke_test.sv
├── my_aes_ctr_pkg.sv         `include de tudo, na ordem certa
└── my_aes_ctr_sim.core       fusesoc (depende de lowrisc:ip:aes)
```

---

## Fase 2 — file list e primeiro build

```bash
cd $REPO_TOP/hw/ip/aes/my_dv
make setup     # fusesoc gera build/ctr/fusesoc-work/lowrisc_dv_my_aes_ctr_sim_0.1.scr
make build
make run TEST=ctr_smoke_test SEED=1 WAVES=1
```

Sem DPI/`-lcrypto`: modelo é SV puro.

---

## Fase 3 — ordem de construção

Cada passo tem que rodar antes do próximo:

1. **`tb.sv` + clock/reset.** Soltar reset; confirmar `ready=SP2V_HIGH` nas waves.
2. **UVM vazio.** Test só com `#1us`. Valida que a UVM linkou.
3. **Driver burro.** Carrega `ctr_in = 0`, pulsa `incr`, `$display` de `ctr_i` após `ready`.
   Ver nas waves os 8 ciclos de `ctr_we` andando slice a slice. **Marco crítico.**
4. **Monitor + item.** Publica `in_ap`/`out_ap`, imprime.
5. **Scoreboard com modelo SV.** Checagem automática.
6. **Sequences dirigidas (carry, wrap) e aleatórias.**
7. **Coverage.**
8. **Injeção de erro** (opcional): forçar `incr` com valor sp2v inválido → esperar `alert`.

---

## Fase 4 — modelo de referência

```systemverilog
function automatic bit [127:0] ref_incr(bit [127:0] ctr_in, bit inc32);
  bit [127:0] v = {<<8{ctr_in}};          // byte 0 vira MSB
  if (inc32) v[31:0] = v[31:0] + 1;       // GCM: wrap 2^32
  else       v       = v + 1;             // CTR: wrap 2^128
  return {<<8{v}};
endfunction
```

Validar o modelo à mão no passo 3 antes de confiar nele (ordem de bytes é a armadilha).
Conferência cruzada: `model/aes_modes.c` (CTR) e vetores GCM em `dv/test_vectors/`.

---

## Fase 5 — o que o scoreboard checa

- **Valor**: `ctr_out == ref_incr(ctr_in, inc32)`.
- **Protocolo**: `ready` cai 1 ciclo após `incr` aceito; exatamente 8 ciclos com 1 slice de
  `ctr_we` HIGH (onehot, ordem do slice menos significativo p/ o mais); `ready` volta.
- **Ordem**: FIFO.
- **inc32**: 96 bits altos nunca mudam.
- **Alert**: nunca sobe com entradas válidas; sobe e fica (terminal) com sp2v inválido.
- **Reset**: incremento abortado não deixa FSM fora de `CTR_IDLE`.

---

## Fase 6 — plano de cobertura

```systemverilog
cp_mode  : coverpoint inc32 {bins inc128 = {0}; bins inc32 = {1};}
cp_carry : coverpoint n_ff_bytes {bins none = {0}; bins b[] = {[1:15]}; bins all = {16};}
cp_wrap  : coverpoint wrap {bins no = {0}; bins yes = {1};}
cross cp_mode, cp_carry;
cp_load  : coverpoint load_iv;
```

`n_ff_bytes` = quantos bytes 0xFF no fim do valor numérico (até onde o carry anda).
Mais: incr back-to-back, incr com `ready=LOW` (ignorado), alert por erro de codificação.

---

## Fase 7 — integrar ao dvsim (opcional, no fim)

Criar `my_dv/my_aes_ctr_sim_cfg.hjson` espelhando `dv/aes_base_sim_cfg.hjson`,
com `fusesoc_core` apontando pro `.core` próprio.

```bash
dvsim $REPO_TOP/hw/ip/aes/my_dv/my_aes_ctr_sim_cfg.hjson --tool vcs -i ctr_smoke
```

Depois do CTR: repetir a estrutura para `aes_ghash_wrap` (modelo GHASH; ver
`model/ghash_masked.py` e `dv/test_vectors/nist_vectors_gcm_pkg.sv`).

---

## Referências dentro do repo

| Arquivo | Para quê |
|---|---|
| `dv/tb/tb.sv` | como conectar DUT e popular `uvm_config_db` |
| `hw/dv/sv/dv_base_agent/` | classes base p/ herdar (sem o CIP inteiro) |
| `dv/env/aes_seq_item.sv` | exemplo de transação bem feita |
| `dv/env/aes_scoreboard.sv` | como usam o modelo DPI |
| `dv/aes_base_sim_cfg.hjson` | estrutura de um sim cfg do dvsim |

---

## Comandos úteis do dvsim (TB oficial)

```bash
# regressão completa de uma variante
dvsim $REPO_TOP/hw/ip/aes/dv/aes_masked_sim_cfg.hjson --tool vcs

# teste único com waves p/ Verdi, seed fixa
dvsim $REPO_TOP/hw/ip/aes/dv/aes_masked_sim_cfg.hjson --tool vcs -i aes_smoke \
      --waves fsdb --fixed-seed 1

# coverage
dvsim $REPO_TOP/hw/ip/aes/dv/aes_masked_sim_cfg.hjson --tool vcs --cov

# paralelismo
... -mo 16
```

Variantes: `aes_masked_`, `aes_unmasked_`, `aes_gcm_masked_`, `aes_gcm_unmasked_`.

Avisos esperados e inofensivos:
- `Test "aes_gcm_save_restore" ... not found` — testes GCM só existem nos cfgs `gcm_*`;
  o testplan é compartilhado pelas 4 variantes.
- `$SCRATCH_ROOT is not accessible` — timeout de NFS. Apontar `SCRATCH_ROOT` p/ disco
  local do nó melhora muito a performance de simulação.

Sem módulo `vcformal` no cluster → fluxo formal Synopsys indisponível. Só simulação (VCS)
e síntese (Design Compiler).
