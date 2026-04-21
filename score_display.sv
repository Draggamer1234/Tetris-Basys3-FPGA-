module score_display (
    input  logic clk,
    input  logic rst,
    input  logic scan_ce,
    input  logic [15:0] score,
    output logic [3:0] an_cntrl,
    output logic [6:0] seg_cntrl
);

logic [1:0] dig_sel;
logic [3:0] dig;

always_ff @(posedge clk) begin
    if (rst) begin
        dig_sel <= 2'd0;
    end else if (scan_ce) begin
        dig_sel <= dig_sel + 2'd1;
    end
end

always_comb begin
    case (dig_sel)
        2'd0: begin
            dig      = score[3:0];
            an_cntrl = 4'b1110;
        end
        2'd1: begin
            dig      = score[7:4];
            an_cntrl = 4'b1101;
        end
        2'd2: begin
            dig      = score[11:8];
            an_cntrl = 4'b1011;
        end
        default: begin
            dig      = score[15:12];
            an_cntrl = 4'b0111;
        end
    endcase
end

segment_decoder seg_dec (
    .digit(dig),
    .seg  (seg_cntrl)
);

endmodule
