module block_renderer (
    input  logic [9:0] curr_pix_x,
    input  logic [9:0] curr_pix_y,
    input  logic [1:0] ui_state,
    input  logic [15:0] score,
    input  logic [2:0] next_piece,
    input  logic [3:0] cell_value,
    output logic       query_valid,
    output logic [3:0] query_x,
    output logic [4:0] query_y,
    output logic [11:0] pixel_color
);

localparam GRID_START_X      = 240;
localparam GRID_START_Y      = 80;
localparam GRID_WIDTH        = 160;
localparam GRID_HEIGHT       = 320;
localparam GRID_BORDER_OUTER = 2;
localparam GRID_BORDER_INNER = 3;

localparam HOLD_X            = 168;
localparam HOLD_Y            = 80;
localparam HOLD_W            = 56;
localparam HOLD_H            = 72;

localparam NEXT_X            = 416;
localparam NEXT_Y            = 80;
localparam NEXT_W            = 56;
localparam NEXT_H            = 104;

localparam SCORE_X           = 416;
localparam SCORE_Y           = 222;
localparam SCORE_W           = 56;
localparam SCORE_H           = 72;

localparam GO_X              = 270;
localparam GO_Y              = 190;
localparam GAME_X            = 246;
localparam GAME_Y            = 180;
localparam RETRY_X           = 272;
localparam RETRY_Y           = 222;

logic in_grid;
logic in_grid_outer;
logic in_hold_box;
logic in_next_box;
logic in_score_box;
logic [9:0] local_x;
logic [9:0] local_y;
logic [3:0] cell_x;
logic [4:0] cell_y;
logic [3:0] px;
logic [3:0] py;
logic [15:0] next_shape;

function automatic [14:0] glyph;
    input [7:0] ch;
    begin
        case (ch)
            "0": glyph = 15'b111101101101111; "1": glyph = 15'b010110010010111; "2": glyph = 15'b111001111100111;
            "3": glyph = 15'b111001111001111; "4": glyph = 15'b101101111001001; "5": glyph = 15'b111100111001111;
            "6": glyph = 15'b111100111101111; "7": glyph = 15'b111001001001001; "8": glyph = 15'b111101111101111;
            "9": glyph = 15'b111101111001111;
            "A": glyph = 15'b111101111101101; "C": glyph = 15'b111100100100111; "D": glyph = 15'b110101101101110;
            "E": glyph = 15'b111100110100111; "G": glyph = 15'b111100101101111; "H": glyph = 15'b101101111101101;
            "I": glyph = 15'b111010010010111; "L": glyph = 15'b100100100100111; "N": glyph = 15'b101111111111101;
            "O": glyph = 15'b111101101101111; "P": glyph = 15'b111101111100100; "R": glyph = 15'b110101110101101;
            "S": glyph = 15'b111100111001111; "T": glyph = 15'b111010010010010; "U": glyph = 15'b101101101101111;
            "V": glyph = 15'b101101101101010; "X": glyph = 15'b101101010101101; "Y": glyph = 15'b101101010010010;
            "!": glyph = 15'b010010010000010;
            default: glyph = 15'b000000000000000;
        endcase
    end
endfunction

