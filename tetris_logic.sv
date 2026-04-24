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
localparam logic [2:0] ST_EVAL     = 3'd2;
localparam logic [2:0] ST_LOCK     = 3'd3;
localparam logic [2:0] ST_SCAN     = 3'd4;
localparam logic [2:0] ST_SHIFT    = 3'd5;
localparam logic [2:0] ST_GAMEOVER = 3'd6;
localparam logic [9:0] FULL_ROW    = 10'h3FF;
localparam logic [6:0] FULL_BAG    = 7'b111_1111;

logic [2:0] state;
logic [3:0] board_mem [0:19][0:9];
logic [9:0] occ_mem [0:19];

logic [2:0] active_piece;
logic [1:0] active_rot;
logic signed [5:0] active_x;
logic [5:0] active_y;
logic [2:0] piece_index;
logic [15:0] rng_lfsr = 16'hACE1;
logic [6:0] bag_mask;
logic       bag_ready;

logic [4:0] scan_row;
logic [4:0] shift_row;
logic [2:0] lines_cleared;

logic signed [5:0] lock_x;
logic [5:0] lock_y;
logic [2:0] lock_piece;
logic [15:0] lock_shape;
logic [4:0] lock_cell;

logic [2:0] spawn_piece;
logic       spawn_collision;
logic [2:0] selected_next_piece;
logic [6:0] after_spawn_mask;
logic [6:0] next_select_mask;
logic [6:0] after_next_mask;
logic signed [5:0] requested_x;
logic [1:0] requested_rot;
logic signed [5:0] effective_x;
logic [1:0] effective_rot;
logic       move_attempt;
logic       move_accepted;
logic       fall_attempt;
logic       fall_accepted;
logic [15:0] spawn_shape;
logic [15:0] active_shape;
logic [15:0] requested_shape;
logic [15:0] effective_shape;

logic signed [5:0] pending_x;
logic [1:0] pending_rot;
logic [5:0] pending_y;
logic [2:0] pending_piece;
logic [15:0] pending_shape;
logic pending_move_attempt;
logic pending_fall_attempt;

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

