import vending_pkg::*;

module registrador_credito (
  input  logic        clk,
  input  logic        rst,
  input  logic        cancel,
  input  logic        credit_load,
  input  logic [1:0]  coin_in,
  //input  logic [2:0]  current_state, // logica alternativa no qual o credit_load é controlado pelo estado da FSM
  input logic reset_credit,
  output logic [7:0]  credit
);

  // Registrador síncrono de acúmulo
  always_ff @(posedge clk) begin
    if (rst || reset_credit || cancel) begin
      credit <= 8'd0; // Zera imediatamente
    end else if (credit_load) begin
      credit <= credit + coin_value; // Acumula 
    end
  end

  // Mapeamento combinacional do valor da moeda inserida
  logic [7:0] coin_value;
  always_comb begin
    case (coin_in)
      2'b01  : coin_value = VAL_MOEDA_25;
      2'b10  : coin_value = VAL_MOEDA_50;
      2'b11  : coin_value = VAL_MOEDA_100;
      default: coin_value = 8'd0;
    endcase
  end
endmodule