function automatic logic hit;
    input [9:0] pxl_x;
    input [9:0] pxl_y;
    input [9:0] x0;
    input [9:0] y0;
    input [7:0] ch;
    input [1:0] scale_bits;
    integer gx;
    integer gy;
    reg [14:0] bits;
    begin
        hit = 1'b0;
        if ((pxl_x >= x0) && (pxl_x < x0 + (10'd3 << scale_bits)) &&
            (pxl_y >= y0) && (pxl_y < y0 + (10'd5 << scale_bits))) begin
            gx = (pxl_x - x0) >> scale_bits;
            gy = (pxl_y - y0) >> scale_bits;
            bits = glyph(ch);
            hit = bits[14 - (gy * 3 + gx)];
        end
    end
endfunction

function automatic [7:0] digit_char;
    input [3:0] digit;
    begin
        case (digit)
            4'd0: digit_char = "0";
            4'd1: digit_char = "1";
            4'd2: digit_char = "2";
            4'd3: digit_char = "3";
            4'd4: digit_char = "4";
            4'd5: digit_char = "5";
            4'd6: digit_char = "6";
            4'd7: digit_char = "7";
            4'd8: digit_char = "8";
            default: digit_char = "9";
        endcase
    end
endfunction

function automatic [15:0] piece_shape;
    input [2:0] piece;
    begin
        case (piece)
            3'd0: piece_shape = 16'b0000_1111_0000_0000; // I
            3'd1: piece_shape = 16'b0000_1100_1100_0000; // O
            3'd2: piece_shape = 16'b0000_0100_1110_0000; // T
            3'd3: piece_shape = 16'b1000_1000_1100_0000; // J
            3'd4: piece_shape = 16'b0100_0100_1100_0000; // L
            3'd5: piece_shape = 16'b0000_0110_1100_0000; // S
            default: piece_shape = 16'b0000_1100_0110_0000; // Z
        endcase
    end
endfunction

function automatic [11:0] block_base_color;
    input [3:0] id;
    begin
        case (id)
            4'h1: block_base_color = 12'h2BF;
            4'h2: block_base_color = 12'hFC2;
            4'h3: block_base_color = 12'hA3F;
            4'h4: block_base_color = 12'h26F;
            4'h5: block_base_color = 12'hF73;
            4'h6: block_base_color = 12'h2D7;
            default: block_base_color = 12'hD22;
        endcase
    end
endfunction

function automatic [11:0] block_light_color;
    input [3:0] id;
    begin
        case (id)
            4'h1: block_light_color = 12'h9EF;
            4'h2: block_light_color = 12'hFF9;
            4'h3: block_light_color = 12'hD9F;
            4'h4: block_light_color = 12'h8BF;
            4'h5: block_light_color = 12'hFBA;
            4'h6: block_light_color = 12'h9FC;
            default: block_light_color = 12'hF99;
        endcase
    end
endfunction

function automatic [11:0] block_shadow_color;
    input [3:0] id;
    begin
        case (id)
            4'h1: block_shadow_color = 12'h146;
            4'h2: block_shadow_color = 12'hA82;
            4'h3: block_shadow_color = 12'h426;
            4'h4: block_shadow_color = 12'h124;
            4'h5: block_shadow_color = 12'h842;
            4'h6: block_shadow_color = 12'h164;
            default: block_shadow_color = 12'h700;
        endcase
    end
endfunction

assign in_grid = (curr_pix_x >= GRID_START_X) && (curr_pix_x < GRID_START_X + GRID_WIDTH) &&
                 (curr_pix_y >= GRID_START_Y) && (curr_pix_y < GRID_START_Y + GRID_HEIGHT);
assign in_grid_outer = (curr_pix_x >= GRID_START_X - GRID_BORDER_OUTER) && (curr_pix_x < GRID_START_X + GRID_WIDTH + GRID_BORDER_OUTER) &&
                       (curr_pix_y >= GRID_START_Y - GRID_BORDER_OUTER) && (curr_pix_y < GRID_START_Y + GRID_HEIGHT + GRID_BORDER_OUTER);
assign in_hold_box = (curr_pix_x >= HOLD_X) && (curr_pix_x < HOLD_X + HOLD_W) &&
                     (curr_pix_y >= HOLD_Y) && (curr_pix_y < HOLD_Y + HOLD_H);
assign in_next_box = (curr_pix_x >= NEXT_X) && (curr_pix_x < NEXT_X + NEXT_W) &&
                     (curr_pix_y >= NEXT_Y) && (curr_pix_y < NEXT_Y + NEXT_H);
assign in_score_box = (curr_pix_x >= SCORE_X) && (curr_pix_x < SCORE_X + SCORE_W) &&
                      (curr_pix_y >= SCORE_Y) && (curr_pix_y < SCORE_Y + SCORE_H);

assign local_x = curr_pix_x - GRID_START_X;
assign local_y = curr_pix_y - GRID_START_Y;
assign cell_x  = local_x[7:4];
assign cell_y  = local_y[8:4];
assign px      = local_x[3:0];
assign py      = local_y[3:0];
assign next_shape = piece_shape(next_piece);

always_comb begin
    logic [9:0] preview_x;
    logic [9:0] preview_y;
    logic [1:0] preview_cell_x;
    logic [1:0] preview_cell_y;
    logic [3:0] preview_px_x;
    logic [3:0] preview_px_y;
    logic [3:0] render_id;
    logic       ghost_cell;
    query_valid = 1'b0;
    query_x     = 4'd0;
    query_y     = 5'd0;
    preview_x   = 10'd0;
    preview_y   = 10'd0;
    preview_cell_x = 2'd0;
    preview_cell_y = 2'd0;
    preview_px_x = 4'd0;
    preview_px_y = 4'd0;
    render_id   = 4'd0;
    ghost_cell  = 1'b0;
    pixel_color = curr_pix_x[6] ? 12'h000 : 12'h010;
    if (in_grid_outer) begin
        pixel_color = 12'hDDD;
    end

    if (in_grid) begin
        if ((px == 0) || (py == 0)) begin
            pixel_color = 12'h222;
        end else begin
            pixel_color = 12'h000;
        end
    end

    if (in_grid && (ui_state != 2'd0)) begin
        query_valid = 1'b1;
        query_x     = cell_x;
        query_y     = cell_y;
        ghost_cell  = (cell_value >= 4'd8);
        render_id   = ghost_cell ? (cell_value - 4'd7) : cell_value;

        if (cell_value == 4'h0) begin
            if ((px == 0) || (py == 0)) begin
                pixel_color = 12'h222;
            end else begin
                pixel_color = 12'h000;
            end
        end else if (ghost_cell) begin
            if ((px == 0) || (py == 0) || (px == 15) || (py == 15)) begin
                pixel_color = block_shadow_color(render_id);
            end else if (((px == 2) || (py == 2) || (px == 13) || (py == 13)) && !(px[1] ^ py[1])) begin
                pixel_color = block_base_color(render_id);
            end else begin
                pixel_color = 12'h000;
            end
        end else if ((px <= 1) || (py <= 1)) begin
            pixel_color = block_light_color(render_id);
        end else if ((px >= 14) || (py >= 14)) begin
            pixel_color = block_shadow_color(render_id);
        end else if ((px == 3) || (py == 3)) begin
            pixel_color = block_light_color(render_id);
        end else begin
            pixel_color = block_base_color(render_id);
        end
    end

    if (in_hold_box || in_next_box || in_score_box) begin
        pixel_color = 12'h000;
        if ((curr_pix_x == HOLD_X) || (curr_pix_x == HOLD_X + HOLD_W - 1) ||
            (curr_pix_y == HOLD_Y) || (curr_pix_y == HOLD_Y + HOLD_H - 1)) begin
            pixel_color = 12'hDDD;
        end
        if ((curr_pix_x == NEXT_X) || (curr_pix_x == NEXT_X + NEXT_W - 1) ||
            (curr_pix_y == NEXT_Y) || (curr_pix_y == NEXT_Y + NEXT_H - 1)) begin
            pixel_color = 12'hDDD;
        end
        if ((curr_pix_x == SCORE_X) || (curr_pix_x == SCORE_X + SCORE_W - 1) ||
            (curr_pix_y == SCORE_Y) || (curr_pix_y == SCORE_H + SCORE_Y - 1)) begin
            pixel_color = 12'hDDD;
        end
    end

    if (
        hit(curr_pix_x, curr_pix_y, HOLD_X - 2, HOLD_Y - 12, "H", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, HOLD_X + 2, HOLD_Y - 12, "O", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, HOLD_X + 6, HOLD_Y - 12, "L", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, HOLD_X + 10, HOLD_Y - 12, "D", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, NEXT_X + 12, NEXT_Y - 12, "N", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, NEXT_X + 16, NEXT_Y - 12, "E", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, NEXT_X + 20, NEXT_Y - 12, "X", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, NEXT_X + 24, NEXT_Y - 12, "T", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 6, SCORE_Y - 12, "S", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 10, SCORE_Y - 12, "C", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 14, SCORE_Y - 12, "O", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 18, SCORE_Y - 12, "R", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 22, SCORE_Y - 12, "E", 2'd0)
    ) begin
        pixel_color = 12'hDDD;
    end

    if (in_next_box) begin
        preview_x      = curr_pix_x - (NEXT_X + 4);
        preview_y      = curr_pix_y - (NEXT_Y + 20);
        preview_cell_x = preview_x[5:4];
        preview_cell_y = preview_y[5:4];
        preview_px_x   = preview_x[3:0];
        preview_px_y   = preview_y[3:0];

        if ((preview_x < 48) && (preview_y < 64) &&
            next_shape[15 - {preview_cell_y, preview_cell_x}]) begin
            if ((preview_px_x <= 1) || (preview_px_y <= 1)) begin
                pixel_color = block_light_color(next_piece + 4'd1);
            end else if ((preview_px_x >= 14) || (preview_px_y >= 14)) begin
                pixel_color = block_shadow_color(next_piece + 4'd1);
            end else if ((preview_px_x == 3) || (preview_px_y == 3)) begin
                pixel_color = block_light_color(next_piece + 4'd1);
            end else begin
                pixel_color = block_base_color(next_piece + 4'd1);
            end
        end
    end

    if (
        hit(curr_pix_x, curr_pix_y, SCORE_X + 6,  SCORE_Y + 14, "0", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 10, SCORE_Y + 14, "0", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 14, SCORE_Y + 14, digit_char(score[15:12]), 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 18, SCORE_Y + 14, digit_char(score[11:8]), 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 22, SCORE_Y + 14, digit_char(score[7:4]), 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 26, SCORE_Y + 14, digit_char(score[3:0]), 2'd0)
    ) begin
        pixel_color = 12'hDDD;
    end

    if (
        hit(curr_pix_x, curr_pix_y, SCORE_X + 20, SCORE_Y + 34, "0", 2'd0) ||
        hit(curr_pix_x, curr_pix_y, SCORE_X + 24, SCORE_Y + 34, "1", 2'd0)
    ) begin
        pixel_color = 12'hAAA;
    end

    if (ui_state == 2'd0) begin
        if (
            hit(curr_pix_x, curr_pix_y, GO_X, GO_Y, "G", 2'd2) ||
            hit(curr_pix_x, curr_pix_y, GO_X + 16, GO_Y, "O", 2'd2) ||
            hit(curr_pix_x, curr_pix_y, GO_X + 32, GO_Y, "!", 2'd2)
        ) begin
            pixel_color = curr_pix_y[2] ? 12'hECA : 12'hC96;
        end
    end else if (ui_state == 2'd2) begin
        if (
            hit(curr_pix_x, curr_pix_y, GAME_X,      GAME_Y, "G", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 8,  GAME_Y, "A", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 16, GAME_Y, "M", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 24, GAME_Y, "E", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 48, GAME_Y, "O", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 56, GAME_Y, "V", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 64, GAME_Y, "E", 2'd1) ||
            hit(curr_pix_x, curr_pix_y, GAME_X + 72, GAME_Y, "R", 2'd1)
        ) begin
            pixel_color = 12'hF88;
        end

        if (
            hit(curr_pix_x, curr_pix_y, RETRY_X,      RETRY_Y, "R", 2'd0) ||
            hit(curr_pix_x, curr_pix_y, RETRY_X + 4,  RETRY_Y, "E", 2'd0) ||
            hit(curr_pix_x, curr_pix_y, RETRY_X + 8,  RETRY_Y, "T", 2'd0) ||
            hit(curr_pix_x, curr_pix_y, RETRY_X + 12, RETRY_Y, "R", 2'd0) ||
            hit(curr_pix_x, curr_pix_y, RETRY_X + 16, RETRY_Y, "Y", 2'd0)
        ) begin
            pixel_color = 12'hCA4;
        end
    end
end

endmodule
