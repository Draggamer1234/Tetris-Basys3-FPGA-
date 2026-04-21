module tetris_logic (
    input  logic       gm_clk,
    input  logic       gm_rst,
    input  logic       move_ce,
    input  logic       fall_ce,
    input  logic       left_pulse,
    input  logic       right_pulse,
    input  logic       rotate_pulse,
    input  logic       down_pulse,
    input  logic       down_level,
    input  logic       query_valid,
    input  logic [3:0] query_x,
    input  logic [4:0] query_y,
    output logic [3:0] query_value,
    output logic [15:0] score,
    output logic [2:0] next_piece,
    output logic       game_over
);

localparam logic [2:0] ST_SPAWN    = 3'd0;
localparam logic [2:0] ST_PLAY     = 3'd1;
localparam logic [2:0] ST_SCAN     = 3'd2;
localparam logic [2:0] ST_SHIFT    = 3'd3;
localparam logic [2:0] ST_GAMEOVER = 3'd4;
localparam logic [9:0] FULL_ROW    = 10'h3FF;

logic [2:0] state;
logic [3:0] board_mem [0:19][0:9];
logic [9:0] occ_mem [0:19];

logic [2:0] active_piece;
logic [1:0] active_rot;
logic signed [5:0] active_x;
logic [5:0] active_y;
logic [2:0] piece_index;

logic [4:0] scan_row;
logic [4:0] shift_row;
logic [2:0] lines_cleared;

logic [2:0] spawn_piece;
logic       spawn_collision;
logic signed [5:0] requested_x;
logic [1:0] requested_rot;
logic signed [5:0] effective_x;
logic [1:0] effective_rot;
logic       move_attempt;
logic       move_accepted;
logic       fall_attempt;
logic       fall_accepted;
logic [15:0] active_shape;
logic [15:0] effective_shape;

function automatic [15:0] get_shape;
    input [2:0] piece_type;
    input [1:0] piece_rot;
    begin
        case (piece_type)
            3'd0: get_shape = piece_rot[0] ? 16'b1000_1000_1000_1000 : 16'b0000_1111_0000_0000; // I
            3'd1: get_shape = 16'b0000_1100_1100_0000;                                           // O
            3'd2: begin                                                                           // T
                case (piece_rot)
                    2'd0: get_shape = 16'b0000_0100_1110_0000;
                    2'd1: get_shape = 16'b0000_1000_1100_1000;
                    2'd2: get_shape = 16'b0000_0000_1110_0100;
                    default: get_shape = 16'b0000_0100_1100_0100;
                endcase
            end
            3'd3: begin                                                                           // J
                case (piece_rot)
                    2'd0: get_shape = 16'b1000_1000_1100_0000;
                    2'd1: get_shape = 16'b0000_0100_1110_0000;
                    2'd2: get_shape = 16'b0000_1100_0100_0100;
                    default: get_shape = 16'b0000_1110_1000_0000;
                endcase
            end
            3'd4: begin                                                                           // L
                case (piece_rot)
                    2'd0: get_shape = 16'b0100_0100_1100_0000;
                    2'd1: get_shape = 16'b0000_1110_0010_0000;
                    2'd2: get_shape = 16'b0000_1100_1000_1000;
                    default: get_shape = 16'b0000_1000_1110_0000;
                endcase
            end
            3'd5: get_shape = piece_rot[0] ? 16'b0000_1000_1100_0100 : 16'b0000_0110_1100_0000; // S
            3'd6: get_shape = piece_rot[0] ? 16'b0000_0100_1100_1000 : 16'b0000_1100_0110_0000; // Z
            default: get_shape = 16'b0;
        endcase
    end
endfunction

function automatic logic check_collision;
    input [2:0] piece_type;
    input [1:0] piece_rot;
    input signed [5:0] piece_x;
    input [5:0] piece_y;
    logic [15:0] shape;
    integer i;
    integer j;
    integer grid_x;
    integer grid_y;
    begin
        shape = get_shape(piece_type, piece_rot);
        check_collision = 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                if (shape[15 - (i * 4 + j)]) begin
                    grid_x = piece_x + j;
                    grid_y = piece_y + i;
                    if ((grid_x < 0) || (grid_x > 9) || (grid_y > 19)) begin
                        check_collision = 1'b1;
                    end else if ((grid_y >= 0) && occ_mem[grid_y][grid_x]) begin
                        check_collision = 1'b1;
                    end
                end
            end
        end
    end
endfunction

function automatic logic row_is_full;
    input [4:0] row_idx;
    begin
        row_is_full = (occ_mem[row_idx] == FULL_ROW);
    end
endfunction

