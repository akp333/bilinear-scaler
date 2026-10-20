module bilinear_scale #(
    parameter W_in=4,
    parameter H_in=4,
    parameter W_out=6,
    parameter H_out=10
)(
    input clk,
    input rst,
    input start,
    output reg done
);

reg[7:0] input_img[0:H_in*W_in-1];
reg[7:0] output_img[0:H_out*W_out-1];

initial begin 
    $readmemh("input.hex", input_img);
end

localparam[15:0] scale_x=(W_in*256+W_out/2)/W_out;
localparam[15:0] scale_y=(H_in*256+H_out/2)/H_out;

reg running;
reg issued_last;
reg[15:0] cnt_x, cnt_y;

reg[31:0] s1_xin, s1_yin;
reg[15:0] s1_xout, s1_yout;
reg s1_valid;

reg[7:0] s2_a, s2_b;
reg[15:0] s2_x0, s2_y0, s2_x1, s2_y1;
reg[15:0] s2_xout, s2_yout;
reg s2_valid;

reg[15:0] s3_xout, s3_yout;
reg[15:0] s3_x0, s3_y0, s3_x1, s3_y1;
reg[7:0] s3_a, s3_b;
reg s3_valid;

reg[7:0] s4_I00, s4_I10, s4_I01, s4_I11;
reg[7:0] s4_a, s4_b;
reg[15:0] s4_xout, s4_yout;
reg s4_valid;

reg[23:0] val;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cnt_x<=0;
        cnt_y<=0;
        running<=0;
        done<=0;
        issued_last<=0;
    end
    else if(running) begin
        if(!issued_last) begin
            if(cnt_x==W_out-1) begin
                if(cnt_y==H_out-1) issued_last<=1;
                else begin
                    cnt_y<=cnt_y+1;
                    cnt_x<=0;
                end
            end
            else cnt_x<=cnt_x+1;
        end
        if(s4_valid && s4_xout==W_out-1 && s4_yout==H_out-1) begin
            done<=1;
            running<=0;
            issued_last<=0;
        end
    end
    else if (start) begin
        running<=1;
        cnt_x<=0;
        cnt_y<=0;
        done<=0;
        issued_last<=0;
    end
end

always @(posedge clk) begin
    s1_xin<=scale_x*cnt_x;
    s1_yin<=scale_y*cnt_y;
    s1_xout<=cnt_x;
    s1_yout<=cnt_y;
    s1_valid<=running;
end

always @(posedge clk) begin
    s2_x0<=((s1_xin>>8)>=(W_in-1))?(W_in-1):(s1_xin>>8);
    s2_y0<=((s1_yin>>8)>=(H_in-1))?(H_in-1):(s1_yin>>8);
    s2_x1<=((s1_xin>>8)>=(W_in-1))?(W_in-1):((s1_xin>>8)+1);
    s2_y1<=((s1_yin>>8)>=(H_in-1))?(H_in-1):((s1_yin>>8)+1);
    s2_a<=s1_xin[7:0];
    s2_b<=s1_yin[7:0];
    s2_xout<=s1_xout;
    s2_yout<=s1_yout;
    s2_valid<=s1_valid;
end

always @(posedge clk) begin
    s3_a<=s2_a;
    s3_b<=s2_b;
    s3_x0<=s2_x0;
    s3_y0<=s2_y0;
    s3_x1<=s2_x1;
    s3_y1<=s2_y1;
    s3_xout<=s2_xout;
    s3_yout<=s2_yout;
    s3_valid<=s2_valid;
end

always @(posedge clk) begin
    s4_I00<=input_img[s3_y0*W_in+s3_x0];
    s4_I10<=input_img[s3_y0*W_in+s3_x1];
    s4_I01<=input_img[s3_y1*W_in+s3_x0];
    s4_I11<=input_img[s3_y1*W_in+s3_x1];
    s4_a<=s3_a;
    s4_b<=s3_b;
    s4_xout<=s3_xout;
    s4_yout<=s3_yout;
    s4_valid<=s3_valid;
end

always @(posedge clk) begin
    if(s4_valid) begin
        val=(256-s4_a)*(256-s4_b)*s4_I00+s4_a*(256-s4_b)*s4_I10+(256-s4_a)*s4_b*s4_I01+s4_a*s4_b*s4_I11;
        output_img[s4_yout*W_out+s4_xout]<=(val+32768)>>16;
    end
end

always @(posedge clk) begin
    if(done) begin
        $writememh("output.hex",output_img);
    end
end

endmodule
