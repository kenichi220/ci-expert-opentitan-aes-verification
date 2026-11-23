# -----------------------------------------------------------------------------
#   make build                         compila tudo -> out/simv
#   make run   [TEST=..] [SEED=..]     roda um teste           -> out/<TEST>_<SEED>.log
#   make run   WAVES=1                 ... e grava waves FSDB  -> out/<TEST>_<SEED>.fsdb
#   make run   PLUSARGS="+ERR=.."      ... repassa plusargs extras ao simv
#   make verdi [TEST=..] [SEED=..]     abre o FSDB no Verdi (pos-simulacao)
#   make errs                          aes_drv_err_test com cada um dos 5 tipos de erro
#   make t9                            testes do topico 9 (ref, drv, errs, negativo)
#   make t10                           testes do topico 10 + coverage somada (urg)
#   make t11                           todos os testes atuais (refatoracao p/ env) + errs + urg
#   make cov                           junta a coverage de todas as runs -> out/urgReport
#   make build COV=1 / run COV=1       + coverage de CODIGO do DUT (linha, cond, fsm...)
#   make gui   [TEST=..]               não funciona aparatentemente
# -----------------------------------------------------------------------------

UVM_AES_ROOT ?= $(abspath ..)
AES_RTL      ?= $(abspath $(UVM_AES_ROOT)/../aes/rtl)
OT_DEPS      ?= $(UVM_AES_ROOT)/deps/opentitan
AES_MODEL    ?= $(abspath $(UVM_AES_ROOT)/../aes/model)
OUT          ?= $(UVM_AES_ROOT)/sim/out
export UVM_AES_ROOT AES_RTL OT_DEPS   # -> files.f

TEST      ?= aes_base_test
SEED      ?= 1
VERBOSITY ?= UVM_MEDIUM
WAVES     ?= 0
COV       ?= 0
PLUSARGS  ?=
RUN_NAME  := $(TEST)_$(SEED)

# -kdb -lca: base do Verdi | +define+UVM: assertions do OT viram uvm_error
# -xlrm uniq_prior_final: evita falsos warnings de unique/priority do RTL do OT
# C_SRCS: ref model C (DPI), compilado e ligado ao simv
# Covergroups vao sempre para out/simv.vdb; -cm_name separa as runs. COV=1: + code coverage do DUT
C_SRCS := $(UVM_AES_ROOT)/env/aes_ref_dpi.c $(AES_MODEL)/aes.c

VCS_OPTS := -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
            -kdb -lca -debug_access+all \
            -assert svaext -xlrm uniq_prior_final \
            +define+UVM +lint=TFIPC-L \
            -top tb_top \
            -f $(UVM_AES_ROOT)/sim/files.f \
            $(C_SRCS) -CFLAGS "-I$(AES_MODEL)" \
            -Mdir=$(OUT)/csrc -o $(OUT)/simv -l $(OUT)/build.log

CM_TYPES := line+cond+fsm+branch+tgl
ifeq ($(COV),1)
VCS_OPTS += -cm $(CM_TYPES) -cm_hier $(UVM_AES_ROOT)/sim/cov_hier.cfg
endif

SIM_OPTS := +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) \
            +UVM_VERBOSITY=$(VERBOSITY) -l $(OUT)/$(RUN_NAME).log \
            -cm_name $(RUN_NAME) $(PLUSARGS)
ifeq ($(COV),1)
SIM_OPTS += -cm $(CM_TYPES)
endif
ifeq ($(WAVES),1)
SIM_OPTS += +WAVES=$(OUT)/$(RUN_NAME).fsdb
endif

.PHONY: build run errs test cov verdi gui check clean

build: | $(OUT)
	cd $(OUT) && vcs $(VCS_OPTS)

run:
	cd $(OUT) && ./simv $(SIM_OPTS)

ERR_TYPES := ERR_IN_VALID ERR_CRYPT ERR_DEC_KEY_GEN ERR_OUT_READY ERR_NO_CMD
errs:
	@for e in $(ERR_TYPES); do \
	  $(MAKE) --no-print-directory run TEST=aes_drv_err_test PLUSARGS="+ERR=$$e" \
	    RUN_NAME=aes_drv_err_test_$$e > /dev/null 2>&1; \
	  printf "%-16s " $$e; grep -h "\[RESULT\] \*\*\*" $(OUT)/aes_drv_err_test_$$e.log | sed 's/.*\[RESULT\] //'; \
	done

T_TESTS := aes_item_test aes_ref_test aes_drv_test aes_agent_test aes_sb_neg_test aes_cov_test
test:
	@for t in $(T_TESTS); do \
	  $(MAKE) --no-print-directory run TEST=$$t > /dev/null 2>&1; \
	  printf "%-16s " $$t; grep -h "\[RESULT\] \*\*\*" $(OUT)/$${t}_$(SEED).log | sed 's/.*\[RESULT\] //'; \
	done
	@$(MAKE) --no-print-directory errs
	@$(MAKE) --no-print-directory cov

# urg soma todas as runs do vdb -> out/urgReport (dashboard.html, groups.txt)
cov:
	cd $(OUT) && urg -dir simv.vdb -report urgReport -format both -log urg.log
	@echo "--- inicio de out/urgReport/groups.txt ---"
	@head -40 $(OUT)/urgReport/groups.txt

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
