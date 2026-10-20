`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst;
    reg start;
    wire done;

    bilinear_scale #(
        .W_in(474),
        .H_in(296),
        .W_out(500),
        .H_out(500)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done)
    );

    // 100 MHz clock
    initial begin
        clk = 0;
        forever #5 clk=~clk;
    end

    initial begin

        rst=1;
        start=0;

        #20;
        rst=0;

        #10;

        start=1;
        #10;
        start=0;

        wait(done==1);

        $display("=================================");
        $display("Scaling finished!");
        $display("output.hex has been generated.");
        $display("=================================");

        #10;

        $finish;

    end

endmodule
