`timescale 1ns/1ps

module sdram_controller #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 16
)(
    input  wire                  clk,
    input  wire                  reset_n,

    // User interface
    input  wire                  write_req,
    input  wire                  read_req,
    input  wire [ADDR_WIDTH-1:0] address,
    input  wire [DATA_WIDTH-1:0] write_data,

    output reg  [DATA_WIDTH-1:0] read_data,
    output reg                   read_valid,
    output reg                   busy,

    // SDRAM interface
    output reg                   sdram_cs_n,
    output reg                   sdram_ras_n,
    output reg                   sdram_cas_n,
    output reg                   sdram_we_n,
    output reg  [3:0]             sdram_addr,
    inout  wire [DATA_WIDTH-1:0]  sdram_dq,
    output reg                   sdram_cke
);

    // =========================================================
    // FSM STATES
    // =========================================================

    localparam ST_INIT      = 4'd0;
    localparam ST_IDLE      = 4'd1;
    localparam ST_ACTIVATE  = 4'd2;
    localparam ST_WRITE     = 4'd3;
    localparam ST_READ_CMD  = 4'd4;
    localparam ST_READ_WAIT = 4'd5;
    localparam ST_READ_DATA = 4'd6;
    localparam ST_REFRESH   = 4'd7;

    reg [3:0] state;

    // =========================================================
    // TRANSACTION REGISTERS
    // =========================================================

    reg [ADDR_WIDTH-1:0]  saved_address;
    reg [DATA_WIDTH-1:0]  saved_write_data;
    reg                   saved_is_write;

    reg [3:0] init_count;
    reg [7:0] refresh_count;

    // =========================================================
    // SDRAM DATA BUS
    // =========================================================

    reg [DATA_WIDTH-1:0] dq_out;
    reg                  dq_oe;

    assign sdram_dq = dq_oe ? dq_out : {DATA_WIDTH{1'bz}};

    // =========================================================
    // SDRAM COMMAND OUTPUTS
    // =========================================================

    always @(*) begin

        // Default = NOP
        sdram_cs_n  = 1'b0;
        sdram_ras_n = 1'b1;
        sdram_cas_n = 1'b1;
        sdram_we_n  = 1'b1;

        sdram_addr  = 4'd0;
        sdram_cke   = 1'b1;

        // Busy except in IDLE
        if (state == ST_IDLE)
            busy = 1'b0;
        else
            busy = 1'b1;

        case (state)

            ST_ACTIVATE: begin

                // ACTIVE command
                sdram_ras_n = 1'b0;
                sdram_addr  = saved_address[7:4];

            end

            ST_WRITE: begin

                // WRITE command
                sdram_cas_n = 1'b0;
                sdram_we_n  = 1'b0;
                sdram_addr  = saved_address[3:0];

            end

            ST_READ_CMD: begin

                // READ command
                sdram_cas_n = 1'b0;
                sdram_we_n  = 1'b1;
                sdram_addr  = saved_address[3:0];

            end

            ST_REFRESH: begin

                // AUTO REFRESH command
                sdram_ras_n = 1'b0;
                sdram_cas_n = 1'b0;
                sdram_we_n  = 1'b1;

            end

            default: begin

                // NOP

            end

        endcase

    end

    // =========================================================
    // SDRAM DATA OUTPUT
    // =========================================================

    always @(*) begin

        dq_out = saved_write_data;

        if (state == ST_WRITE)
            dq_oe = 1'b1;
        else
            dq_oe = 1'b0;

    end

    // =========================================================
    // CONTROLLER FSM
    // =========================================================

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            state            <= ST_INIT;

            saved_address    <= 8'd0;
            saved_write_data <= 16'd0;
            saved_is_write   <= 1'b0;

            read_data        <= 16'd0;
            read_valid       <= 1'b0;

            init_count       <= 4'd0;
            refresh_count    <= 8'd0;

        end
        else begin

            // Default
            read_valid <= 1'b0;

            case (state)

                // =================================================
                // INITIALIZATION
                // =================================================

                ST_INIT: begin

                    if (init_count == 4'd5) begin

                        state         <= ST_IDLE;
                        refresh_count <= 8'd0;

                    end
                    else begin

                        init_count <= init_count + 1'b1;

                    end

                end

                // =================================================
                // IDLE
                // =================================================

                ST_IDLE: begin

                    if (write_req) begin

                        saved_address    <= address;
                        saved_write_data <= write_data;
                        saved_is_write   <= 1'b1;

                        refresh_count <= 8'd0;

                        state <= ST_ACTIVATE;

                    end
                    else if (read_req) begin

                        saved_address  <= address;
                        saved_is_write <= 1'b0;

                        refresh_count <= 8'd0;

                        state <= ST_ACTIVATE;

                    end
                    else if (refresh_count == 8'd9) begin

                        refresh_count <= 8'd0;

                        state <= ST_REFRESH;

                    end
                    else begin

                        refresh_count <= refresh_count + 1'b1;

                    end

                end

                // =================================================
                // ACTIVATE
                // =================================================

                ST_ACTIVATE: begin

                    if (saved_is_write)
                        state <= ST_WRITE;
                    else
                        state <= ST_READ_CMD;

                end

                // =================================================
                // WRITE
                // =================================================

                ST_WRITE: begin

                    state <= ST_IDLE;

                end

                // =================================================
                // READ COMMAND
                // =================================================

                ST_READ_CMD: begin

                    state <= ST_READ_WAIT;

                end

                // =================================================
                // READ WAIT
                // =================================================

                ST_READ_WAIT: begin

                    state <= ST_READ_DATA;

                end

                // =================================================
                // READ DATA
                // =================================================

                ST_READ_DATA: begin

                    read_data  <= sdram_dq;
                    read_valid <= 1'b1;

                    state <= ST_IDLE;

                end

                // =================================================
                // REFRESH
                // =================================================

                ST_REFRESH: begin

                    state <= ST_IDLE;

                end

                default: begin

                    state <= ST_INIT;

                end

            endcase

        end

    end

endmodule