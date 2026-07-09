import vending_pkg::*;

module memoria (
  input  logic        clk,
  input  logic [1:0]  sel_item,  // Endereço (0..3)
  input  logic        mem_read,  // Habilita leitura da FSM
  input  logic        mem_write, // Habilita escrita (decremento) da FSM
  output logic [7:0]  price,     // Preço em centavos (8 bits superiores)
  output logic [7:0]  stock      // Estoque (8 bits inferiores)
);

  // Memória interna: 4 posições de 16 bits
  logic [15:0] mem [0:3];

  // Inicialização obrigatória dos dados via initial begin
  initial begin
    mem[0] = {8'd25,  8'd5}; // Café:  Preço R$0,25 (25), Estoque 5
    mem[1] = {8'd50,  8'd5}; // Água:  Preço R$0,50 (50), Estoque 5
    mem[2] = {8'd75,  8'd3}; // Suco:  Preço R$0,75 (75), Estoque 3
    mem[3] = {8'd100, 8'd2}; // Snack: Preço R$1,00 (100), Estoque 2
  end

  // Leitura síncrona: dados disponíveis no ciclo seguinte
  always_ff @(posedge clk) begin
    if (mem_read) begin
      price <= mem[sel_item][15:8];
      stock <= mem[sel_item][7:0];
    end
  end

  // Escrita síncrona: decrementa estoque (preço é fixo)
  always_ff @(posedge clk) begin
    if (mem_write && mem[sel_item][7:0] > 0) begin
      mem[sel_item][7:0] <= mem[sel_item][7:0] - 1'b1;
    end
  end

endmodule