`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2026 20:20:37
// Design Name: 
// Module Name: tb_fifo_sv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_fifo;
    localparam DATA_WIDTH = 8;
    localparam DEPTH = 8;

    reg clk, rst, wr_enb, rd_enb;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire full, empty;

    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH), .ADDR_WIDTH(3)) dut (
        .clk(clk), .rst(rst), .wr_enb(wr_enb), .rd_enb(rd_enb),
        .data_in(data_in), .data_out(data_out), .full(full), .empty(empty)
    );

    // Reference model: expected FIFO contents
    reg [DATA_WIDTH-1:0] expected_q[$];
    reg [DATA_WIDTH-1:0] expected_data;
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_flags;
        begin
            if ((expected_q.size() == 0) && (empty !== 1'b1)) begin
                $error("SCOREBOARD FAIL: expected empty=1, actual empty=%b", empty);
                fail_count = fail_count + 1;
            end else if ((expected_q.size() != 0) && (empty !== 1'b0)) begin
                $error("SCOREBOARD FAIL: expected empty=0, actual empty=%b", empty);
                fail_count = fail_count + 1;
            end else if ((expected_q.size() == DEPTH) && (full !== 1'b1)) begin
                $error("SCOREBOARD FAIL: expected full=1, actual full=%b", full);
                fail_count = fail_count + 1;
            end else if ((expected_q.size() < DEPTH) && (full !== 1'b0)) begin
                $error("SCOREBOARD FAIL: expected full=0, actual full=%b", full);
                fail_count = fail_count + 1;
            end else begin
                $display("[%0t] PASS flags: queue_size=%0d full=%b empty=%b",
                         $time, expected_q.size(), full, empty);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task automatic do_write(input reg [DATA_WIDTH-1:0] value);
        begin
            @(negedge clk);
            wr_enb = 1'b1;
            rd_enb = 1'b0;
            data_in = value;
            @(posedge clk);
            if (expected_q.size() < DEPTH) begin
                expected_q.push_back(value);
                $display("[%0t] WRITE accepted: data_in=0x%02h", $time, value);
            end else begin
                $display("[%0t] WRITE blocked (FIFO full): data_in=0x%02h", $time, value);
            end
            #1;
            check_flags();
        end
    endtask

    task automatic do_read;
        begin
            @(negedge clk);
            wr_enb = 1'b0;
            rd_enb = 1'b1;
            @(posedge clk);
            if (expected_q.size() > 0) begin
                expected_data = expected_q.pop_front();
                #1;
                if (data_out === expected_data) begin
                    $display("[%0t] PASS read: expected=0x%02h actual=0x%02h",
                             $time, expected_data, data_out);
                    pass_count = pass_count + 1;
                end else begin
                    $error("[%0t] FAIL read: expected=0x%02h actual=0x%02h",
                           $time, expected_data, data_out);
                    fail_count = fail_count + 1;
                end
            end else begin
                #1;
                $display("[%0t] READ blocked (FIFO empty)", $time);
            end
            check_flags();
        end
    endtask

    initial begin
        rst = 1'b1;
        wr_enb = 1'b0;
        rd_enb = 1'b0;
        data_in = '0;
        expected_data = '0;

        repeat (2) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        check_flags();

        // Fill all 8 locations, then attempt an overflow write.
        for (i = 0; i < DEPTH; i = i + 1)
            do_write(8'hA0 + i);
        do_write(8'hFF);

        // Drain all entries in FIFO order, then attempt an underflow read.
        for (i = 0; i < DEPTH; i = i + 1)
            do_read();
        do_read();

        // Mixed operations also exercise pointer wrap-around.
        do_write(8'h11);
        do_write(8'h22);
        do_write(8'h33);
        do_read();
        do_write(8'h44);
        do_read();
        do_read();
        do_read();

        @(negedge clk);
        wr_enb = 1'b0;
        rd_enb = 1'b0;
        #2;
        $display("========================================");
        $display("FINAL RESULT: PASS checks=%0d, FAIL checks=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("OVERALL: TEST PASSED");
        else
            $display("OVERALL: TEST FAILED");
        $display("========================================");
        $finish;
    end
endmodule