function automatic [15:0] add_score_bcd;
    input [15:0] old_score;
    input [2:0] lines_done;
    reg [4:0] hsum;
    reg [4:0] tsum;
    reg [4:0] add_h;
    begin
        add_h = 5'd0;
        case (lines_done)
            3'd1: add_h = 5'd1;
            3'd2: add_h = 5'd4;
            3'd3: add_h = 5'd9;
            3'd4: add_h = 5'd16;
            default: add_h = 5'd0;
        endcase

        hsum = old_score[11:8] + add_h;
        tsum = old_score[15:12];
        if (hsum >= 20) begin
            hsum = hsum - 20;
            tsum = tsum + 2;
        end else if (hsum >= 10) begin
            hsum = hsum - 10;
            tsum = tsum + 1;
        end

        if (tsum > 9) begin
            add_score_bcd = 16'h9900;
        end else begin
            add_score_bcd = {tsum[3:0], hsum[3:0], 8'h00};
        end
    end
endfunction

always_comb begin
    spawn_piece     = piece_index;
    spawn_collision = check_collision(spawn_piece, 2'd0, 6'sd3, 6'd0);

    requested_x   = active_x;
    requested_rot = active_rot;
    move_attempt  = 1'b0;
    fall_attempt  = fall_ce || down_pulse || (move_ce && down_level);

    if (rotate_pulse) begin
        requested_rot = active_rot + 2'd1;
        move_attempt  = 1'b1;
    end else if (left_pulse && !right_pulse) begin
        requested_x  = active_x - 6'sd1;
        move_attempt = 1'b1;
    end else if (right_pulse && !left_pulse) begin
        requested_x  = active_x + 6'sd1;
        move_attempt = 1'b1;
    end

    move_accepted = move_attempt && !check_collision(active_piece, requested_rot, requested_x, active_y);
    effective_x   = move_accepted ? requested_x : active_x;
    effective_rot = move_accepted ? requested_rot : active_rot;
    fall_accepted = !check_collision(active_piece, effective_rot, effective_x, active_y + 6'd1);
    active_shape  = get_shape(active_piece, active_rot);
    effective_shape = get_shape(active_piece, effective_rot);
end

always_ff @(posedge gm_clk) begin
    integer i;
    integer j;
    integer rr;
    integer cc;
    integer gx;
    integer gy;

    if (gm_rst) begin
        for (i = 0; i < 20; i = i + 1) begin
            for (j = 0; j < 10; j = j + 1) begin
                board_mem[i][j] <= 4'h0;
            end
            occ_mem[i] <= '0;
        end

        state        <= ST_SPAWN;
        active_piece <= 3'd0;
        active_rot   <= 2'd0;
        active_x     <= 6'sd3;
        active_y     <= 6'd0;
        piece_index  <= 3'd0;
        scan_row     <= 5'd0;
        shift_row    <= 5'd0;
        lines_cleared <= 3'd0;
        score        <= 16'h0000;
    end else begin
        case (state)
            ST_SPAWN: begin
                active_piece <= spawn_piece;
                active_rot   <= 2'd0;
                active_x     <= 6'sd3;
                active_y     <= 6'd0;
                piece_index  <= (piece_index == 3'd6) ? 3'd0 : (piece_index + 3'd1);

                if (spawn_collision) begin
                    state <= ST_GAMEOVER;
                end else begin
                    state <= ST_PLAY;
                end
            end

            ST_PLAY: begin
                if (move_accepted) begin
                    active_x   <= requested_x;
                    active_rot <= requested_rot;
                end

                if (fall_attempt) begin
                    if (fall_accepted) begin
                        active_y <= active_y + 6'd1;
                    end else begin
                        for (rr = 0; rr < 4; rr = rr + 1) begin
                            for (cc = 0; cc < 4; cc = cc + 1) begin
                                if (effective_shape[15 - (rr * 4 + cc)]) begin
                                    gx = effective_x + cc;
                                    gy = active_y + rr;
                                    if ((gx >= 0) && (gx < 10) && (gy >= 0) && (gy < 20)) begin
                                        board_mem[gy][gx] <= active_piece + 4'd1;
                                        occ_mem[gy][gx]   <= 1'b1;
                                    end
                                end
                            end
                        end

                        scan_row      <= 5'd0;
                        lines_cleared <= 3'd0;
                        state         <= ST_SCAN;
                    end
                end
            end

            ST_SCAN: begin
                if (scan_row == 20) begin
                    score <= add_score_bcd(score, lines_cleared);
                    state      <= ST_SPAWN;
                end else if (row_is_full(scan_row)) begin
                    lines_cleared <= lines_cleared + 3'd1;
                    shift_row     <= scan_row;
                    state         <= ST_SHIFT;
                end else begin
                    scan_row <= scan_row + 5'd1;
                end
            end

            ST_SHIFT: begin
                if (shift_row != 0) begin
                    for (j = 0; j < 10; j = j + 1) begin
                        board_mem[shift_row][j] <= board_mem[shift_row - 1][j];
                    end
                    occ_mem[shift_row] <= occ_mem[shift_row - 1];
                    shift_row <= shift_row - 5'd1;
                end else begin
                    for (j = 0; j < 10; j = j + 1) begin
                        board_mem[0][j] <= 4'h0;
                    end
                    occ_mem[0] <= '0;
                    state      <= ST_SCAN;
                end
            end

            default: begin
                state <= ST_GAMEOVER;
            end
        endcase
    end
end

always_comb begin
    integer rel_x;
    integer rel_y;

    game_over   = (state == ST_GAMEOVER);
    next_piece  = piece_index;
    query_value = 4'h0;

    if (query_valid) begin
        query_value = board_mem[query_y][query_x];
    end

    if (query_valid && (state == ST_PLAY)) begin
        rel_x = $signed({1'b0, query_x}) - active_x;
        rel_y = $signed({1'b0, query_y}) - $signed({1'b0, active_y[4:0]});
        if ((rel_x >= 0) && (rel_x < 4) &&
            (rel_y >= 0) && (rel_y < 4) &&
            active_shape[15 - (rel_y * 4 + rel_x)]) begin
            query_value = active_piece + 4'd1;
        end
    end
end

endmodule
