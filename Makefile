# ==========================================================
# Diretórios
# ==========================================================
RTL_DIR   = rtl
TB_DIR    = sim
SYNTH_DIR = synth

# ==========================================================
# Arquivos RTL e Pacotes (Ordem estrita de dependência)
# ==========================================================
PKG_FILES = $(RTL_DIR)/vending_pkg.sv

RTL_FILES = \
    $(RTL_DIR)/comparator.sv \
    $(RTL_DIR)/subtractor.sv \
    $(RTL_DIR)/memory.sv \
    $(RTL_DIR)/credit_reg.sv \
    $(RTL_DIR)/control_unit.sv \
    $(RTL_DIR)/vending_top.sv

# ==========================================================
# Arquivos de Testbench
# ==========================================================
TB_FILES = \
    $(TB_DIR)/interface.sv \
    $(TB_DIR)/package.sv \
    $(TB_DIR)/tb_vending.sv

# ==========================================================
# Top do testbench
# ==========================================================
TOP = tb_vending

# ==========================================================
# Flags de Compilação e Simulação (Fluxo Unificado)
# ==========================================================
TIMESCALE = 1ns/1ps

VCS_FLAGS = -full64 \
            -sverilog \
            -timescale=$(TIMESCALE) \
            -debug_access+all \
            -kdb \
            -ntb_opts uvm \
            +lint=all,noWMIA-L,noNS \
			-debug_all

# ==========================================================
# Compilação / Elaboração Unificada (Gera o executável simv)
# ==========================================================
# Compilamos todos os arquivos diretamente com o vcs para que
# o pacote UVM seja visível globalmente durante todo o parsing.
compile:
	vcs $(VCS_FLAGS) -top $(TOP) $(PKG_FILES) $(RTL_FILES) $(TB_FILES)

# ==========================================================
# Simulação (Executa os cenários de teste)
# ==========================================================
run: compile
	./simv

# ==========================================================
# Abrir ondas no Synopsys Verdi
# ==========================================================
wave:
	verdi -ssf vending_machine.fsdb &

# ==========================================================
# Síntese Lógica no Design Compiler
# ==========================================================
synth:
	setarch `uname -m` -R dc_shell -f $(SYNTH_DIR)/synth.tcl

# ==========================================================
# Limpeza da síntese
# ==========================================================
clean_synth:
	rm -rf \
		work \
		$(SYNTH_DIR)/work \
		$(SYNTH_DIR)/reports/*.rpt \
		$(SYNTH_DIR)/*.rpt \
		$(SYNTH_DIR)/*.ddc \
		$(SYNTH_DIR)/*.db \
		$(SYNTH_DIR)/*_syn.v \
		Synopsys_stack_trace* \
		crte_*

# ==========================================================
# Limpeza da simulação
# ==========================================================
clean_sim:
	rm -rf \
		csrc \
		simv* \
		*.daidir \
		novas* \
		AN.DB \
		ucli.key \
		verdi* \
		DVEfiles \
		.vlogan* \
		*.fsdb \
		*.vcd \
		*.log \
		command.log \
		filename.log \
		default.svf

# ==========================================================
# Limpeza total
# ==========================================================
clean: clean_sim clean_synth

.PHONY: compile run wave synth clean clean_sim clean_synth