function automatic [15:0] advance_lfsr;
    input [15:0] current_value;
    input        entropy_bit;
    logic feedback;
    begin
        feedback = current_value[15] ^ current_value[13] ^
                   current_value[12] ^ current_value[10] ^ entropy_bit;
        advance_lfsr = {current_value[14:0], feedback};
        if (advance_lfsr == 16'h0000) begin
            advance_lfsr = 16'hACE1;
        end
    end
endfunction

function automatic [2:0] wrap7;
    input [3:0] value;
    begin
        case (value)
            4'd0: wrap7 = 3'd0;
            4'd1: wrap7 = 3'd1;
            4'd2: wrap7 = 3'd2;
            4'd3: wrap7 = 3'd3;
            4'd4: wrap7 = 3'd4;
            4'd5: wrap7 = 3'd5;
            4'd6: wrap7 = 3'd6;
            4'd7: wrap7 = 3'd0;
            4'd8: wrap7 = 3'd1;
            4'd9: wrap7 = 3'd2;
            4'd10: wrap7 = 3'd3;
            4'd11: wrap7 = 3'd4;
            default: wrap7 = 3'd5;
        endcase
    end
endfunction

function automatic [2:0] select_bag_piece;
    input [6:0] mask;
    input [15:0] random_bits;
    logic [2:0] base;
    logic [2:0] idx;
    logic       found;
    integer step;
    begin
        base = (random_bits[2:0] == 3'd7) ? random_bits[5:3] : random_bits[2:0];
        if (base == 3'd7) begin
            base = random_bits[8:6];
        end
        if (base == 3'd7) begin
            base = 3'd0;
        end

        select_bag_piece = 3'd0;
        found = 1'b0;
        for (step = 0; step < 7; step = step + 1) begin
            idx = wrap7({1'b0, base} + step);
            if (!found && mask[idx]) begin
                select_bag_piece = idx;
                found = 1'b1;
            end
        end
    end
endfunction

function automatic [6:0] remove_bag_piece;
    input [6:0] mask;
    input [2:0] piece;
    begin
        remove_bag_piece = mask & ~(7'b000_0001 << piece);
    end
endfunction

function automatic [3:0] shape_row_bits;
    input [15:0] shape;
    input [1:0] row_idx;
    begin
        case (row_idx)
            2'd0: shape_row_bits = {shape[12], shape[13], shape[14], shape[15]};
            2'd1: shape_row_bits = {shape[8],  shape[9],  shape[10], shape[11]};
            2'd2: shape_row_bits = {shape[4],  shape[5],  shape[6],  shape[7]};
            default: shape_row_bits = {shape[0], shape[1], shape[2], shape[3]};
        endcase
    end
endfunction

function automatic logic row_x_out_of_bounds;
    input signed [5:0] piece_x;
    input [3:0] row_bits;
    begin
        case (piece_x)
            -6'sd3: row_x_out_of_bounds = |row_bits[2:0];
            -6'sd2: row_x_out_of_bounds = |row_bits[1:0];
            -6'sd1: row_x_out_of_bounds = row_bits[0];
             6'sd0,  6'sd1,  6'sd2,  6'sd3,
             6'sd4,  6'sd5,  6'sd6: row_x_out_of_bounds = 1'b0;
             6'sd7: row_x_out_of_bounds = row_bits[3];
             6'sd8: row_x_out_of_bounds = |row_bits[3:2];
             6'sd9: row_x_out_of_bounds = |row_bits[3:1];
            default: row_x_out_of_bounds = |row_bits;
        endcase
    end
endfunction

function automatic [9:0] row_board_mask;
    input signed [5:0] piece_x;
    input [3:0] row_bits;
    begin
        case (piece_x)
            -6'sd3: row_board_mask = {9'b0, row_bits[3]};
            -6'sd2: row_board_mask = {8'b0, row_bits[3:2]};
            -6'sd1: row_board_mask = {7'b0, row_bits[3:1]};
             6'sd0: row_board_mask = {6'b0, row_bits};
             6'sd1: row_board_mask = {5'b0, row_bits, 1'b0};
             6'sd2: row_board_mask = {4'b0, row_bits, 2'b0};
             6'sd3: row_board_mask = {3'b0, row_bits, 3'b0};
             6'sd4: row_board_mask = {2'b0, row_bits, 4'b0};
             6'sd5: row_board_mask = {1'b0, row_bits, 5'b0};
             6'sd6: row_board_mask = {row_bits, 6'b0};
             6'sd7: row_board_mask = {row_bits[2:0], 7'b0};
             6'sd8: row_board_mask = {row_bits[1:0], 8'b0};
             6'sd9: row_board_mask = {row_bits[0], 9'b0};
            default: row_board_mask = 10'b0;
        endcase
    end
endfunction

