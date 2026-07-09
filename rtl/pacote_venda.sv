package vending_pkg;

  // Codificação de 3 bits para os 6 estados da FSM (Moore)
  typedef enum logic [2:0] {
    IDLE     = 3'b000,
    COLLECT  = 3'b001,
    CHECK    = 3'b010,
    DISPENSE = 3'b011,
    CHANGE   = 3'b100,
    ERROR    = 3'b101
  } estado_t;

  // Constantes em ponto fixo (valores em centavos) para o memória e o comparador.
  localparam int VAL_MOEDA_25  = 25;
  localparam int VAL_MOEDA_50  = 50;
  localparam int VAL_MOEDA_100 = 100;

endpackage : vending_pkg