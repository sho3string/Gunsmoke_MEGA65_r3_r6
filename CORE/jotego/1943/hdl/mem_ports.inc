// 1943 memory interface, derived from cores/1943/cfg/mem.yaml.
// Hand-authored M2M interface: not JTFRAME memgen output.
    output          main_cs,
    output [17:0]   main_addr,
    input  [7:0]    main_data,
    input           main_ok,

    output [14:0]   snd_addr,
    input  [7:0]    snd_data,

    output [14:0]   char_addr,
    input  [15:0]   char_data,
    input           char_ok,

    output [14:0]   map1_addr,
    input  [15:0]   map1_data,
    input           map1_ok,
    output          map1_cs,

    output [14:0]   map2_addr,
    input  [15:0]   map2_data,
    input           map2_ok,
    output          map2_cs,

    output [17:0]   scr1_addr,
    input  [15:0]   scr1_data,
    output [15:0]   scr2_addr,
    input  [15:0]   scr2_data,

    output [17:0]   obj_addr,
    input  [15:0]   obj_data,
    input           obj_ok,

    input  [25:0]   ioctl_addr,
    input  [25:0]   prog_addr,
    input  [7:0]    prog_data,
    input           prom_we
