`timescale 1ns/1ps

module sdram_controller_tb;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 16;

    // =========================================================
    // CLOCK / RESET
    // =========================================================

    reg clk;
    reg reset_n;

    // =========================================================
    // USER INTERFACE
    // =========================================================

    reg                   write_req;
    reg                   read_req;
    reg  [ADDR_WIDTH-1:0] address;
    reg  [DATA_WIDTH-1:0] write_data;

    wire [DATA_WIDTH-1:0] read_data;
    wire                  read_valid;
    wire                  busy;

    // =========================================================
    // SDRAM INTERFACE
    // =========================================================

    wire                  sdram_cs_n;
    wire                  sdram_ras_n;
    wire                  sdram_cas_n;
    wire                  sdram_we_n;
    wire [3:0]            sdram_addr;
    wire [DATA_WIDTH-1:0] sdram_dq;
    wire                  sdram_cke;

    // =========================================================
    // BEHAVIORAL SDRAM MEMORY
    // =========================================================

    reg [DATA_WIDTH-1:0] memory [0:255];

    reg [3:0] active_row;

    reg [DATA_WIDTH-1:0] sdram_dq_reg;
    reg                  sdram_dq_oe;

    assign sdram_dq =
        sdram_dq_oe ? sdram_dq_reg :
        {DATA_WIDTH{1'bz}};

    // =========================================================
    // TEST VARIABLES
    // =========================================================

    integer i;
    integer error_count;
    integer write_count;
    integer read_count;

    // =========================================================
    // DUT
    // =========================================================

    sdram_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .reset_n    (reset_n),

        .write_req  (write_req),
        .read_req   (read_req),
        .address    (address),
        .write_data (write_data),

        .read_data  (read_data),
        .read_valid (read_valid),
        .busy        (busy),

        .sdram_cs_n  (sdram_cs_n),
        .sdram_ras_n (sdram_ras_n),
        .sdram_cas_n (sdram_cas_n),
        .sdram_we_n  (sdram_we_n),
        .sdram_addr  (sdram_addr),
        .sdram_dq    (sdram_dq),
        .sdram_cke   (sdram_cke)
    );

    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;

    // =========================================================
    // SDRAM BEHAVIORAL MODEL
    // =========================================================
    //
    // IMPORTANT:
    // During a READ, the SDRAM keeps driving the data bus.
    // It does NOT release the bus immediately.
    //
    // The controller needs time to sample the returned data.
    // =========================================================

    always @(negedge clk) begin

        if (!reset_n) begin

            sdram_dq_oe  = 1'b0;
            sdram_dq_reg = 16'd0;

        end
        else begin

            // -------------------------------------------------
            // ACTIVE COMMAND
            // -------------------------------------------------

            if (!sdram_cs_n &&
                !sdram_ras_n &&
                 sdram_cas_n &&
                 sdram_we_n) begin

                active_row = sdram_addr;

                $display(
                    "[SDRAM] ACTIVATE Row=%0d Time=%0t",
                    active_row,
                    $time
                );

            end

            // -------------------------------------------------
            // WRITE COMMAND
            // -------------------------------------------------

            if (!sdram_cs_n &&
                 sdram_ras_n &&
                !sdram_cas_n &&
                !sdram_we_n) begin

                memory[{active_row, sdram_addr}] = sdram_dq;

                $display(
                    "[SDRAM] WRITE Address=%0d Data=%0d Time=%0t",
                    {active_row, sdram_addr},
                    sdram_dq,
                    $time
                );

                // Release bus after WRITE
                sdram_dq_oe = 1'b0;

            end

            // -------------------------------------------------
            // READ COMMAND
            // -------------------------------------------------

            if (!sdram_cs_n &&
                 sdram_ras_n &&
                !sdram_cas_n &&
                 sdram_we_n) begin

                // Put requested memory value onto SDRAM bus
                sdram_dq_reg =
                    memory[{active_row, sdram_addr}];

                // Keep driving the bus
                sdram_dq_oe = 1'b1;

                $display(
                    "[SDRAM] READ Address=%0d Data=%0d Time=%0t",
                    {active_row, sdram_addr},
                    memory[{active_row, sdram_addr}],
                    $time
                );

            end

            // -------------------------------------------------
            // REFRESH COMMAND
            // -------------------------------------------------

            if (!sdram_cs_n &&
                !sdram_ras_n &&
                !sdram_cas_n &&
                 sdram_we_n) begin

                $display(
                    "[SDRAM] REFRESH Time=%0t",
                    $time
                );

            end

        end

    end

    // =========================================================
    // WRITE TASK
    // =========================================================

    task do_write;

        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;

        begin

            while (busy)
                @(posedge clk);

            @(negedge clk);

            address    = addr;
            write_data = data;
            write_req  = 1'b1;

            $display("");
            $display(
                "[TEST] WRITE Request Address=%0d Data=%0d",
                addr,
                data
            );

            @(negedge clk);

            write_req = 1'b0;

            write_count = write_count + 1;

            while (busy)
                @(posedge clk);

        end

    endtask

    // =========================================================
    // READ TASK
    // =========================================================

    task do_read;

        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected;

        begin

            while (busy)
                @(posedge clk);

            @(negedge clk);

            address  = addr;
            read_req = 1'b1;

            $display("");
            $display(
                "[TEST] READ Request Address=%0d Expected=%0d",
                addr,
                expected
            );

            @(negedge clk);

            read_req = 1'b0;

            // Wait until controller says data is valid
            while (!read_valid)
                @(posedge clk);

            #1;

            read_count = read_count + 1;

            if (read_data === expected) begin

                $display(
                    "[PASS] READ Address=%0d Data=%0d",
                    addr,
                    read_data
                );

            end
            else begin

                $display(
                    "[ERROR] READ Address=%0d Expected=%0d Got=%0d",
                    addr,
                    expected,
                    read_data
                );

                error_count = error_count + 1;

            end

            while (busy)
                @(posedge clk);

            // Release SDRAM bus after controller has sampled data
            @(negedge clk);

            sdram_dq_oe = 1'b0;

        end

    endtask

    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        // -----------------------------------------------------
        // INITIAL VALUES
        // -----------------------------------------------------

        clk = 1'b0;
        reset_n = 1'b0;

        write_req = 1'b0;
        read_req  = 1'b0;

        address    = 8'd0;
        write_data = 16'd0;

        sdram_dq_reg = 16'd0;
        sdram_dq_oe  = 1'b0;

        active_row = 4'd0;

        error_count = 0;
        write_count = 0;
        read_count  = 0;

        // -----------------------------------------------------
        // CLEAR MEMORY
        // -----------------------------------------------------

        for (i = 0; i < 256; i = i + 1)
            memory[i] = 16'd0;

        // -----------------------------------------------------
        // HEADER
        // -----------------------------------------------------

        $display("");
        $display("==========================================");
        $display("        SDRAM CONTROLLER TEST");
        $display("==========================================");
        $display("");

        // -----------------------------------------------------
        // RESET
        // -----------------------------------------------------

        repeat (4)
            @(posedge clk);

        reset_n = 1'b1;

        $display("[TEST] Reset released.");

        // -----------------------------------------------------
        // INITIALIZATION
        // -----------------------------------------------------

        while (busy)
            @(posedge clk);

        $display("[PASS] SDRAM initialization complete.");

        // =====================================================
        // TEST 1: WRITE
        // =====================================================

        $display("");
        $display("==========================================");
        $display("TEST 1: WRITE");
        $display("==========================================");

        do_write(8'd16, 16'd1234);
        do_write(8'd32, 16'd5678);
        do_write(8'd48, 16'd4321);

        // =====================================================
        // TEST 2: READ
        // =====================================================

        $display("");
        $display("==========================================");
        $display("TEST 2: READ");
        $display("==========================================");

        do_read(8'd16, 16'd1234);
        do_read(8'd32, 16'd5678);
        do_read(8'd48, 16'd4321);

        // =====================================================
        // TEST 3: REFRESH
        // =====================================================

        $display("");
        $display("==========================================");
        $display("TEST 3: REFRESH");
        $display("==========================================");

        repeat (15)
            @(posedge clk);

        $display("[PASS] Refresh operation completed.");

        // =====================================================
        // TEST 4: READ AFTER REFRESH
        // =====================================================

        $display("");
        $display("==========================================");
        $display("TEST 4: READ AFTER REFRESH");
        $display("==========================================");

        do_read(8'd16, 16'd1234);
        do_read(8'd32, 16'd5678);
        do_read(8'd48, 16'd4321);

        // =====================================================
        // FINAL SUMMARY
        // =====================================================

        $display("");
        $display("==========================================");
        $display("             TEST SUMMARY");
        $display("==========================================");

        $display("Total Writes : %0d", write_count);
        $display("Total Reads  : %0d", read_count);
        $display("Errors       : %0d", error_count);

        if (error_count == 0) begin

            $display("");
            $display("==========================================");
            $display("          *** TEST PASSED ***");
            $display("==========================================");
            $display("");

        end
        else begin

            $display("");
            $display("==========================================");
            $display("          *** TEST FAILED ***");
            $display("==========================================");
            $display("");

        end

        #50;

        $finish;

    end

endmodule