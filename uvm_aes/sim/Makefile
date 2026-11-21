# -----------------------------------------------------------------------------
#   make build                         compila tudo -> out/simv
#   make run   [TEST=..] [SEED=..]     roda um teste           -> out/<TEST>_<SEED>.log
#   make run   WAVES=1                 ... e grava waves FSDB  -> out/<TEST>_<SEED>.fsdb
#   make verdi [TEST=..] [SEED=..]     abre o FSDB no Verdi (pos-simulacao)
#   make gui   [TEST=..]               não funciona aparatentemente
# -----------------------------------------------------------------------------

UVM_AES_ROOT ?= $(abspath ..)
AES_RTL      ?= $(abspath $(UVM_AES_ROOT)/../aes/rtl)
OT_DEPS      ?= $(UVM_AES_ROOT)/deps/opentitan
OUT          ?= $(UVM_AES_ROOT)/sim/out
export UVM_AES_ROOT AES_RTL OT_DEPS   # -> files.f

TEST      ?= aes_base_test
SEED      ?= 1
VERBOSITY ?= UVM_MEDIUM
WAVES     ?= 0
RUN_NAME  := $(TEST)_$(SEED)

# -----------------------------------------------------------------------------
# Opcoes de compilacao
#   -full64 -sverilog          modo 64 bits, SystemVerilog
#   -ntb_opts uvm-1.2          usa a biblioteca UVM 1.2 que vem com o VCS
#   -timescale=1ns/1ps         default para arquivos sem `timescale (RTL do OT)
#   -kdb -lca                  gera a base de dados do Verdi (liga sinal <-> codigo)
#   -debug_access+all          permite ver/forcar qualquer sinal (waves, gui)
#   -assert svaext             extensoes de SVA usadas nas assertions do OT
#   -xlrm uniq_prior_final     avalia unique/priority case so no valor final do
#                              time slot (evita falsos warnings do RTL do OT)
#   +define+UVM                faz as assertions do OT (prim_assert) reportarem
#                              falha como uvm_error -> contam no resultado do teste
#   +lint=TFIPC-L              avisa sobre portas nao ligadas
# -----------------------------------------------------------------------------
VCS_OPTS := -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
            -kdb -lca -debug_access+all \
            -assert svaext -xlrm uniq_prior_final \
            +define+UVM +lint=TFIPC-L \
            -top tb_top \
            -f $(UVM_AES_ROOT)/sim/files.f \
            -Mdir=$(OUT)/csrc -o $(OUT)/simv -l $(OUT)/build.log

SIM_OPTS := +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) \
            +UVM_VERBOSITY=$(VERBOSITY) -l $(OUT)/$(RUN_NAME).log
ifeq ($(WAVES),1)
SIM_OPTS += +WAVES=$(OUT)/$(RUN_NAME).fsdb
endif

.PHONY: build run verdi gui check clean

build: | $(OUT)
	cd $(OUT) && vcs $(VCS_OPTS)

run:
	cd $(OUT) && ./simv $(SIM_OPTS)

SIGNALS_RC ?= $(UVM_AES_ROOT)/sim/signals.rc
VERDI_OPTS := -dbdir simv.daidir -ssf $(OUT)/$(RUN_NAME).fsdb
VERDI_OPTS += $(if $(wildcard $(SIGNALS_RC)),-sswr $(SIGNALS_RC))

verdi:
	cd $(OUT) && verdi $(VERDI_OPTS) &

gui:
	cd $(OUT) && ./simv $(SIM_OPTS) -gui=verdi &

check:
	@which vcs   || (echo "vcs not found: run 'source ../env.sh'"   && false)
	@which verdi || (echo "verdi not found: run 'source ../env.sh'" && false)
	@echo "VERDI_HOME=$$VERDI_HOME"

$(OUT):
	mkdir -p $(OUT)

clean:
	rm -rf $(OUT)
