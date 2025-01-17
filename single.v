module single(
    input clk, rst,
    input video_on,
    input up1,
    input down1,
    input[11:0] pixel_x, pixel_y,
    input [15:0] rng,
    input [3:0] score,
    input [1:0] ball,
    output reg[11:0] rgb,
    output [1:0] graph_on,
    output reg miss,
    output reg hit,
    output over
);
    localparam bar_XL = 550, // left bar player
               bar_XR = 555, // right bar player
               bar_LENGTH = 80, // bar length
               bar_V = 10, // bar velocity
               ball_DIAM = 7, // ball diameter minus one
               ball_V = 2; // ball velocity

    wire bar_on, ball_box;
    reg ball_on;
    reg[2:0] rom_addr; // ROM for circular pattern of ball
    reg[7:0] rom_data; // 8-bit value regarding pixels
    reg[9:0] bar_top_q = 200, bar_top_d; // stores upper Y value of bar_1

    reg[9:0] ball_x_q = 320, ball_x_d; // stores left X value of the bouncing ball
    reg[9:0] ball_y_q = 200, ball_y_d; // stores upper Y value of the bouncing ball
    reg ball_xdelta_q = 0, ball_xdelta_d;
    reg ball_ydelta_q = 0, ball_ydelta_d;

    wire [7:0] first_8_bits;
    wire [7:0] last_8_bits;
    assign first_8_bits = rng[7:0];
    assign last_8_bits = rng[15:8];

    // Display conditions
    assign bar_on = (bar_XL <= pixel_x && pixel_x <= bar_XR && 
                     bar_top_q <= pixel_y && pixel_y <= (bar_top_q + bar_LENGTH));
    assign ball_box = (ball_x_q <= pixel_x && pixel_x <= (ball_x_q + ball_DIAM) && 
                       ball_y_q <= pixel_y && pixel_y <= (ball_y_q + ball_DIAM));

    // Circular ball_on logic
    always @* begin
        rom_addr = 0;
        ball_on = 0;
        if (ball_box) begin
            rom_addr = pixel_y - ball_y_q;
            if (pixel_x >= ball_x_q && (pixel_x - ball_x_q) < 8) begin
                ball_on = rom_data[pixel_x - ball_x_q];
            end
        end
    end

    // Ball ROM pattern
    always @* begin
        case (rom_addr)
            3'd0: rom_data = 8'b0001_1000;
            3'd1: rom_data = 8'b0011_1100;
            3'd2: rom_data = 8'b0111_1110;
            3'd3: rom_data = 8'b1111_1111;
            3'd4: rom_data = 8'b1111_1111;
            3'd5: rom_data = 8'b0111_1110;
            3'd6: rom_data = 8'b0011_1100;
            3'd7: rom_data = 8'b0001_1000;
        endcase
    end

    // Logic for movable bar and self-bouncing ball
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            bar_top_q <= 200;
            ball_x_q <= 320;
            ball_y_q <= 200;
            ball_xdelta_q <= 0;
            ball_ydelta_q <= 0;
        end else begin
            bar_top_q <= bar_top_d;
            ball_x_q <= ball_x_d;
            ball_y_q <= ball_y_d;
            ball_xdelta_q <= ball_xdelta_d;
            ball_ydelta_q <= ball_ydelta_d;
        end
    end

    always @* begin
        // Default values to avoid latches
        bar_top_d = bar_top_q;
        ball_x_d = ball_x_q;
        ball_y_d = ball_y_q;
        ball_xdelta_d = ball_xdelta_q;
        ball_ydelta_d = ball_ydelta_q;
        hit = 0;
        miss = 0;

        if (pixel_y == 500 && pixel_x == 0) begin
            // Bar movement logic
            if (up1 && bar_top_q > bar_V) begin
                bar_top_d = bar_top_q - bar_V;
            end else if (down1 && bar_top_q < (480 - bar_LENGTH)) begin
                bar_top_d = bar_top_q + bar_V;
            end

            // Bouncing ball logic
            if ((bar_XL <= (ball_x_q + ball_DIAM) && (ball_x_q + ball_DIAM) <= bar_XR && 
                 bar_top_q <= (ball_y_q + ball_DIAM) && ball_y_q <= (bar_top_q + bar_LENGTH))) begin
                ball_xdelta_d = 0; // Bounce from bar
                hit = 1;
            end

            if (ball_y_q <= 5) ball_ydelta_d = 1; // Bounce from top
            if (480 <= (ball_y_q + ball_DIAM)) ball_ydelta_d = 0; // Bounce from bottom
            if (ball_x_q <= 5) ball_xdelta_d = 0; // Bounce from left

            // If player misses
            if (ball_x_q > 640 && ball_xdelta_q) begin
                miss = 1;
                ball_xdelta_d = ^first_8_bits;
                ball_ydelta_d = ^last_8_bits;
            end else begin
                miss = 0;
            end

            ball_x_d = ball_xdelta_d ? (ball_x_q + ball_V) : (ball_x_q - ball_V);
            ball_y_d = ball_ydelta_d ? (ball_y_q + ball_V) : (ball_y_q - ball_V);
        end
    end

    assign graph_on = {bar_on, ball_on};
    assign over = (score >= 12 || ball == 0);

    always @* begin
        rgb = 0;
        if (video_on) begin
            if (bar_on) rgb = 12'b0000_1001_0000;
            else if (ball_on) rgb = 12'b0000_0000_1111;
            else rgb = 12'b0000_0000_0000; // Background color
        end
    end
endmodule
