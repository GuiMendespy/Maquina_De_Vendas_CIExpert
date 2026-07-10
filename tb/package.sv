`include "uvm_macros.svh"

package vending_pkg;
    import uvm_pkg::*;

    class vending_transaction extends uvm_sequence_item;
        bit [1:0] coin_in;
        bit [1:0] sel_item;
        bit confirm;
        bit cancel;
        bit dispense;
        bit [7:0] change_out;
        bit error;
        bit [7:0] display;
        bit [2:0] state_out;

        `uvm_object_utils(vending_transaction)

        function new(string name = "vending_transaction");
            super.new(name);
        endfunction
    endclass

    class vending_sequence_compra_sucesso extends uvm_sequence #(vending_transaction);
        `uvm_object_utils(vending_sequence_compra_sucesso)

        function new(string name = "vending_sequence_compra_sucesso");
            super.new(name);
        endfunction

        task body();
            vending_transaction req;
            req = vending_transaction::type_id::create("req");

            start_item(req);
            req.coin_in  = 2'b11; // R$1,00
            req.sel_item = 2'b00; // Café (preco 25)
            req.confirm  = 1;
            req.cancel   = 0;
            finish_item(req);
        endtask
    endclass

    class vending_sequence_credito_insuficiente extends uvm_sequence #(vending_transaction);
        `uvm_object_utils(vending_sequence_credito_insuficiente)

        function new(string name = "vending_sequence_credito_insuficiente");
            super.new(name);
        endfunction

        task body();
            vending_transaction req;
            req = vending_transaction::type_id::create("req");

            start_item(req);
            req.coin_in  = 2'b01; // R$0,25
            req.sel_item = 2'b11; // Snack (preco 100)
            req.confirm  = 1;
            req.cancel   = 0;
            finish_item(req);
        endtask
    endclass

    // Cenario 3: Cancelamento com moedas acumuladas -> retorno imediato a IDLE, credito zerado
    class vending_sequence_cancelamento extends uvm_sequence #(vending_transaction);
        `uvm_object_utils(vending_sequence_cancelamento)

        function new(string name = "vending_sequence_cancelamento");
            super.new(name);
        endfunction

        task body();
            vending_transaction req;
            req = vending_transaction::type_id::create("req");

            start_item(req);
            req.coin_in  = 2'b10; // R$0,50
            req.sel_item = 2'b00;
            req.confirm  = 0;
            req.cancel   = 1;
            finish_item(req);
        endtask
    endclass

    // Cenario 4: Esgotamento de estoque -> 5 compras de cafe, 6a deve falhar com erro
    class vending_sequence_estoque_esgotado extends uvm_sequence #(vending_transaction);
        `uvm_object_utils(vending_sequence_estoque_esgotado)

        function new(string name = "vending_sequence_estoque_esgotado");
            super.new(name);
        endfunction

        task body();
            vending_transaction req;
            repeat (6) begin
                req = vending_transaction::type_id::create("req");
                start_item(req);
                req.coin_in  = 2'b11; // R$1,00 (suficiente pro cafe)
                req.sel_item = 2'b00; // Cafe (estoque inicial 5)
                req.confirm  = 1;
                req.cancel   = 0;
                finish_item(req);
            end
        endtask
    endclass

    class vending_driver extends uvm_driver #(vending_transaction);
        `uvm_component_utils(vending_driver)

        virtual vending_interface.DRIVER vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual vending_interface)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Interface virtual nao configurada para o driver")
        endfunction

        task run_phase(uvm_phase phase);
            vending_transaction req;
            forever begin
                seq_item_port.get_next_item(req);

                // Seleciona o item e mantem estavel durante o cenario
                vif.drv_cb.sel_item <= req.sel_item;

                // Pulso de moeda (1 ciclo ligado, depois volta a 00)
                if (req.coin_in != 2'b00) begin
                    @(vif.drv_cb);
                    vif.drv_cb.coin_in <= req.coin_in;
                    @(vif.drv_cb);
                    vif.drv_cb.coin_in <= 2'b00;
                end

                // Pulso de confirm, esperando 2 ciclos apos a moeda
                if (req.confirm) begin
                    repeat(2) @(vif.drv_cb);
                    vif.drv_cb.confirm <= 1;
                    @(vif.drv_cb);
                    vif.drv_cb.confirm <= 0;
                end

                // Pulso de cancel, esperando 2 ciclos apos a moeda (mesmo timing do confirm)
                if (req.cancel) begin
                    repeat(2) @(vif.drv_cb);
                    vif.drv_cb.cancel <= 1;
                    @(vif.drv_cb);
                    vif.drv_cb.cancel <= 0;
                end

                seq_item_port.item_done();
            end
        endtask
    endclass

    class vending_monitor extends uvm_monitor;
        `uvm_component_utils(vending_monitor)

        virtual vending_interface.MONITOR vif;
        uvm_analysis_port #(vending_transaction) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual vending_interface)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Interface virtual nao configurada para o monitor")
        endfunction

        task run_phase(uvm_phase phase);
            vending_transaction tr;
            forever begin
                @(vif.mon_cb);
                tr = vending_transaction::type_id::create("tr");
                tr.coin_in    = vif.mon_cb.coin_in;
                tr.sel_item   = vif.mon_cb.sel_item;
                tr.confirm    = vif.mon_cb.confirm;
                tr.cancel     = vif.mon_cb.cancel;
                tr.dispense   = vif.mon_cb.dispense;
                tr.change_out = vif.mon_cb.change_out;
                tr.error      = vif.mon_cb.error;
                tr.display    = vif.mon_cb.display;
                tr.state_out  = vif.mon_cb.state_out;
                ap.write(tr);
            end
        endtask
    endclass

    class vending_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(vending_scoreboard)

        uvm_analysis_imp #(vending_transaction, vending_scoreboard) imp;

        bit [7:0] credit;
        bit [7:0] price [4] = '{25, 50, 75, 100};
        int       stock [4] = '{5, 5, 3, 2};
        bit       prev_dispense;
        bit       prev_error;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            imp = new("imp", this);
        endfunction

        function void write(vending_transaction tr);
            if (tr.coin_in != 2'b00) begin
                case (tr.coin_in)
                    2'b01: credit += 25;
                    2'b10: credit += 50;
                    2'b11: credit += 100;
                endcase
            end

            if (tr.cancel) credit = 0;

            if (tr.dispense && !prev_dispense) begin
                if (credit >= price[tr.sel_item] && stock[tr.sel_item] > 0) begin
                    `uvm_info("SCOREBOARD", "PASS - dispense com credito e estoque suficientes", UVM_LOW)
                    stock[tr.sel_item]--;
                end else begin
                    `uvm_error("SCOREBOARD", "FAIL - dispense ocorreu sem credito/estoque suficientes")
                end
            end

            if (tr.error && !prev_error) begin
                if (credit < price[tr.sel_item] || stock[tr.sel_item] == 0) begin
                    `uvm_info("SCOREBOARD", "PASS - erro ocorreu corretamente", UVM_LOW)
                end else begin
                    `uvm_error("SCOREBOARD", "FAIL - erro ocorreu sem motivo valido")
                end
            end

            if (prev_dispense) begin
                bit [7:0] exp_change = credit - price[tr.sel_item];
                if (tr.change_out == exp_change) begin
                    `uvm_info("SCOREBOARD", $sformatf("PASS - troco correto: %0d", tr.change_out), UVM_LOW)
                end else begin
                    `uvm_error("SCOREBOARD", $sformatf("FAIL - troco esperado %0d, obtido %0d", exp_change, tr.change_out))
                end
                credit = 0;
            end

            prev_dispense = tr.dispense;
            prev_error    = tr.error;
        endfunction
    endclass

    class vending_env extends uvm_env;
        `uvm_component_utils(vending_env)

        vending_driver             drv;
        vending_monitor            mon;
        uvm_sequencer #(vending_transaction) sqr;
        vending_scoreboard         sb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv = vending_driver::type_id::create("drv", this);
            mon = vending_monitor::type_id::create("mon", this);
            sqr = uvm_sequencer#(vending_transaction)::type_id::create("sqr", this);
            sb  = vending_scoreboard::type_id::create("sb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
            mon.ap.connect(sb.imp);
        endfunction
    endclass

    // Base comum: monta o env, cada teste-filho so escolhe a sequence
    virtual class vending_test_base extends uvm_test;
        vending_env env;

        function new(string name, uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = vending_env::type_id::create("env", this);
        endfunction
    endclass

    // Cenario 1: compra bem-sucedida de cafe
    class vending_test_compra_sucesso extends vending_test_base;
        `uvm_component_utils(vending_test_compra_sucesso)

        function new(string name = "vending_test_compra_sucesso", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            vending_sequence_compra_sucesso seq;
            phase.raise_objection(this);
            seq = vending_sequence_compra_sucesso::type_id::create("seq");
            seq.start(env.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    // Cenario 2: credito insuficiente
    class vending_test_credito_insuficiente extends vending_test_base;
        `uvm_component_utils(vending_test_credito_insuficiente)

        function new(string name = "vending_test_credito_insuficiente", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            vending_sequence_credito_insuficiente seq;
            phase.raise_objection(this);
            seq = vending_sequence_credito_insuficiente::type_id::create("seq");
            seq.start(env.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    // Cenario 3: cancelamento com creditos acumulados
    class vending_test_cancelamento extends vending_test_base;
        `uvm_component_utils(vending_test_cancelamento)

        function new(string name = "vending_test_cancelamento", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            vending_sequence_cancelamento seq;
            phase.raise_objection(this);
            seq = vending_sequence_cancelamento::type_id::create("seq");
            seq.start(env.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    // Cenario 4: esgotamento de estoque
    class vending_test_estoque_esgotado extends vending_test_base;
        `uvm_component_utils(vending_test_estoque_esgotado)

        function new(string name = "vending_test_estoque_esgotado", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            vending_sequence_estoque_esgotado seq;
            phase.raise_objection(this);
            seq = vending_sequence_estoque_esgotado::type_id::create("seq");
            seq.start(env.sqr);
            phase.drop_objection(this);
        endtask
    endclass

endpackage