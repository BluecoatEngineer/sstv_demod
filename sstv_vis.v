// sstv_vis.v - Vertical Interval Signaling detector
//
// Author: Jack Bradach
//         jack@bradach.net
//         github.com/jbradach
//
// Recognizes a slow-scan television (SSTV) Vertical Interval Signaling (VIS)
// code and extracts it.  This code consists of a 1200Hz sync bit followed by
// 8 bits sent LSB to form the VIS code (7-bits + even parity bit) and another
// 1200Hz stop bit.  Each bit is 30ms in duration.  When a VIS has correctly
// been identified, the VIS code as well as the valid signal will be latched
// and driven out of the block. The VIS will be held until the cal_ok signal
// from the calibration block deasserts, indicating that it needs to ready
// itself to detect a new frame.
module sstv_vis #(
    parameter simulate = 0
)   (
    input   clk,
    input   reset,
    input   [11:0]  freq,
    input   cal_ok,
    output  reg [6:0] vis_code,
    output  reg valid
);

    reg [8:0] data_recv;

    reg [4:0]   vis_state;
    reg [4:0]   next_vis_state;
    reg [3:0]   bit_num;
    reg [31:0]  delay_counter;

    // With an input clock of 100mHz, it takes
    // 3 million ticks to equal 30 ms.
    localparam  CLK_TICKS_30MS  =   simulate ? 32'd3_000 : 32'd3_000_000;

    localparam  FREQ_1100HZ = 12'd1100;
    localparam  FREQ_1200HZ = 12'd1200;
    localparam  FREQ_1300HZ = 12'd1300;

    // The encoded VIS data is 7 bits plus a parity bit.
    localparam  SSTV_VIS_LENGTH      = 4'd8;

    localparam  SSTV_VIS_IDLE    =   'b00001;
    localparam  SSTV_VIS_BEGIN   =   'b00010;
    localparam  SSTV_VIS_RECV    =   'b00100;
    localparam  SSTV_VIS_END     =   'b01000;
    localparam  SSTV_VIS_PARITY  =   'b10000;

    // Advance the state machine on the
    // rising edge of the clock.
    always @(posedge clk)
        if (reset)
            vis_state <= SSTV_VIS_IDLE;
        else
            vis_state <= next_vis_state;

    always @(*) begin
        next_vis_state = SSTV_VIS_IDLE;
        case (vis_state)

            // When we get the signal from the calibration module
            // that calibration has completed, we start listening
            // for a 1200Hz sync tone.
            SSTV_VIS_IDLE:
                if (cal_ok && (freq == FREQ_1200HZ))
                    next_vis_state = SSTV_VIS_BEGIN;
                else
                    next_vis_state = SSTV_VIS_IDLE;

            SSTV_VIS_BEGIN:
                    // Sync pulse needs to be 30ms long
                    if (CLK_TICKS_30MS == delay_counter)
                        next_vis_state = SSTV_VIS_RECV;
                    else if (((CLK_TICKS_30MS / 2) == delay_counter) &&
                            (FREQ_1200HZ != freq))
                        next_vis_state = SSTV_VIS_IDLE;
                    else
                        next_vis_state = SSTV_VIS_BEGIN;

            SSTV_VIS_RECV:
                // Sanity check, if we take our sample and
                // don't have a valid value, something's
                // gone wrong so we go back to SSTV_VIS_IDLE.
                if ((CLK_TICKS_30MS / 2) == delay_counter)
                    if ((FREQ_1100HZ != freq) &&
                        (FREQ_1300HZ != freq))
                        next_vis_state = SSTV_VIS_IDLE;
                    else
                        next_vis_state = SSTV_VIS_RECV;
                // Otherwise continue until we have all
                // the bits (wait til the end of the 30ms
                // interval before going to next state.
                else if ((bit_num == SSTV_VIS_LENGTH) &&
                        (CLK_TICKS_30MS == delay_counter))
                    next_vis_state = SSTV_VIS_END;
                else
                    next_vis_state = SSTV_VIS_RECV;

            SSTV_VIS_END:
                // Sync pulse needs to be 30ms long
                if (CLK_TICKS_30MS == delay_counter)
                    next_vis_state = SSTV_VIS_PARITY;
                else if (((CLK_TICKS_30MS / 2) == delay_counter) &&
                         (FREQ_1200HZ != freq))
                    next_vis_state = SSTV_VIS_IDLE;
                else
                    next_vis_state = SSTV_VIS_END;

            // Stay in the the parity validation
            // state until the calibration block
            // indicates it's starting over.
            SSTV_VIS_PARITY:
                if (0 == cal_ok)
                    next_vis_state = SSTV_VIS_IDLE;
                else
                    next_vis_state = SSTV_VIS_PARITY;

            default:
                next_vis_state = SSTV_VIS_IDLE;
        endcase
    end

    always @(posedge clk)
        if (reset) begin
            data_recv       <= 10'b0;
            vis_code        <= 7'b0;
            valid           <= 1'b0;
            delay_counter   <= 32'b1;
            bit_num         <= 4'd0;
        end
        else
            case (vis_state)

                SSTV_VIS_IDLE: begin
                    data_recv   <= 10'b0;
                    bit_num     <= 4'd0;
                    if (FREQ_1200HZ == freq)
                        delay_counter <= delay_counter + 32'b1;
                    else
                        delay_counter <= 32'b1;
                end

                SSTV_VIS_BEGIN: begin
                    valid    <= 1'b0;
                    if (CLK_TICKS_30MS == delay_counter)
                        delay_counter <= 32'b1;
                    else
                        delay_counter <= delay_counter + 32'b1;
                end

                SSTV_VIS_RECV:
                    if (CLK_TICKS_30MS == delay_counter) begin
                        delay_counter <= 32'b1;
                        data_recv <= data_recv >> 9'b1;
                    end
                    else begin
                        delay_counter <= delay_counter + 32'b1;
                        // Sample the bit in the middle of the 30ms window
                        if ((CLK_TICKS_30MS / 2) == delay_counter) begin
                            bit_num <= bit_num + 4'd1;
                            // The case where we have a bogus logic value is
                            // handled in the other always block.  It basically
                            // kicks us back to SSTV_VIS_IDLE.
                            if (FREQ_1300HZ == freq)
                                data_recv[8] <= 1'b0;
                            else
                                data_recv[8] <= 1'b1;
                        end
                    end

                SSTV_VIS_END:
                    if (CLK_TICKS_30MS == delay_counter)
                        delay_counter <= 32'b1;
                    else
                        delay_counter <= delay_counter + 32'b1;

                SSTV_VIS_PARITY:
                    if (^data_recv[7:0] == data_recv[8]) begin
                        vis_code <= data_recv[7:0];
                        valid    <= 1'b1;
                    end
            endcase

endmodule
