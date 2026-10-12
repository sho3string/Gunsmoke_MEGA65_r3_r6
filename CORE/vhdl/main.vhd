----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;
use work.globals.all;
library work;
use work.video_modes_pkg.all;
library xpm;
use xpm.vcomponents.all;



entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(3 downto 0);
      video_green_o           : out std_logic_vector(3 downto 0);
      video_blue_o            : out std_logic_vector(3 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0);
      
       -- ROM download bus from QNICE
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(24 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;
      
      video_flip_o            : out std_logic;
      osm_control_i           : in  std_logic_vector(255 downto 0)
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
signal keyboard_n          : std_logic_vector(79 downto 0);


-- -------------------------------------------------------------------------
-- Exed Exes core signals
-- -------------------------------------------------------------------------

-- Reset
signal reset       : std_logic;


-- Gun.Smoke cabinet controls
signal gs_cab_1p         : std_logic_vector(1 downto 0);
signal gs_coin           : std_logic_vector(1 downto 0);
signal joystick1         : std_logic_vector(5 downto 0);
signal joystick2         : std_logic_vector(5 downto 0);

-- DIP Switches
signal gs_dipsw_a        : std_logic_vector(7 downto 0);
signal gs_dipsw_b        : std_logic_vector(7 downto 0);
signal gs_dipsw          : std_logic_vector(31 downto 0);
signal service           : std_logic;

signal dip_pause         : std_logic;
signal dip_flip          : std_logic;

-- JTFRAME clock enables
signal cen12             : std_logic;
signal cen6              : std_logic;
signal cen3              : std_logic;
signal cen1p5            : std_logic;
signal cen8              : std_logic;

signal pxl_cen           : std_logic;
signal pxl2_cen          : std_logic;

-- Audio
signal psg0              : std_logic_vector(9 downto 0);
signal psg1              : std_logic_vector(9 downto 0);
signal fm0               : std_logic_vector(15 downto 0);
signal fm1               : std_logic_vector(15 downto 0);

signal audio_mixed       : signed(15 downto 0);

-- Gun.Smoke ROM interfaces
signal gs_main_cs    : std_logic;
signal gs_main_addr  : std_logic_vector(16 downto 0);
signal gs_main_data  : std_logic_vector(7 downto 0);
signal gs_main_ok    : std_logic;

signal gs_snd_cs     : std_logic;
signal gs_snd_addr   : std_logic_vector(14 downto 0);
signal gs_snd_data   : std_logic_vector(7 downto 0);
signal gs_snd_ok     : std_logic;

signal gs_char_addr  : std_logic_vector(13 downto 1);
signal gs_char_data  : std_logic_vector(15 downto 0);
signal gs_char_ok    : std_logic;

signal gs_map_cs     : std_logic;
signal gs_map_addr   : std_logic_vector(14 downto 0);
signal gs_map_data   : std_logic_vector(15 downto 0);
signal gs_map_ok     : std_logic;

signal gs_scr_addr   : std_logic_vector(17 downto 1);
signal gs_scr_data   : std_logic_vector(15 downto 0);
signal gs_scr_ok     : std_logic;

signal gs_obj_addr   : std_logic_vector(17 downto 1);
signal gs_obj_data   : std_logic_vector(15 downto 0);
signal gs_obj_ok     : std_logic;


-- ROM download / PROM programming
signal prog_addr   : std_logic_vector(25 downto 0);
signal prog_data   : std_logic_vector(7 downto 0);
signal prom_we     : std_logic;
signal shoot2_button1_n : std_logic := '1';
signal shoot2_button2_n : std_logic := '1';
signal pot1_val    : std_logic_vector(7 downto 0);
signal pot2_val    : std_logic_vector(7 downto 0);
signal potxy1_sw   : std_logic;
signal potxy2_sw   : std_logic;
signal pot_pol1_sw : std_logic;
signal pot_pol2_sw : std_logic;

-- ROM download write enables
signal dn_main_we    : std_logic;
signal dn_snd_we     : std_logic;

signal dn_char_lo_we : std_logic;
signal dn_char_hi_we : std_logic;

signal dn_map_lo_we  : std_logic;
signal dn_map_hi_we  : std_logic;

signal dn_scr_lo_we  : std_logic;
signal dn_scr_hi_we  : std_logic;

signal dn_obj_lo_we  : std_logic;
signal dn_obj_hi_we  : std_logic;

-- ROM download offsets
signal dl_main_off : std_logic_vector(25 downto 0);
signal dl_snd_off  : std_logic_vector(25 downto 0);
signal dl_char_off : std_logic_vector(25 downto 0);
signal dl_map_off  : std_logic_vector(25 downto 0);
signal dl_scr_off  : std_logic_vector(25 downto 0);
signal dl_obj_off  : std_logic_vector(25 downto 0);

-- ROM byte lanes
signal char_q0, char_q1 : std_logic_vector(7 downto 0);
signal map_q0,  map_q1  : std_logic_vector(7 downto 0);
signal scr_q0,  scr_q1  : std_logic_vector(7 downto 0);
signal obj_q0,  obj_q1  : std_logic_vector(7 downto 0);

-- Address stability registers
signal main_addr_d : std_logic_vector(gs_main_addr'range);
signal snd_addr_d  : std_logic_vector(gs_snd_addr'range);
signal char_addr_d : std_logic_vector(gs_char_addr'range);
signal map_addr_d  : std_logic_vector(gs_map_addr'range);
signal scr_addr_d  : std_logic_vector(gs_scr_addr'range);
signal obj_addr_d  : std_logic_vector(gs_obj_addr'range);

-- Offer some keyboard controls in addition to Joy 1 Controls
constant m65_1          : integer := 56; --Player 1 Start
constant m65_2          : integer := 59; --Player 2 Start
constant m65_5          : integer := 16; --Insert coin 1
constant m65_6          : integer := 19; --Insert coin 2
constant m65_9          : integer := 32; --Service button

constant m65_up_crsr    : integer := 73; --Player up
constant m65_vert_crsr  : integer := 7;  --Player down
constant m65_left_crsr  : integer := 74; --Player left
constant m65_horz_crsr  : integer := 2;  --Player right
constant m65_z          : integer := 12; --Fire 1
constant m65_x          : integer := 23; --Fire 2
constant m65_capslock   : integer := 72; --Pause


-- -------------------------------------------------------------------------
-- Gun.Smoke ROM download map
-- -------------------------------------------------------------------------
constant C_MAIN_START : natural := 16#000000#;
constant C_SND_START  : natural := 16#018000#;
constant C_CHAR_START : natural := 16#020000#;
constant C_MAP_START  : natural := 16#024000#;
constant C_SCR_START  : natural := 16#02C000#;
constant C_OBJ_START  : natural := 16#06C000#;
constant C_PROM_START : natural := 16#0AC000#;
constant C_ROM_END    : natural := 16#0ACA00#;



begin

    -- Core reset
    reset <= reset_soft_i or reset_hard_i;
    
    video_ce_o <= cen6;
    
    video_flip_o <= dip_flip;

    prog_addr <= std_logic_vector(resize(unsigned(dn_addr_i), prog_addr'length) - to_unsigned(C_PROM_START, prog_addr'length));
    prog_data <= dn_data_i;
    prom_we <= dn_wr_i when unsigned(dn_addr_i) >= C_PROM_START and unsigned(dn_addr_i) < C_ROM_END else '0';
    
    -- -------------------------------------------------------------------------
    -- Gun.Smoke ROM download write enables
    -- -------------------------------------------------------------------------

    dn_main_we <= dn_wr_i when unsigned(dn_addr_i) >= C_MAIN_START and unsigned(dn_addr_i) < C_SND_START else '0';
    dn_snd_we <= dn_wr_i when unsigned(dn_addr_i) >= C_SND_START and unsigned(dn_addr_i) < C_CHAR_START else '0';
    dn_char_lo_we <= dn_wr_i when unsigned(dn_addr_i) >= C_CHAR_START and unsigned(dn_addr_i) < C_MAP_START and dn_addr_i(0) = '0' else '0';
    dn_char_hi_we <= dn_wr_i when unsigned(dn_addr_i) >= C_CHAR_START and unsigned(dn_addr_i) < C_MAP_START and dn_addr_i(0) = '1' else '0';
    dn_map_lo_we <= dn_wr_i when unsigned(dn_addr_i) >= C_MAP_START and unsigned(dn_addr_i) < C_SCR_START and dn_addr_i(0) = '0' else '0';
    dn_map_hi_we <= dn_wr_i when unsigned(dn_addr_i) >= C_MAP_START and unsigned(dn_addr_i) < C_SCR_START and dn_addr_i(0) = '1' else '0';
    dn_scr_lo_we <= dn_wr_i when unsigned(dn_addr_i) >= C_SCR_START and unsigned(dn_addr_i) < C_OBJ_START and dn_addr_i(0) = '0' else '0';
    dn_scr_hi_we <= dn_wr_i when unsigned(dn_addr_i) >= C_SCR_START and unsigned(dn_addr_i) < C_OBJ_START and dn_addr_i(0) = '1' else '0';
    dn_obj_lo_we <= dn_wr_i when unsigned(dn_addr_i) >= C_OBJ_START and unsigned(dn_addr_i) < C_PROM_START and dn_addr_i(0) = '0' else '0';
    dn_obj_hi_we <= dn_wr_i when unsigned(dn_addr_i) >= C_OBJ_START and unsigned(dn_addr_i) < C_PROM_START and dn_addr_i(0) = '1' else '0';

    -- -------------------------------------------------------------------------
    -- Gun.Smoke ROM download offsets
    -- -------------------------------------------------------------------------

    dl_main_off <= std_logic_vector(unsigned('0' & dn_addr_i) - C_MAIN_START);
    dl_snd_off  <= std_logic_vector(unsigned('0' & dn_addr_i) - C_SND_START);
    dl_char_off <= std_logic_vector(unsigned('0' & dn_addr_i) - C_CHAR_START);
    dl_map_off  <= std_logic_vector(unsigned('0' & dn_addr_i) - C_MAP_START);
    dl_scr_off  <= std_logic_vector(unsigned('0' & dn_addr_i) - C_SCR_START);
    dl_obj_off  <= std_logic_vector(unsigned('0' & dn_addr_i) - C_OBJ_START);

    -- Assemble JTFRAME wide ROM buses from byte lanes
    gs_char_data <= char_q1 & char_q0;
    gs_map_data  <= map_q1  & map_q0;
    gs_scr_data  <= scr_q1  & scr_q0;
    gs_obj_data  <= obj_q1  & obj_q0;


    -- Synchronous BRAMs return the requested word one main clock later.
    -- Hold *_ok low for the first cycle after an address change.
    process(clk_main_i)
    begin
        if rising_edge(clk_main_i) then
            gs_main_ok <= '1' when gs_main_addr = main_addr_d else '0';
            gs_snd_ok  <= '1' when gs_snd_addr  = snd_addr_d  else '0';
            gs_char_ok <= '1' when gs_char_addr = char_addr_d else '0';
            gs_map_ok  <= '1' when gs_map_addr  = map_addr_d  else '0';
            gs_scr_ok  <= '1' when gs_scr_addr  = scr_addr_d  else '0';
            gs_obj_ok  <= '1' when gs_obj_addr  = obj_addr_d  else '0';
    
            main_addr_d <= gs_main_addr;
            snd_addr_d  <= gs_snd_addr;
            char_addr_d <= gs_char_addr;
            map_addr_d  <= gs_map_addr;
            scr_addr_d  <= gs_scr_addr;
            obj_addr_d  <= gs_obj_addr;
        end if;
    end process;
    
 
    -- SW1
    gs_dipsw_a <= not (
    osm_control_i(C_MENU_SW1_0) &
    osm_control_i(C_MENU_SW1_1) &
    osm_control_i(C_MENU_SW1_2) &
    osm_control_i(C_MENU_SW1_3) &
    osm_control_i(C_MENU_SW1_4) &
    osm_control_i(C_MENU_SW1_5) &
    osm_control_i(C_MENU_SW1_6) &
    osm_control_i(C_MENU_SW1_7));
    
    gs_dipsw_b <= not (
    osm_control_i(C_MENU_SW2_0) &
    osm_control_i(C_MENU_SW2_1) &
    osm_control_i(C_MENU_SW2_2) &
    osm_control_i(C_MENU_SW2_3) &
    osm_control_i(C_MENU_SW2_4) &
    osm_control_i(C_MENU_SW2_5) &
    osm_control_i(C_MENU_SW2_6) &
    osm_control_i(C_MENU_SW2_7));
    
    gs_dipsw <=  x"0000" & gs_dipsw_b & gs_dipsw_a;
    gs_cab_1p(0) <= keyboard_n(m65_1);
    gs_cab_1p(1) <= keyboard_n(m65_2);
    gs_coin(0) <= keyboard_n(m65_6);
    gs_coin(1) <= keyboard_n(m65_5);
    service <= keyboard_n(m65_9);
    gs_dipsw <= gs_dipsw;
    
    potxy1_sw   <= osm_control_i(C_MENU_SECOND_FIRE_1); -- Joy 1: 0 = POTX, 1 = POTY
    potxy2_sw   <= osm_control_i(C_MENU_SECOND_FIRE_2); -- Joy 2: 0 = POTX, 1 = POTY
    pot_pol1_sw <= osm_control_i(C_MENU_POTPOL_1);      -- Joy 1 polarity
    pot_pol2_sw <= osm_control_i(C_MENU_POTPOL_2);      -- Joy 2 polarity
    
    second_button_proc : process(all)
    begin
    
       -------------------------------------------------------------------------
       -- Select POTX/POTY independently for both joystick ports
       ------------------------------------------------------------------------
        
        -- Player 1
        if potxy1_sw = '0' then
           pot1_val <= pot1_x_i;
        else
           pot1_val <= pot1_y_i;
        end if;
        
        -- Player 2
        if potxy2_sw = '0' then
           pot2_val <= pot2_x_i;
        else
           pot2_val <= pot2_y_i;
        end if;
    
       ------------------------------------------------------------------------
       -- Player 1 second fire
       ------------------------------------------------------------------------
       if pot_pol1_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot1_val) < unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot1_val) >= unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       end if;
       
       -----------------------------------------------------------------------
       -- Player 2 second fire
       ------------------------------------------------------------------------
       if pot_pol2_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot2_val) < unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot2_val) >= unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       end if;
    end process;
    
    -- -------------------------------------------------------------------------
    -- Player 1 controls
    -- Active low
    -- -------------------------------------------------------------------------
    
    -- Player 1 joystick - active low
    joystick1(0) <= joy_1_right_n_i and keyboard_n(m65_horz_crsr);
    joystick1(1) <= joy_1_left_n_i  and keyboard_n(m65_left_crsr);
    joystick1(2) <= joy_1_down_n_i  and keyboard_n(m65_vert_crsr);
    joystick1(3) <= joy_1_up_n_i    and keyboard_n(m65_up_crsr);
    -- Button 1 = Z / joystick fire
    joystick1(4) <= joy_1_fire_n_i and keyboard_n(m65_z);
    -- Button 2 = X / second joystick button
    joystick1(5) <=  keyboard_n(m65_x) and shoot2_button1_n;
    
    -- Player 2 joystick - active low
    joystick2(0) <= joy_2_right_n_i and keyboard_n(m65_horz_crsr);
    joystick2(1) <= joy_2_left_n_i  and keyboard_n(m65_left_crsr);
    joystick2(2) <= joy_2_down_n_i  and keyboard_n(m65_vert_crsr);
    joystick2(3) <= joy_2_up_n_i    and keyboard_n(m65_up_crsr);
    -- Butto2 1 = Z / joystick fire
    joystick2(4) <= joy_2_fire_n_i and keyboard_n(m65_z);
    -- Button 2 = X / second joystick button
    joystick2(5) <=  keyboard_n(m65_x) and shoot2_button2_n;
    
    -- -------------------------------------------------------------------------
    -- JTFRAME clock enables (48 MHz)
    -- -------------------------------------------------------------------------

    i_jtframe_cen48 : entity work.jtframe_cen48
    port map (
        clk    => clk_main_i,
        cen12  => cen12,
        cen8   => cen8,
        cen6   => cen6,
        cen3   => cen3,
        cen1p5 => cen1p5
    );


    -- -------------------------------------------------------------------------
    -- Gunsmoke
    -- -------------------------------------------------------------------------


    i_jtgunsmk_game : entity work.jtgunsmk_game
    port map (
        -- Clock / reset
        rst         => reset,
        clk         => clk_main_i,
        prog_clk    => dn_clk_i,

        -- Clock enables
        cen8        => cen8,
        cen3        => cen3,
        cen1p5      => cen1p5,

        -- Pixel enables
        pxl_cen     => cen6,
        pxl2_cen    => cen12,

        -- Cabinet
        joystick1   => joystick1,
        joystick2   => joystick2,
        coin        => gs_coin,
        cab_1p      => gs_cab_1p,
        service     => service,

        -- DIP switches
        dipsw       => gs_dipsw,
        dip_pause   => dip_pause,
        dip_flip    => dip_flip,

        -- Video
        red          => video_red_o,
        green        => video_green_o,
        blue         => video_blue_o,
        LHBL         => video_hblank_o,
        LVBL         => video_vblank_o,
        HS           => video_hs_o,
        VS           => video_vs_o,

        -- Audio
        psg0        => psg0,
        psg1        => psg1,
        fm0         => fm0,
        fm1         => fm1,

        -- Main ROM
        main_cs     => gs_main_cs,
        main_addr   => gs_main_addr,
        main_data   => gs_main_data,
        main_ok     => gs_main_ok,

        -- Sound ROM
        snd_cs      => gs_snd_cs,
        snd_addr    => gs_snd_addr,
        snd_data    => gs_snd_data,
        snd_ok      => gs_snd_ok,

        -- Character ROM
        char_addr   => gs_char_addr,
        char_data   => gs_char_data,
        char_ok     => gs_char_ok,

        -- Scroll map ROM
        map_cs      => gs_map_cs,
        map_addr    => gs_map_addr,
        map_data    => gs_map_data,
        map_ok      => gs_map_ok,

        -- Scroll graphics ROM
        scr_addr    => gs_scr_addr,
        scr_data    => gs_scr_data,
        scr_ok      => gs_scr_ok,

        -- Object ROM
        obj_addr    => gs_obj_addr,
        obj_data    => gs_obj_data,
        obj_ok      => gs_obj_ok,

        -- PROM programming
        prog_addr   => prog_addr,
        prog_data   => prog_data,
        prom_we     => prom_we,
        ioctl_addr  => std_logic_vector(resize(unsigned(dn_addr_i), 25)),

        -- Layer enables
        gfx_en      => "1111",

        -- Debug
        debug_bus   => (others => '0'),
        debug_view  => open
    );
   
   
   -- Jotego audio path.
   -- Use the audio mixer
    i_audio_mixer : entity work.jtframe_mixer
    generic map (
       W0   => 10,
       W1   => 10,
       W2   => 16,
       W3   => 16,
       WOUT => 16
    )
    port map (
       rst   => reset,
       clk   => clk_main_i,
       cen   => '1',
    
       ch0   => signed(psg0),
       ch1   => signed(psg1),
       ch2   => signed(fm0),
       ch3   => signed(fm1),
    
       gain0 => x"10",
       gain1 => x"10",
       gain2 => x"10",
       gain3 => x"10",
    
       mixed => audio_mixed,
       peak  => open
    );
    
    audio_left_o  <= audio_mixed;
    audio_right_o <= audio_mixed;


    -- -------------------------------------------------------------------------
    -- Gun.Smoke ROM BRAMs
    -- Port A = 48 MHz core read
    -- Port B = QNICE download
    -- -------------------------------------------------------------------------
    
    -- Main CPU ROM
    i_rom_main : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 17,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_main_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => gs_main_data,
    
        clock_b   => dn_clk_i,
        address_b => dl_main_off(16 downto 0),
        data_b    => dn_data_i,
        wren_b    => dn_main_we,
        q_b       => open
    );
    
    -- Sound CPU ROM
    i_rom_snd : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 15,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_snd_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => gs_snd_data,
    
        clock_b   => dn_clk_i,
        address_b => dl_snd_off(14 downto 0),
        data_b    => dn_data_i,
        wren_b    => dn_snd_we,
        q_b       => open
    );
    
    -- Character ROM - low byte
    i_rom_char_0 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 13,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_char_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => char_q0,
    
        clock_b   => dn_clk_i,
        address_b => dl_char_off(13 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_char_lo_we,
        q_b       => open
    );
    
    -- Character ROM - high byte
    i_rom_char_1 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 13,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_char_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => char_q1,
    
        clock_b   => dn_clk_i,
        address_b => dl_char_off(13 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_char_hi_we,
        q_b       => open
    );
    
    -- Scroll map ROM - low byte
    i_rom_map_0 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 15,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_map_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => map_q0,
    
        clock_b   => dn_clk_i,
        address_b => dl_map_off(15 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_map_lo_we,
        q_b       => open
    );
    
    -- Scroll map ROM - high byte
    i_rom_map_1 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 15,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_map_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => map_q1,
    
        clock_b   => dn_clk_i,
        address_b => dl_map_off(15 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_map_hi_we,
        q_b       => open
    );
    
    -- Scroll graphics ROM - low byte
    i_rom_scr_0 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 17,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_scr_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => scr_q0,
    
        clock_b   => dn_clk_i,
        address_b => dl_scr_off(17 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_scr_lo_we,
        q_b       => open
    );
    
    -- Scroll graphics ROM - high byte
    i_rom_scr_1 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 17,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_scr_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => scr_q1,
    
        clock_b   => dn_clk_i,
        address_b => dl_scr_off(17 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_scr_hi_we,
        q_b       => open
    );
    
    -- Object ROM - low byte
    i_rom_obj_0 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 17,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_obj_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => obj_q0,
    
        clock_b   => dn_clk_i,
        address_b => dl_obj_off(17 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_obj_lo_we,
        q_b       => open
    );
    
    -- Object ROM - high byte
    i_rom_obj_1 : entity work.dualport_2clk_ram
    generic map (
        ADDR_WIDTH => 17,
        DATA_WIDTH => 8,
        FALLING_A  => false,
        FALLING_B  => true
    )
    port map (
        clock_a   => clk_main_i,
        address_a => gs_obj_addr,
        data_a    => (others => '0'),
        wren_a    => '0',
        q_a       => obj_q1,
    
        clock_b   => dn_clk_i,
        address_b => dl_obj_off(17 downto 1),
        data_b    => dn_data_i,
        wren_b    => dn_obj_hi_we,
        q_b       => open
    );

     
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      ); -- i_keyboard

end architecture synthesis;