`timescale 1ns/1ps
import vending_pkg::*;

module testbench;

  // 1. Declaração de Sinais para Conectar ao DUT (Device Under Test)
  logic [1:0] coin_in;
  logic [1:0] sel_item;
  logic       confirm;
  logic       cancel;
  logic       clk;
  logic       rst;
  logic       dispense;
  logic [7:0] change_out;
  logic       error;
  logic [7:0] display;
  logic [2:0] state_out;

  // 2. Instanciação do Módulo Top-Level (DUT)
  top_level dut (
    .coin_in(coin_in),
    .sel_item(sel_item),
    .confirm(confirm),
    .cancel(cancel),
    .clk(clk),
    .rst(rst),
    .dispense(dispense),
    .change_out(change_out),
    .error(error),
    .display(display),
    .state_out(state_out)
  );

  // 3. Geração do Clock Global (Período de 10 ns = 100 MHz)
  always begin
    #5 clk = ~clk;
  end

  // ==========================================================================
  // TASKS AUXILIARES PARA SIMPLIFICAR OS ESTÍMULOS
  // ==========================================================================
  
  // Task para aplicar uma moeda e esperar um ciclo de clock
  task automatic aplicar_moeda(input logic [1:0] moeda);
    begin
      @(posedge clk);
      coin_in = moeda;
      @(posedge clk);
      coin_in = 2'b00; // Retorna a zero no ciclo seguinte (comportamento de pulso)
    end
  endtask

  // Task para checar os resultados esperados
  task automatic checar_saida(input logic exp_dispense, input logic [7:0] exp_change, input logic exp_error, input string cenario);
    begin
      #1; // Pequeno atraso necessário para estabilização após a borda do clock
      if ((dispense === exp_dispense) && (change_out === exp_change) && (error === exp_error)) begin
        $display("[PASS] %s -> Dispense: %b, Troco: %d, Erro: %b", cenario, dispense, change_out, error);
      end else begin
        $display("[FAIL] %s -> ESPERADO (Dispense:%b, Troco:%d, Erro:%b) | OBTIDO (Dispense:%b, Troco:%d, Erro:%b)", 
                 cenario, exp_dispense, exp_change, exp_error, dispense, change_out, error);
      end
    end
  endtask

  // ==========================================================================
  // BLOCO PRINCIPAL DE ESTÍMULOS (CENÁRIOS OBRIGATÓRIOS)
  // ==========================================================================
  initial begin
    // Inicialização segura de todos os sinais de entrada
    clk      = 0;
    rst      = 1;
    cancel   = 0;
    confirm  = 0;
    coin_in  = 2'b00;
    sel_item = 2'b00;

    // Configuração para geração de arquivos de onda para o Verdi/DVE
    $dumpfile("vending_machine.vcd");
    $dumpvars(0, testbench);

    // Aplica o Reset de inicialização por 2 ciclos de clock
    repeat(2) @(posedge clk);
    rst = 0;
    $display("--- Iniciando Simulação do Controlador de Vending Machine ---");

    // ------------------------------------------------------------------------
    // CENÁRIO 1: Compra com Sucesso (Café - Preço: 25 centavos)
    // Inserir R$1.00 (Moeda 11), selecionar Café (00) -> Esperado: Dispense=1, Troco=75
    // ------------------------------------------------------------------------
    $display("\n[Executando] Cenario 1: Compra bem-sucedida de Cafe com troco...");
    sel_item = 2'b00; // Seleciona Café
    aplicar_moeda(2'b11); // Insere R$1.00 (Entra em COLLECT no próximo clock)
    
    repeat(2) @(posedge clk); // Aguarda estabilizar no estado COLLECT
    confirm = 1; // Pressiona Confirmar (FSM calcula próximo_estado = CHECK)
    @(posedge clk);
    confirm = 0;

    // Sincronia de Estados:
    @(posedge clk); // FSM entra em CHECK (Memória lê e comparador avalia)
    @(posedge clk); // FSM entra em DISPENSE (Ativa pulso de liberação)
    checar_saida(.exp_dispense(1'b1), .exp_change(8'd0), .exp_error(1'b0), "Cenario 1 - Estado DISPENSE");
    
    @(posedge clk); // FSM entra em CHANGE (Troco é devidamente registrado na saída)
    checar_saida(.exp_dispense(1'b0), .exp_change(8'd75), .exp_error(1'b0), "Cenario 1 - Estado CHANGE (Troco)");
    
    @(posedge clk); // FSM retorna ao estado IDLE

    // ------------------------------------------------------------------------
    // CENÁRIO 2: Crédito Insuficiente (Snack - Preço: 100 centavos)
    // Inserir R$0.25 (Moeda 01), selecionar Snack (11) -> Esperado: Erro=1, Dispense=0
    // ------------------------------------------------------------------------
    $display("\n[Executando] Cenario 2: Tentativa de compra com credito insuficiente...");
    sel_item = 2'b11; // Seleciona Snack
    aplicar_moeda(2'b01); // Insere R$0.25
    
    repeat(2) @(posedge clk);
    confirm = 1; // Solicita a compra
    @(posedge clk);
    confirm = 0;

    @(posedge clk); // Passa por CHECK
    @(posedge clk); // Transiciona para o estado ERROR devido à falta de saldo
    checar_saida(.exp_dispense(1'b0), .exp_change(8'd0), .exp_error(1'b1), "Cenario 2 - Estado de Erro");

    // Teste do seu novo circuito: Cancela a operação estando no estado ERROR
    cancel = 1; // Ativa reset_credit na unidade_controle e proximo_estado = IDLE
    @(posedge clk);
    cancel = 0;
    #1;
    if (display === 8'd0) begin
      $display("[PASS] Cenario 2 - reset_credit limpou o saldo acumulado em ERROR.");
    end else begin
      $display("[FAIL] Cenario 2 - Saldo nao foi limpo ao cancelar em ERROR.");
    end

    // ------------------------------------------------------------------------
    // CENÁRIO 3: Cancelamento no meio da operação (Estado COLLECT)
    // Inserir R$0.50 (Moeda 10) e apertar cancelar -> Esperado: Voltar para IDLE e zerar crédito
    // ------------------------------------------------------------------------
    $display("\n[Executando] Cenario 3: Cancelamento durante a insercao de moedas (COLLECT)...");
    aplicar_moeda(2'b10); // Insere R$0.50
    
    repeat(2) @(posedge clk); // Aguarda a FSM processar em COLLECT
    cancel = 1; // Ativa a sua nova lógica de reset_credit e desvia para IDLE
    //@(posedge clk); // Remove o sinal no ciclo seguinte
    cancel = 0;
    
    #1;
    // state_out === 3'b000 mapeia para IDLE
    if (state_out === 3'b000 && display === 8'd0) begin
      $display("[PASS] Cenario 3 -> reset_credit limpou o acumulador e retornou para IDLE com sucesso.");
    end else begin
      $display("[FAIL] Cenario 3 -> Sistema falhou ao tratar o cancelamento em COLLECT. Estado: %b, Credito: %d", state_out, display);
    end

    // ------------------------------------------------------------------------
    // Finalização do Ambiente de Simulação
    // ------------------------------------------------------------------------
    $display("\n--- Fim da Simulacao Técnica ---");
    $finish;
  end

endmodule