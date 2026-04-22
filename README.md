# Tetris-Basys3-FPGA-
FPGA Tetris for the Basys3 board with VGA output, coded in SystemVerilog.
This is a final project for EECE352 FPGA Design.

## Quick Start

### Requirements
- Digilent Basys3 FPGA board
- Xilinx Vivado
- VGA monitor and VGA cable
- USB cable for programming

### Build and Run
1. Open the project in Vivado.
2. Add all source files and include `basys3.xdc`.
3. Set `top_module.sv` as the top-level module.
4. Run synthesis, implementation, and bitstream generation.
5. Program the Basys3 in Vivado Hardware Manager.
6. Connect the board to a VGA monitor.

### Controls
- `Left Button` moves the piece left
- `Right Button` moves the piece right
- `Up Button` rotates the piece
- `Down Button` soft drops the piece
- `Center Button` starts or resets the game

### How to Play
- Start the game with the `Center Button` if needed.
- Move and rotate falling tetrominoes to complete horizontal lines.
- Completed lines are cleared automatically and increase your score.
- The game ends when a new piece can no longer spawn.

### Display
- The VGA display shows the playfield, score, and next-piece preview.
- The seven-segment display provides score-related output depending on the configuration.
