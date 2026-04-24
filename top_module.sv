module top_module (
    input  logic clk,
    input  logic rst,
    input  logic btnL,
    input  logic btnU,
    input  logic btnD,
    input  logic btnR,
    output logic vga_hsync,
    output logic vga_vsync,
    output logic [3:0] vga_red,
    output logic [3:0] vga_green,
    output logic [3:0] vga_blue,
    output logic [3:0] an,
    output logic [6:0] seg
);

parameter int CLK_HZ     = 100_000_000;
parameter int GRAVITY_HZ = 2;
localparam int GRAVITY_DIV = CLK_HZ / GRAVITY_HZ;

logic pixel_ce;
logic scan_ce;
logic move_ce;
logic grav_ce;

logic up_level;
logic down_level;
logic left_level;
logic right_level;
logic up_pulse;
logic down_pulse;
logic left_pulse;
logic right_pulse;

logic [9:0] x_pos;
logic [9:0] y_pos;
logic active_video;
logic [11:0] rgb;
logic [15:0] score;
logic [3:0] cell_value;
logic [2:0] next_piece;
logic [1:0] ui_state;
logic game_over;
logic game_rst;
logic retry_start;
logic query_valid;
logic [3:0] query_x;
logic [4:0] query_y;

clock_enable #(.DIVISOR(4)) pixel_tick (
    .clk (clk),
    .rst (rst),
    .tick(pixel_ce)
);

clock_enable #(.DIVISOR(100_000)) scan_tick (
    .clk (clk),
    .rst (rst),
    .tick(scan_ce)
);

clock_enable #(.DIVISOR(2_000_000)) move_tick (
    .clk (clk),
    .rst (rst),
    .tick(move_ce)
);

clock_enable #(.DIVISOR(GRAVITY_DIV)) grav_tick (
    .clk (clk),
    .rst (rst),
    .tick(grav_ce)
);

debounce db_up (
    .clk  (clk),
    .rst  (rst),
    .noisy(btnU),
    .level(up_level),
    .pulse(up_pulse)
);

debounce db_down (
    .clk  (clk),
    .rst  (rst),
    .noisy(btnD),
    .level(down_level),
    .pulse(down_pulse)
);

debounce db_left (
    .clk  (clk),
    .rst  (rst),
    .noisy(btnL),
    .level(left_level),
    .pulse(left_pulse)
);

debounce db_right (
    .clk  (clk),
    .rst  (rst),
    .noisy(btnR),
    .level(right_level),
    .pulse(right_pulse)
);

always_ff @(posedge clk) begin
    if (rst) begin
        ui_state <= 2'd0;
    end else begin
        case (ui_state)
            2'd0: if (up_pulse) ui_state <= 2'd1;
            2'd1: if (game_over) ui_state <= 2'd2;
            2'd2: if (up_pulse) ui_state <= 2'd1;
            default: ui_state <= 2'd0;
        endcase
    end
end

assign retry_start = (ui_state == 2'd2) && up_pulse;
assign game_rst = rst || (ui_state == 2'd0) || retry_start;

vga_controller dsply (
    .clk     (clk),
    .rst     (rst),
    .pixel_ce(pixel_ce),
    .hsync   (vga_hsync),
    .vsync   (vga_vsync),
    .x_pos   (x_pos),
    .y_pos   (y_pos),
    .active  (active_video)
);

score_display score_dsp (
    .clk      (clk),
    .rst      (rst),
    .scan_ce  (scan_ce),
    .score    (score),
    .an_cntrl (an),
    .seg_cntrl(seg)
);

block_renderer renderer (
    .curr_pix_x(x_pos),
    .curr_pix_y(y_pos),
    .ui_state  (ui_state),
    .score     (score),
    .next_piece(next_piece),
    .cell_value(cell_value),
    .query_valid(query_valid),
    .query_x   (query_x),
    .query_y   (query_y),
    .pixel_color(rgb)
);

tetris_logic game (
    .gm_clk      (clk),
    .gm_rst      (game_rst),
    .move_ce     ((ui_state == 2'd1) ? move_ce : 1'b0),
    .fall_ce     ((ui_state == 2'd1) ? grav_ce : 1'b0),
    .left_pulse  ((ui_state == 2'd1) ? left_pulse : 1'b0),
    .right_pulse ((ui_state == 2'd1) ? right_pulse : 1'b0),
    .rotate_pulse((ui_state == 2'd1) ? up_pulse : 1'b0),
    .down_pulse  ((ui_state == 2'd1) ? down_pulse : 1'b0),
    .down_level  ((ui_state == 2'd1) ? down_level : 1'b0),
    .query_valid (query_valid),
    .query_x     (query_x),
    .query_y     (query_y),
    .query_value (cell_value),
    .score       (score),
    .next_piece  (next_piece),
    .game_over   (game_over)
);

always_comb begin
    if (active_video) begin
        vga_red   = rgb[11:8];
        vga_green = rgb[7:4];
        vga_blue  = rgb[3:0];
    end else begin
        vga_red   = 4'h0;
        vga_green = 4'h0;
        vga_blue  = 4'h0;
    end
end

endmodule
