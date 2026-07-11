interface vending_interface (input logic clk, input logic rst);
    logic [1:0] coin_in  = 2'b00;
    logic [1:0] sel_item = 2'b00;
    logic confirm = 1'b0;
    logic cancel  = 1'b0;
    
    logic dispense;
    logic [7:0] change_out;
    logic error;
    logic [7:0] display;
    logic [2:0] state_out;

    clocking drv_cb @(posedge clk);
        output coin_in, sel_item, confirm, cancel;
    endclocking

    clocking mon_cb @(posedge clk);
        input coin_in, sel_item, confirm, cancel,
              dispense, change_out, error, display, state_out;
    endclocking

    modport DRIVER  (clocking drv_cb, input clk, rst);
    modport MONITOR (clocking mon_cb, input clk, rst);
endinterface