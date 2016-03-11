// sstv_vid.v - VGA translator for SSTV receiver
//
// Author: Jack Bradach
//         jack@bradach.net
//         github.com/jbradach
//
// Draws the input ROM image as well as the received image from the SSTV output
// RAM.  This will draw a 640x480x1 (scaled up from two 160x120x1 images)
// pattern from the two data sources.  The alt_color signal determines the
// "high" color signal used when video is drawn.  Changing it will cause an
// instant (well, close enough) color change of all "on" pixels.
module vga (
    input clk,
    input reset,

    input       [1:0]   alt_color,
    input               video_on,
    input       [9:0]   pixel_row,
    input       [9:0]   pixel_col,

    // Input from bitmap ROM
    output      [14:0]  bitmap_rom_addr,
    input               bitmap_rom_data,

    // Input from SSTV RAM
    output      [14:0]  sstv_ram_addr,
    input       [1:0]   sstv_ram_data,

    // Colors
    output reg  [2:0]   red,
    output reg  [2:0]   green,
    output reg  [1:0]   blue
);

    reg [7:0] bitmap_col;
    reg [6:0] bitmap_row;
    reg [7:0] sstv_col;
    reg [6:0] sstv_row;

    reg [7:0] color;
    reg [7:0] on_color;

    // Convert the row/col into a sensible address.
    assign bitmap_rom_addr  = (bitmap_row * 160) + bitmap_col;
    assign sstv_ram_addr    = (sstv_row * 160) + sstv_col;

    // Update the color registers on a clock edge.
    always @(posedge clk) begin
        if (video_on) begin
            red   <= color[2:0];
            green <= color[5:3];
            blue  <= color[7:6];
        end
        else begin
            // All colors to black during the blanking interval.
            red   <= 3'b000;
            green <= 3'b000;
            blue  <= 2'b00;
        end
    end

    // Constants for the few supported colors
    localparam COLOR_BLACK          = 8'b00_000_000;
    localparam COLOR_WHITE          = 8'b11_111_111;
    localparam COLOR_GREEN          = 8'b00_111_000;
    localparam COLOR_RED            = 8'b00_000_111;
    localparam COLOR_BLUE           = 8'b11_000_000;
    localparam COLOR_DARKGRAY       = 8'b01_010_010;
    localparam COLOR_LIGHTGRAY      = 8'b10_100_100;

    // Combo logic for mapping our "on" color.
    always @(*)
        if (reset)
            on_color = COLOR_WHITE;
        else
            case (alt_color)
                2'b00:
                    on_color = COLOR_WHITE;
                2'b01:
                    on_color = COLOR_GREEN;
                2'b10:
                    on_color = COLOR_RED;
                2'b11:
                    on_color = COLOR_BLUE;
            endcase

    // More combo logic for mapping ROM/RAM pixels
    // into VGA space.  Deeper logic than I'd like,
    // but it works and I'm tired.
    always @(*)
        if (reset)
            color = COLOR_BLACK;
        else begin
            color = COLOR_BLACK;

            // Bitmap ROM data
            if ((pixel_col >= 10'd0) && (pixel_col < 10'd320)) begin
                if (pixel_row < 10'd240) begin
                    bitmap_col = pixel_col >> 1;
                    bitmap_row = pixel_row >> 1;
                    if (bitmap_rom_data)
                        color = on_color;
                    else
                        color = COLOR_BLACK;
                end
            end

            // RAM (SSTV output) data
            else if ((pixel_col >= 10'd320) && (pixel_col < 10'd640)) begin
                if (pixel_row < 10'd240) begin
                    sstv_col = (pixel_col - 10'd320) >> 1;
                    sstv_row = pixel_row >> 1;
                    if (sstv_ram_data)
                        color = on_color;
                    else
                        color = COLOR_BLACK;
                end
            end
        end

endmodule