function automatic logic check_shape_collision;
    input [15:0] shape;
    input signed [5:0] piece_x;
    input [5:0] piece_y;
    integer row;
    logic [3:0] row_bits;
    logic [4:0] board_y;
    begin
        check_shape_collision = 1'b0;
        for (row = 0; row < 4; row = row + 1) begin
            row_bits = shape_row_bits(shape, row[1:0]);
            board_y = piece_y[4:0] + row[4:0];
            if (row_bits != 4'b0000) begin
                if (row_x_out_of_bounds(piece_x, row_bits) ||
                    ((piece_y + row[5:0]) > 6'd19)) begin
                    check_shape_collision = 1'b1;
                end else if ((row_board_mask(piece_x, row_bits) & occ_mem[board_y]) != 10'b0) begin
                    check_shape_collision = 1'b1;
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
    spawn_piece      = bag_ready ? piece_index : select_bag_piece(FULL_BAG, rng_lfsr);
    after_spawn_mask = bag_ready ? bag_mask : remove_bag_piece(FULL_BAG, spawn_piece);
    next_select_mask = (after_spawn_mask == 7'b000_0000) ? FULL_BAG : after_spawn_mask;
    selected_next_piece = select_bag_piece(next_select_mask, advance_lfsr(rng_lfsr, 1'b0));
    after_next_mask = remove_bag_piece(next_select_mask, selected_next_piece);
    spawn_shape = get_shape(spawn_piece, 2'd0);
    spawn_collision = (state == ST_SPAWN) && check_shape_collision(spawn_shape, 6'sd3, 6'd0);

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

    active_shape = get_shape(active_piece, active_rot);
    requested_shape = get_shape(active_piece, requested_rot);
    move_accepted = pending_move_attempt && (state == ST_EVAL) &&
                    !check_shape_collision(pending_shape, pending_x, pending_y);
    effective_x   = move_accepted ? pending_x : active_x;
    effective_rot = move_accepted ? pending_rot : active_rot;
    effective_shape = move_accepted ? pending_shape : active_shape;
    fall_accepted = !pending_fall_attempt || (state != ST_EVAL) ||
                    !check_shape_collision(effective_shape, effective_x, pending_y + 6'd1);
end

always_ff @(posedge gm_clk) begin
    integer i;
    integer j;
    integer gx;
    integer gy;

    rng_lfsr <= advance_lfsr(rng_lfsr, left_pulse ^ right_pulse ^ rotate_pulse ^
                                       down_pulse ^ down_level ^ move_ce ^ fall_ce);

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
        bag_mask     <= FULL_BAG;
        bag_ready    <= 1'b0;
        scan_row     <= 5'd0;
        shift_row    <= 5'd0;
        lines_cleared <= 3'd0;
        lock_x       <= 6'sd0;
        lock_y       <= 6'd0;
        lock_piece   <= 3'd0;
        lock_shape   <= 16'd0;
        lock_cell    <= 5'd0;
        pending_x    <= 6'sd3;
        pending_rot  <= 2'd0;
        pending_y    <= 6'd0;
        pending_piece <= 3'd0;
        pending_shape <= 16'd0;
        pending_move_attempt <= 1'b0;
        pending_fall_attempt <= 1'b0;
        score        <= 16'h0000;
    end else begin
        case (state)
            ST_SPAWN: begin
                active_piece <= spawn_piece;
                active_rot   <= 2'd0;
                active_x     <= 6'sd3;
                active_y     <= 6'd0;
                piece_index  <= selected_next_piece;
                bag_mask     <= after_next_mask;
                bag_ready    <= 1'b1;

                if (spawn_collision) begin
                    state <= ST_GAMEOVER;
                end else begin
                    state <= ST_PLAY;
                end
            end

            ST_PLAY: begin
                if (move_attempt || fall_attempt) begin
                    pending_x            <= requested_x;
                    pending_rot          <= requested_rot;
                    pending_y            <= active_y;
                    pending_piece        <= active_piece;
                    pending_shape        <= requested_shape;
                    pending_move_attempt <= move_attempt;
                    pending_fall_attempt <= fall_attempt;
                    state                <= ST_EVAL;
                end
            end

            ST_EVAL: begin
                if (move_accepted) begin
                    active_x   <= pending_x;
                    active_rot <= pending_rot;
                end

                if (pending_fall_attempt) begin
                    if (fall_accepted) begin
                        active_y <= pending_y + 6'd1;
                        state    <= ST_PLAY;
                    end else begin
                        lock_x     <= effective_x;
                        lock_y     <= pending_y;
                        lock_piece <= pending_piece;
                        lock_shape <= effective_shape;
                        lock_cell  <= 5'd0;
                        state      <= ST_LOCK;
                    end
                end else begin
                    state <= ST_PLAY;
                end
            end

            ST_LOCK: begin
                if (lock_cell == 5'd16) begin
                    scan_row      <= 5'd0;
                    lines_cleared <= 3'd0;
                    state         <= ST_SCAN;
                end else begin
                    if (lock_shape[15 - lock_cell[3:0]]) begin
                        gx = lock_x + $signed({4'b0000, lock_cell[1:0]});
                        gy = lock_y + lock_cell[3:2];
                        if ((gx >= 0) && (gx < 10) && (gy >= 0) && (gy < 20)) begin
                            board_mem[gy][gx] <= lock_piece + 4'd1;
                            occ_mem[gy][gx]   <= 1'b1;
                        end
                    end
                    lock_cell <= lock_cell + 5'd1;
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
    next_piece  = bag_ready ? piece_index : 3'd0;
    query_value = 4'h0;

    if (query_valid) begin
        query_value = board_mem[query_y][query_x];
    end

    if (query_valid && ((state == ST_PLAY) || (state == ST_EVAL))) begin
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
