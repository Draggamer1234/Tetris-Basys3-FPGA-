module vga_controller (
    input  logic clk,
    input  logic rst,
    input  logic pixel_ce,
    output logic hsync,
    output logic vsync,
    output logic [9:0] x_pos,
    output logic [9:0] y_pos,
    output logic active
);

localparam int H_VIS   = 640;
localparam int H_FRONT = 16;
localparam int H_SYNC  = 96;
localparam int H_BACK  = 48;
localparam int H_TOTAL = H_VIS + H_FRONT + H_SYNC + H_BACK;

localparam int V_VIS   = 480;
localparam int V_FRONT = 10;
localparam int V_SYNC  = 2;
localparam int V_BACK  = 33;
localparam int V_TOTAL = V_VIS + V_FRONT + V_SYNC + V_BACK;

logic [9:0] h_count;
logic [9:0] v_count;

always_ff @(posedge clk) begin
    if (rst) begin
        h_count <= 10'd0;
        v_count <= 10'd0;
    end else if (pixel_ce) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;
            if (v_count == V_TOTAL - 1) begin
                v_count <= 10'd0;
            end else begin
                v_count <= v_count + 10'd1;
            end
        end else begin
            h_count <= h_count + 10'd1;
        end
    end
end

always_comb begin
    active = (h_count < H_VIS) && (v_count < V_VIS);
    x_pos  = active ? h_count : 10'd0;
    y_pos  = active ? v_count : 10'd0;
    hsync  = ~((h_count >= H_VIS + H_FRONT) && (h_count < H_VIS + H_FRONT + H_SYNC));
    vsync  = ~((v_count >= V_VIS + V_FRONT) && (v_count < V_VIS + V_FRONT + V_SYNC));
end

endmodule
