/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-2-2019 */

module jt1943_game(
    input         rst,
    input         clk,
    input         prog_clk,
    input         clk24,
    input         cen8,
    input         cen6,
    input         cen3,
    input         cen1p5,
    input         pxl_cen,
    input         pxl2_cen,

    output [3:0]  red, green, blue,
    output        LHBL, LVBL, HS, VS,

    input  [3:0]  cab_1p, coin,
    input  [6:0]  joystick1, joystick2,
    input  [31:0] dipsw,
    input         dip_pause, dip_flip, service,

    input  [3:0]  gfx_en,
    input  [7:0]  debug_bus,
    output [7:0]  debug_view,

    output [17:0] main_addr,
    output        main_cs,
    input  [7:0]  main_data,
    input         main_ok,

    output [14:0] snd_addr,
    input  [7:0]  snd_data,

    output [13:0] char_addr,
    input  [15:0] char_data,
    input         char_ok,

    output [13:0] map1_addr, map2_addr,
    input  [15:0] map1_data, map2_data,
    input         map1_ok, map2_ok,
    output        map1_cs, map2_cs,

    output [16:0] scr1_addr,
    input  [15:0] scr1_data,
    output [14:0] scr2_addr,
    input  [15:0] scr2_data,

    output [16:0] obj_addr,
    input  [15:0] obj_data,
    input         obj_ok,

    output [9:0]  psg0, psg1,
    output [15:0] fm0, fm1,

    input  [25:0] ioctl_addr,
    input  [25:0] prog_addr,
    input  [7:0]  prog_data,
    input         prom_we
);

localparam [25:0] MCU_PROM_ADDR = 26'h0D8000;

wire [8:0] V;

