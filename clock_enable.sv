module clock_enable #(
    parameter integer DIVISOR = 4
) (
    input  logic clk,
    input  logic rst,
    output logic tick
);

localparam integer COUNT_W = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

logic [COUNT_W-1:0] count;

always_ff @(posedge clk) begin
    if (rst) begin
        count <= '0;
        tick  <= 1'b0;
    end else if (DIVISOR <= 1) begin
        count <= '0;
        tick  <= 1'b1;
    end else if (count == DIVISOR - 1) begin
        count <= '0;
        tick  <= 1'b1;
    end else begin
        count <= count + 1'b1;
        tick  <= 1'b0;
    end
end

endmodule
