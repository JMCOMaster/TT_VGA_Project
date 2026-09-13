`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    
  output wire [7:0] uo_out,   
  input  wire [7:0] uio_in,   
  output wire [7:0] uio_out,  
  output wire [7:0] uio_oe,   
  input  wire       ena,      
  input  wire       clk,      
  input  wire       rst_n     
);

  wire hsync, vsync, video_active;
  wire [1:0] R, G, B;
  wire [9:0] pix_x, pix_y;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
    .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
  );

  // ==========================================
  // ANIMATION COUNTERS
  // ==========================================
  reg prev_vsync;
  reg [9:0] frame_count; 
  reg [6:0] tide_val;  
  reg tide_dir;        

  always @(posedge clk) begin
    if (~rst_n) begin
      prev_vsync <= 0;
      frame_count <= 0;
      tide_val <= 0;
      tide_dir <= 0;
    end else begin
      prev_vsync <= vsync;
      if (prev_vsync && !vsync) begin
        frame_count <= frame_count + 1;
        
        if (frame_count[1:0] == 2'b11) begin
          if (tide_dir == 0) begin
            if (tide_val == 99) begin
              tide_val <= 100;
              tide_dir <= 1; 
            end else tide_val <= tide_val + 1;
          end else begin
            if (tide_val == 1) begin
              tide_val <= 0;
              tide_dir <= 0; 
            end else tide_val <= tide_val - 1;
          end
        end
      end
    end
  end

  // ==========================================
  // SPATIAL AND MATHEMATICAL LOGIC (OPTIMIZED)
  // ==========================================
  
  // 1. THE SUN (Manhattan distance / Diamond shape)
  wire signed [11:0] sun_dx = $signed({2'b00, pix_x}) - 100;
  wire signed [11:0] sun_dy = $signed({2'b00, pix_y}) - 80;
  wire [11:0] abs_sun_dx = sun_dx[11] ? -sun_dx : sun_dx;
  wire [11:0] abs_sun_dy = sun_dy[11] ? -sun_dy : sun_dy;
  
  wire is_sun_core = (abs_sun_dx + abs_sun_dy < 45); 
  wire is_sun_ray = (abs_sun_dx + abs_sun_dy < 65) && ((sun_dx[2] ^ sun_dy[2]) == frame_count[4]);

  // 2. THE SEA AND WAVES
  wire [9:0] shore_noise = {8'b0, pix_x[6:5]};
  wire [9:0] shore_y = 260 + tide_val + shore_noise;
  
  wire is_sea = (pix_y >= 200) && (pix_y < shore_y);
  wire [9:0] wave_x = pix_x + {1'b0, frame_count[8:0]}; 
  wire is_deep_foam = is_sea && (pix_y[4:3] == 2'b10) && (wave_x[6:4] == 3'b000);
  wire is_shore_foam = is_sea && (pix_y >= shore_y - 4);
  wire is_wave_foam = is_deep_foam || is_shore_foam;

  // 3. THE SAND (Dry and Wet)
  wire is_sand = (pix_y >= shore_y);
  wire [9:0] max_shore_y = 360 + shore_noise;
  wire is_wet_sand = is_sand && (pix_y <= max_shore_y);

  // 4. THE BEACH BALL AND ITS SHADOW (Octagon shape)
  wire signed [11:0] ball_dx = $signed({2'b00, pix_x}) - 450;
  wire signed [11:0] ball_dy = $signed({2'b00, pix_y}) - 370;
  wire [11:0] abs_ball_dx = ball_dx[11] ? -ball_dx : ball_dx;
  wire [11:0] abs_ball_dy = ball_dy[11] ? -ball_dy : ball_dy;
  
  // Octagon: combines diamond limit with square limits to emulate a circle cheaply
  wire is_ball = (abs_ball_dx + abs_ball_dy < 65) && (abs_ball_dx < 45) && (abs_ball_dy < 45); 
  wire is_ball_stripe = is_ball && (ball_dx > -15) && (ball_dx < 15);

  wire signed [11:0] shadow_dx = $signed({2'b00, pix_x}) - 460;
  wire signed [11:0] shadow_dy = $signed({2'b00, pix_y}) - 417;
  wire [11:0] abs_shadow_dx = shadow_dx[11] ? -shadow_dx : shadow_dx;
  wire [11:0] abs_shadow_dy = shadow_dy[11] ? -shadow_dy : shadow_dy;
  
  // Flat diamond for shadow
  wire is_ball_shadow = is_sand && (abs_shadow_dx + (abs_shadow_dy << 2) < 55);

  // 5. THE PALM TREE AND PROJECTED SHADOW
  wire [9:0] trunk_offset = (pix_y >= 140) ? ((pix_y - 140) >> 3) : 0;
  wire is_trunk = (pix_y >= 140) && (pix_y < 420) && (pix_x > 530 + trunk_offset) && (pix_x < 557 + trunk_offset);
  
  // Palm tree shadow
  wire [9:0] ps_offset = (pix_y >= 410) ? ((pix_y - 410) + ((pix_y - 410) >> 1)) : 0;
  wire is_palm_shadow = is_sand && (pix_y >= 410) && (pix_y < 480) && (pix_x > 553 + ps_offset) && (pix_x < 590 + ps_offset);
  
  wire is_any_shadow = is_ball_shadow || is_palm_shadow;

  // Palm Leaves (Manhattan distance)
  wire signed [11:0] leaf1_dx = $signed({2'b00, pix_x}) - 535;
  wire signed [11:0] leaf1_dy = $signed({2'b00, pix_y}) - 130;
  wire [11:0] a_l1_dx = leaf1_dx[11] ? -leaf1_dx : leaf1_dx;
  wire [11:0] a_l1_dy = leaf1_dy[11] ? -leaf1_dy : leaf1_dy;

  wire signed [11:0] leaf2_dx = $signed({2'b00, pix_x}) - 502;
  wire signed [11:0] leaf2_dy = $signed({2'b00, pix_y}) - 160;
  wire [11:0] a_l2_dx = leaf2_dx[11] ? -leaf2_dx : leaf2_dx;
  wire [11:0] a_l2_dy = leaf2_dy[11] ? -leaf2_dy : leaf2_dy;

  wire signed [11:0] leaf3_dx = $signed({2'b00, pix_x}) - 585;
  wire signed [11:0] leaf3_dy = $signed({2'b00, pix_y}) - 160;
  wire [11:0] a_l3_dx = leaf3_dx[11] ? -leaf3_dx : leaf3_dx;
  wire [11:0] a_l3_dy = leaf3_dy[11] ? -leaf3_dy : leaf3_dy;
  
  wire is_leaf1 = (a_l1_dx + a_l1_dy < 70) && (leaf1_dy < 10);
  wire is_leaf2 = (a_l2_dx + a_l2_dy < 60) && (leaf2_dx < 10) && (leaf2_dy < 10);
  wire is_leaf3 = (a_l3_dx + a_l3_dy < 60) && (leaf3_dx > -10) && (leaf3_dy < 10);
  wire is_leaves = is_leaf1 || is_leaf2 || is_leaf3;

  // Coconuts (Manhattan distance)
  wire signed [11:0] coco1_dx = $signed({2'b00, pix_x}) - 525;
  wire signed [11:0] coco1_dy = $signed({2'b00, pix_y}) - 145;
  wire [11:0] a_c1_dx = coco1_dx[11] ? -coco1_dx : coco1_dx;
  wire [11:0] a_c1_dy = coco1_dy[11] ? -coco1_dy : coco1_dy;

  wire signed [11:0] coco2_dx = $signed({2'b00, pix_x}) - 565;
  wire signed [11:0] coco2_dy = $signed({2'b00, pix_y}) - 150;
  wire [11:0] a_c2_dx = coco2_dx[11] ? -coco2_dx : coco2_dx;
  wire [11:0] a_c2_dy = coco2_dy[11] ? -coco2_dy : coco2_dy;

  wire is_coconuts = (a_c1_dx + a_c1_dy < 14) || (a_c2_dx + a_c2_dy < 14);

  // 6. THE AIRPLANE (Horizon animation)
  wire signed [11:0] plane_dx = $signed({2'b00, pix_x}) - $signed({2'b00, frame_count});
  wire signed [11:0] plane_dy = $signed({2'b00, pix_y}) - 60;
  
  wire is_plane_body = (plane_dx > -20) && (plane_dx < 20) && (plane_dy > -3) && (plane_dy < 3);
  wire is_plane_wing = (plane_dx > -5)  && (plane_dx < 5)  && (plane_dy > -10) && (plane_dy < 10);
  wire is_plane_tail = (plane_dx > -20) && (plane_dx < -13) && (plane_dy > -10) && (plane_dy < 0);
  wire is_plane = (is_plane_body || is_plane_wing || is_plane_tail) && (pix_y < 200);

  // 7. THE TOWEL (Left side of the sand)
  wire is_towel_base = (pix_x > 60) && (pix_x < 330) && (pix_y > 380) && (pix_y < 460);
  wire is_towel = is_sand && is_towel_base;
  wire is_towel_stripe = is_towel && (pix_x[5] == 1'b0); // Vertical stripes

  // ==========================================
  // RGB COLOR MULTIPLEXER
  // ==========================================
  reg [1:0] r_reg, g_reg, b_reg;

  always @(*) begin
    if (!video_active) begin
      r_reg = 2'b00; g_reg = 2'b00; b_reg = 2'b00;
    end else if (is_towel_stripe) begin
      r_reg = 2'b11; g_reg = 2'b11; b_reg = 2'b00; 
    end else if (is_towel) begin
      r_reg = 2'b11; g_reg = 2'b11; b_reg = 2'b11; 
    end else if (is_ball_stripe) begin
      r_reg = 2'b11; g_reg = 2'b11; b_reg = 2'b11; 
    end else if (is_ball) begin
      r_reg = 2'b11; g_reg = 2'b00; b_reg = 2'b00; 
    end else if (is_coconuts || is_trunk) begin
      r_reg = 2'b01; g_reg = 2'b00; b_reg = 2'b00; 
    end else if (is_leaves) begin
      r_reg = 2'b00; g_reg = 2'b10; b_reg = 2'b00; 
    end else if (is_plane) begin
      r_reg = 2'b11; g_reg = 2'b11; b_reg = 2'b11; 
    end else if (is_sun_core) begin
      r_reg = 2'b11; g_reg = 2'b11; b_reg = 2'b00; 
    end else if (is_sun_ray) begin
      r_reg = 2'b11; g_reg = 2'b10; b_reg = 2'b00; 
    end else if (is_any_shadow) begin
      r_reg = 2'b01; g_reg = 2'b01; b_reg = 2'b00; 
    end else if (is_wet_sand) begin
      r_reg = 2'b10; g_reg = 2'b01; b_reg = 2'b00; 
    end else if (is_sand) begin
      r_reg = 2'b11; g_reg = 2'b10; b_reg = 2'b00; 
    end else if (is_wave_foam) begin
      r_reg = 2'b01; g_reg = 2'b11; b_reg = 2'b11; 
    end else if (is_sea) begin
      r_reg = 2'b00; g_reg = 2'b01; b_reg = 2'b11; 
    end else begin
      r_reg = 2'b01; g_reg = 2'b10; b_reg = 2'b11; 
    end
  end

  assign R = r_reg;
  assign G = g_reg;
  assign B = b_reg;

endmodule
