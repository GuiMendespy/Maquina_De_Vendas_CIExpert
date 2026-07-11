import vending_pkg::*;

module unidade_controle (
  input  logic        clk,
  input  logic        rst,
  input  logic        cancel,
  input  logic [1:0]  coin_in,
  input  logic        confirm,
  input  logic        can_sell,
  output estado_t     estado, // Porta de saída para monitoramento/depuração

  // Sinais de controle do Datapath e Memória
  output logic        credit_load,
  output logic        reset_credit,
  output logic        mem_read,
  output logic        mem_write,

  // Saídas do sistema
  output logic        dispense,
  output logic        error
);

  // Declaração do registrador de estado conforme a teoria clássica de Moore
  estado_t estado_atual;

  assign estado = estado_atual;

  // --- 1. Registrador e Transição de Estado (sem sinal intermediário) ---
  always_ff @(posedge clk) begin
    if (rst || cancel) begin
      estado_atual <= IDLE; // Reset ou cancelamento força retorno seguro para IDLE
    end else begin
      case (estado_atual)

        IDLE: begin
          // Aguarda inserção de moeda para mudar para COLLECT
          if (coin_in != 2'b00) begin
            estado_atual <= COLLECT;
          end
        end

        COLLECT: begin
          // Quando o usuário pressiona confirmar, avança para a checagem
          if (confirm) begin
            estado_atual <= CHECK;
          end
        end

        CHECK: begin
          // Avalia o resultado booleano instantâneo do comparador no datapath
          if (can_sell) begin
            estado_atual <= DISPENSE; // Crédito suficiente e há estoque
          end else begin
            estado_atual <= ERROR;    // Saldo insuficiente ou falta de produto
          end
        end

        DISPENSE: begin
          // Transiciona incondicionalmente para o cálculo do troco
          estado_atual <= CHANGE;
        end

        CHANGE: begin
          estado_atual <= IDLE;
        end

        ERROR: begin
          // Permanece em ERROR até o usuário cancelar (tratado pelo rst||cancel acima)
          estado_atual <= ERROR;
        end

        default: begin
          estado_atual <= IDLE;
        end

      endcase
    end
  end

  // --- 2. Saídas de Moore: dependem apenas do estado atual ---
  always_comb begin
    case (estado_atual)

      IDLE: begin
        credit_load  = 1'b0;
        mem_read     = 1'b0;
        reset_credit = 1'b0;
        mem_write    = 1'b0;
        dispense     = 1'b0;
        error        = 1'b0; // Nenhuma saída ativa em IDLE (valores default acima)
      end

      COLLECT: begin
        mem_read     = 1'b0;
        reset_credit = 1'b0;
        mem_write    = 1'b0;
        dispense     = 1'b0;
        error        = 1'b0;
        credit_load = 1'b1; // Habilita a carga do acumulador enquanto coleta moedas
      end

      CHECK: begin
        credit_load  = 1'b0;
        reset_credit = 1'b0;
        mem_write    = 1'b0;
        dispense     = 1'b0;
        error        = 1'b0;
        mem_read = 1'b1; // Ativa a leitura síncrona da memória (preço e estoque)
      end

      DISPENSE: begin
        credit_load  = 1'b0;
        mem_read     = 1'b0;
        reset_credit = 1'b0;
        error        = 1'b0;
        dispense  = 1'b1; // Pulso de exatamente 1 ciclo para liberação do item
        mem_write = 1'b1; // Comando síncrono para a memória decrementar o estoque
      end

      CHANGE: begin
        credit_load  = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        dispense     = 1'b0;
        error        = 1'b0;
        reset_credit = 1'b1; // Zera o crédito após o troco já ter sido calculado
      end

      ERROR: begin
        credit_load  = 1'b0;
        mem_read     = 1'b0;
        reset_credit = 1'b0;
        mem_write    = 1'b0;
        dispense     = 1'b0;
        error = 1'b1; // Mantém sinalizador de erro ativo para a interface
      end

      default: begin
        credit_load  = 1'b0;
        mem_read     = 1'b0;
        reset_credit = 1'b0;
        mem_write    = 1'b0;
        dispense     = 1'b0;
        error        = 1'b0;
      end

    endcase
  end

endmodule
