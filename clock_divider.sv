module clock_divider #(parameter DIVIDE_BY = 4)(
    input logic fast_clock,
    output logic slow_clock
);

logic [$clog2(DIVIDE_BY) - 1:0] counter = 0;

always @(posedge fast_clock) begin
    if(counter == DIVIDE_BY - 1) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end

assign slow_clock = (counter < (DIVIDE_BY / 2)) ? 1 : 0;

endmodule