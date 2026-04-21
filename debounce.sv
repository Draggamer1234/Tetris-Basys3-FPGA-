module debounce #(
    parameter integer STABLE_CYCLES = 500_000
) (
    input  logic clk,
    input  logic rst,
    input  logic noisy,
    output logic level,
    output logic pulse
);

localparam integer COUNT_W = (STABLE_CYCLES <= 1) ? 1 : $clog2(STABLE_CYCLES);

logic sync_ff0;
logic sync_ff1;
logic [COUNT_W-1:0] stable_count;

always_ff @(posedge clk) begin
    if (rst) begin
        sync_ff0     <= 1'b0;
        sync_ff1     <= 1'b0;
        stable_count <= '0;
        level        <= 1'b0;
        pulse        <= 1'b0;
    end else begin
        sync_ff0 <= noisy;
        sync_ff1 <= sync_ff0;
        pulse    <= 1'b0;

        if (sync_ff1 == level) begin
            stable_count <= '0;
        end else if (stable_count == STABLE_CYCLES - 1) begin
            stable_count <= '0;
            level        <= sync_ff1;
            pulse        <= sync_ff1;
        end else begin
            stable_count <= stable_count + 1'b1;
        end
    end
end

endmodule
