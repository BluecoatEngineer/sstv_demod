// sstv_stim.v - SSTV Stimulus module
//
// Author - Jack Bradach
//
// This module provides a stimulus to the SSTV receiver, substituting
// for the ADC front-end.  It occured to me after writing this that
// this is pretty much a transmitter module.  It takes a bitmap
// image and converts it into the frequencies (with correct timing)
// needed by the receiver side.  If we were to hook it up to a DAC,
// we could theoretically transmit the image to a suitable SSTV
// receiver.  It speaks Robot-8 and nothing else.
module sstv_stim #(
    parameter simulate = 0
)   (
    input clk,
    input reset,

    input send,
    output  reg done,
    output  reg [11:0] freq,

    output  reg [14:0]  bitmap_addr,
    input               bitmap_data
);

    // FSM states
    reg [9:0]   stim_state;
    reg [9:0]   next_stim_state;

    // Counter for keeping time
    reg [31:0]  delay_counter;
    
    // VIS code registers
    reg [6:0]   vis_code;
    reg [4:0]   bit_num;

    // Pixel row/colum
    reg [6:0]   pixel_row;
    reg [7:0]   pixel_col;

    // Constants for time
    localparam  CLK_TICKS_10MS  = simulate ? 32'd1_000  : 32'd1_000_000;
    localparam  CLK_TICKS_30MS  = simulate ? 32'd3_000  : 32'd3_000_000;
    localparam  CLK_TICKS_300MS = simulate ? 32'd30_000 : 32'd30_000_000;
    localparam  CLK_TICKS_5MS   = simulate ? 32'd500    : 32'd500_000;
    localparam  CLK_TICKS_350US = simulate ? 32'd35     : 32'd35_000;

    // Frequencies used by this module.
    localparam  FREQ_HSYNC      = 12'd1200;
    localparam  FREQ_BREAK      = 12'd1200;
    localparam  FREQ_BITZERO    = 12'd1300;
    localparam  FREQ_BITONE     = 12'd1100;
    localparam  FREQ_LEADER     = 12'd1900;
    localparam  FREQ_BLACK      = 12'd1500;
    localparam  FREQ_WHITE      = 12'd2300;

    // The FSM has ten states, one-hot encoding.
    localparam  STIM_IDLE               = 10'b00_0000_0001;
    localparam  STIM_CAL_LEADER_A       = 10'b00_0000_0010;
    localparam  STIM_CAL_BREAK          = 10'b00_0000_0100;
    localparam  STIM_CAL_LEADER_B       = 10'b00_0000_1000;
    localparam  STIM_VIS_START          = 10'b00_0001_0000;
    localparam  STIM_VIS_SEND           = 10'b00_0010_0000;
    localparam  STIM_VIS_PARITY         = 10'b00_0100_0000;
    localparam  STIM_VIS_END            = 10'b00_1000_0000;
    localparam  STIM_FRAME_HSYNC        = 10'b01_0000_0000;
    localparam  STIM_FRAME_LINE         = 10'b10_0000_0000;
   
    // Advance the state machine
    always @(posedge clk)
        if (reset)
            stim_state <= STIM_IDLE;
        else
            stim_state <= next_stim_state;

    always @(*)
        if(reset)
            next_stim_state = STIM_IDLE;
        else
            case (stim_state)
                // Wait for send
                STIM_IDLE: begin
                    if (send)
                        next_stim_state = STIM_CAL_LEADER_A;
                    else
                        next_stim_state = STIM_IDLE;
                end 
                
                // Send first leader tone
                STIM_CAL_LEADER_A: begin
                    if (delay_counter == CLK_TICKS_300MS)
                        next_stim_state = STIM_CAL_BREAK;
                    else
                        next_stim_state = STIM_CAL_LEADER_A;
                end 

                // 10ms break tone
                STIM_CAL_BREAK: begin
                    if (delay_counter == CLK_TICKS_10MS)
                        next_stim_state = STIM_CAL_LEADER_B;
                    else
                        next_stim_state = STIM_CAL_BREAK;
                end
                
                // Send second leader tone
                STIM_CAL_LEADER_B: begin
                    if (delay_counter == CLK_TICKS_300MS)
                        next_stim_state = STIM_VIS_START;
                    else
                        next_stim_state = STIM_CAL_LEADER_B;
                end

                // Start of VIS code
                STIM_VIS_START:
                    if (delay_counter == CLK_TICKS_30MS)
                        next_stim_state = STIM_VIS_SEND;
                    else
                        next_stim_state = STIM_VIS_START;

                // Send 7 bits for VIS
                STIM_VIS_SEND:
                    if ((bit_num == 3'd6) &&
                        (delay_counter == CLK_TICKS_30MS))
                        next_stim_state = STIM_VIS_PARITY;
                    else
                        next_stim_state = STIM_VIS_SEND;

                // Send appropriate parity bit
                STIM_VIS_PARITY:
                    if (delay_counter == CLK_TICKS_30MS)
                        next_stim_state = STIM_VIS_END;
                    else
                        next_stim_state = STIM_VIS_PARITY;
                
                // End of VIS code
                STIM_VIS_END:
                    if (delay_counter == CLK_TICKS_30MS)
                        next_stim_state = STIM_FRAME_HSYNC;
                    else
                        next_stim_state = STIM_VIS_END;

                // Horizontal sync
                STIM_FRAME_HSYNC: begin
                    if (delay_counter == CLK_TICKS_5MS)
                        next_stim_state = STIM_FRAME_LINE;
                    else
                        next_stim_state = STIM_FRAME_HSYNC;
                end
                
                // Send a line of data
                STIM_FRAME_LINE: begin
                    if ((pixel_col == 8'd159) &&
                        (delay_counter == CLK_TICKS_350US))
                        next_stim_state = STIM_FRAME_HSYNC;
                    else
                        next_stim_state = STIM_FRAME_LINE;
                end

                // Wait, what?  If we got here, back to idle.
                default:
                        next_stim_state = STIM_IDLE;

            endcase

    always @(posedge clk)
        if(reset) begin
            bitmap_addr     <= 15'b0;
            delay_counter   <= 1;
            freq            <= 0;
            done            <= 0;
            pixel_row       <=  7'd0; 
            pixel_col       <=  8'd0;
        end
        else
            case (stim_state)
                STIM_IDLE: begin
                    freq            <=  0;
                    done            <= 0;
                    delay_counter   <= 32'd1;
                    pixel_row       <=  7'd0; 
                    pixel_col       <=  8'd0;
                end 
            
                STIM_CAL_LEADER_A: begin
                    freq <= FREQ_LEADER; 
                    if (delay_counter == CLK_TICKS_300MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end 
                
                STIM_CAL_BREAK: begin
                    freq <= FREQ_BREAK; 
                    if (delay_counter == CLK_TICKS_10MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end
                
                STIM_CAL_LEADER_B: begin
                    freq <= FREQ_LEADER; 
                    if (delay_counter == CLK_TICKS_300MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end 

                STIM_VIS_START: begin
                    vis_code    <= 7'b0001000; // Robot mode 8
                    bit_num     <= 3'b000;
                    freq        <= FREQ_BREAK;
                    if (delay_counter == CLK_TICKS_30MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end 
                
                STIM_VIS_SEND: begin
                    // Drive the correct frequency for
                    // the value of the current bit.
                    if (vis_code[bit_num] == 0)
                        freq    <= FREQ_BITZERO;
                    else
                        freq    <= FREQ_BITONE;    
                    
                    if (delay_counter == CLK_TICKS_30MS) begin
                        delay_counter   <= 32'd1;
                        bit_num <= bit_num + 5'd1;
                    end
                    else
                        delay_counter   <= delay_counter + 32'd1;

                end 
                
                // Send the parity bit.
                STIM_VIS_PARITY: begin
                    if (^vis_code)
                        freq    <= FREQ_BITONE;
                    else
                        freq    <= FREQ_BITZERO;

                    if (delay_counter == CLK_TICKS_30MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end    
               
                // Final break bit 
                STIM_VIS_END: begin
                    freq        <= FREQ_BREAK;
                    if (delay_counter == CLK_TICKS_30MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end 
                    
                STIM_FRAME_HSYNC: begin
                    freq <= FREQ_HSYNC;
                    bitmap_addr <= 15'b0;
                    if (delay_counter == CLK_TICKS_5MS)
                        delay_counter   <= 32'd1;
                    else
                        delay_counter   <= delay_counter + 32'd1;
                end
                
                STIM_FRAME_LINE: begin
                    // Map the bitmap data to the black/white frequency
                    if (bitmap_data) 
                        freq <= FREQ_WHITE;
                    else
                        freq <= FREQ_BLACK;
                    
                    // Push the address for the next clock 
                    bitmap_addr <= (pixel_row * 8'd160) + pixel_col;
                    
                    if (delay_counter == CLK_TICKS_350US) begin
                        delay_counter   <= 32'd1;

                        // Wrap the columns (and advance the row)
                        if (pixel_col < 8'd159)
                            pixel_col <= pixel_col + 8'd1;
                        else begin
                            pixel_col <= 8'd0;
                            pixel_row <= pixel_row + 7'd1;
                        end
                    end
                    else
                        delay_counter   <= delay_counter + 32'd1;

                    if (pixel_row == 7'd120)
                        done    <= 1;
                end

                default: begin
                    freq            <=  0;
                    done            <= 0;
                    delay_counter   <= 32'd1;
                    pixel_row       <=  7'd0; 
                    pixel_col       <=  8'd0;
                end
            endcase




    

endmodule
