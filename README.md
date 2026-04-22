# Tetris-Basys3-FPGA-
FPGA Tetris for the Basys3 board with VGA output, responsive controls, score display, and classic arcade-style gameplay in SystemVerilog.
This is a final project for EECE352 FPGA Design.

Quick Start:
Open the project in Vivado and make sure the Basys3 constraints file basys3.xdc is included.
Set the target board/device to the Basys3 and use top_module.sv as the top-level design.
Run synthesis, implementation, and generate the bitstream.
Program the Basys3 FPGA with the generated bitstream.
Connect the board to a VGA monitor and power it on.

Controls:
Button Left: move piece left
Button Right: move piece right
Button Up: rotate piece
Button Down: soft drop

Gameplay:
The game starts on the title screen.
Press the assigned start/reset control if needed to begin.
Move and rotate falling tetrominoes to complete full horizontal lines.
Completed lines are cleared automatically and increase your score.
The game ends when a new piece cannot spawn without colliding.

Display:
VGA output shows the main playfield, next-piece preview, score, and overlays.
The seven-segment display mirrors score-related output depending on the current build configuration.