wire [12:0] cpu_AB;
wire flip, char_cs;
wire [7:0] cpu_dout, chram_dout;
wire rd;
wire [7:0] dipsw_a, dipsw_b;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign debug_view = {6'd0, dip_flip, flip};

wire wr_n, rd_n;
// sound
wire sres_b;
wire [7:0] snd_latch, mcu_mdin, mcu_mdout, mcu_sdin;
wire [7:0] scrposv, main_ram;

wire char_wait, mcu_mrd, mcu_mwr, mcu_srd, mcu_cen;

wire [15:0] scr1posh, scr2posh;

wire CHON, OBJON, SC2ON, SC1ON;
wire cpu_cen;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;

wire prom_7l_we  = prom_we && ioctl_addr[11:8]== 0;
wire prom_12l_we = prom_we && ioctl_addr[11:8]== 1;
wire prom_12a_we = prom_we && ioctl_addr[11:8]== 2;
wire prom_12m_we = prom_we && ioctl_addr[11:8]== 3;
wire prom_13a_we = prom_we && ioctl_addr[11:8]== 4;
wire prom_14a_we = prom_we && ioctl_addr[11:8]== 5;
wire prom_12c_we = prom_we && ioctl_addr[11:8]== 6;
wire prom_7f_we  = prom_we && ioctl_addr[11:8]== 7;
// wire prom_4b_we  = prom_we && ioctl_addr[11:8]== 8; // Video timing. Unused.
wire prom_7c_we  = prom_we && ioctl_addr[11:8]== 9;
wire prom_8c_we  = prom_we && ioctl_addr[11:8]==10;
wire prom_6l_we  = prom_we && ioctl_addr[11:8]==11;
wire mcu_prom_we = prom_we && ioctl_addr[25:12]==MCU_PROM_ADDR[25:12];

assign cpu_cen = cen6;

jtframe_crossclk_cen u_mcu_cen(
    .clk_in     ( clk       ),
    .cen_in     ( cen6      ),
    .clk_out    ( clk24     ),
    .cen_out    ( mcu_cen   )
);

jt1943_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LVBL       ( LVBL          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // MCU
    .mcu_din    ( mcu_mdin      ),
    .mcu_dout   ( mcu_mdout     ),
    .mcu_rd     ( mcu_mrd       ),
    .mcu_wr     ( mcu_mwr       ),
    // CHAR
    .char_dout  ( chram_dout    ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_wait  ( char_wait     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scrposv    ( scrposv       ),
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .OBJON      ( OBJON         ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p      ( cab_1p[1:0]  ),
    .coin        ( coin[1:0]    ),
    .service     ( service      ),
    .joystick1   ( joystick1     ),
    .joystick2   ( joystick2     ),
    // DIP switches
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dipsw_c    (               ),
    .dip_pause  ( dip_pause     ),
    .coin_cnt   (               ),
    // unused ports (used in SideArms only)
    .blue_cs    (               ),
    .redgreen_cs(               ),
    .eres_n     (               ),
    .wrerr_n    (               )
);

jtgng_sound u_sound (
    .rst            ( rst        ),
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    // Interface with main CPU
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .snd2_latch     (            ),
    .snd_int        ( V[5]       ),
    // ROM
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .rom_cs         (            ),
    .rom_ok         ( 1'b1       ),
    // sound output
    .fm0            ( fm0        ),
    .fm1            ( fm1        ),
    .psg0           ( psg0       ),
    .psg1           ( psg1       ),
    .debug_bus      ( debug_bus  ),
    .debug_view     (            ),
    // unused
    .mcu_sdin       ( mcu_sdin   ),
    .mcu_srd        ( mcu_srd    )
);

`ifndef JT1943_USE_REAL_MCU
    assign mcu_sdin = 8'd0;
    jt1943_security u_security(
        .clk    ( clk       ),
        .cen    ( cpu_cen   ),
        .wr_n   ( 1'b0      ),
        .cs     ( mcu_mwr   ),
        .din    ( cpu_dout  ),
        .dout   ( mcu_mdin  )
    );
`else
    jttrojan_mcu u_mcu(
        .rst        ( rst             ),
        .clk_rom    ( clk             ),
        .clk        ( clk24           ),
        .cen        ( mcu_cen         ),
        .LVBL       ( LVBL            ),
        .vdump      ( V               ),
        .mrd        ( mcu_mrd         ),
        .mwr        ( mcu_mwr         ),
        .to_main    ( mcu_mdin        ),
        .from_main  ( mcu_mdout       ),
        .srd        ( mcu_srd         ),
        .swr        ( 1'b0            ),
        .to_snd     ( mcu_sdin        ),
        .from_snd   ( 8'd0            ),
        .prog_addr  ( prog_addr[11:0] ),
        .prom_din   ( prog_data       ),
        .prom_we    ( mcu_prom_we     )
    );
`endif

jt1943_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .prog_clk   ( prog_clk      ),
    .pxl_cen    ( pxl_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .cen8       ( cen8          ),
    .cen3       ( cen3          ),
    .cen6       ( cen6          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .cpu_dout   ( cpu_dout      ),
    .flip       ( flip          ),
    .dip_flip   ( dip_flip      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_wait  ( char_wait     ),
    .char_ok    ( char_ok       ),
    .CHON       ( CHON          ),
    // SCROLL - ROM
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    .scrposv    ( scrposv       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // Scroll maps
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_data     ),
    .map1_ok    ( map1_ok       ),
    .map1_cs    ( map1_cs       ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_data     ),
    .map2_ok    ( map2_ok       ),
    .map2_cs    ( map2_cs       ),
    // OBJ
    .OBJON      ( OBJON         ),
    .obj_AB     ( obj_AB        ),
    .obj_DB     ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    // Char
    .prom_char_we  ( prom_7f_we    ),
    // color mixer proms
    .prom_red_we   ( prom_12a_we   ),
    .prom_green_we ( prom_13a_we   ),
    .prom_blue_we  ( prom_14a_we   ),
    .prom_prior_we ( prom_12c_we   ),
    // scroll 1/2 proms
    .prom_scr1hi_we( prom_6l_we    ),
    .prom_scr1lo_we( prom_7l_we    ),
    .prom_scr2hi_we( prom_12l_we   ),
    .prom_scr2lo_we( prom_12m_we   ),
    // obj proms
    .prom_objhi_we ( prom_7c_we    ),
    .prom_objlo_we ( prom_8c_we    ),
    // Debug
    .gfx_en        ( gfx_en        ),
    .debug_bus     ( debug_bus     ),
    // Pixel Output
    .red           ( red           ),
    .green         ( green         ),
    .blue          ( blue          )
);

endmodule
