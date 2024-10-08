--  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
--    .d8888. d8888b.  .d8b.   .o88b. d88888b       .o88b. db   db d888888b  .o88b. db   dD d88888b d8b   db
--    88'  YP 88  `8D d8' `8b d8P  Y8 88'          d8P  Y8 88   88   `88'   d8P  Y8 88 ,8P' 88'     888o  88
--    `8bo.   88oodD' 88ooo88 8P      88ooooo      8P      88ooo88    88    8P      88,8P   88ooooo 88V8o 88
--      `Y8b. 88      88   88 8b      88      C88D 8b      88   88    88    8b      88`8b   88      88 V8o88
--    db   8D 88      88   88 Y8b  d8 88.          Y8b  d8 88   88   .88.   Y8b  d8 88 `88. 88.     88  V888 
--    `8888Y' 88      YP   YP  `Y88P' Y88888P       `Y88P' YP   YP Y888888P  `Y88P' YP   YD Y88888P VP   V8P
--
--  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--  Description: Memory-mapped AXI traffic generator.
--  
--  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

library ieee, work;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

package TrafficGenerator_P is
  component TrafficGenerator is
    generic
    (
      G_TIMEBASE_WIDTH        : integer := 32;
      G_ADDRESS_WIDTH         : integer := 32;
      G_COUNTERS_WIDTH        : integer := 32;
      G_AXI_DATA_WIDTH        : integer := 128;
      G_AXI_ADDR_WIDTH        : integer := 49
    );
    port
    (
      ------------------------------------------------------
      -- CLOCK & RESET
      ------------------------------------------------------
      i_clock                 : in  std_logic;
      i_reset                 : in  std_logic;

      ------------------------------------------------------
      -- CONTROL & STATUS SIGNALS
      ------------------------------------------------------
      i_transfers_count       : in  std_logic_vector(( G_COUNTERS_WIDTH      - 1) downto 0);          -- Total number of transfers
      i_burst_size            : in  std_logic_vector(( G_COUNTERS_WIDTH      - 1) downto 0);          -- Burst size in bytes
      i_address               : in  std_logic_vector(( G_ADDRESS_WIDTH       - 1) downto 0);          -- Start address for sequential and random accesses
      i_boundary              : in  std_logic_vector(( G_ADDRESS_WIDTH       - 1) downto 0);          -- Last address
      i_run                   : in  std_logic;                                                        -- Module control signal
      i_random                : in  std_logic;                                                        -- Random address generation
      i_read_enb              : in  std_logic;                                                        -- Read channel enable
      i_write_enb             : in  std_logic;                                                        -- Write channel enable
      o_busy                  : out std_logic;                                                        -- Busy signal
      o_done                  : out std_logic;                                                        -- Complete signal

      ------------------------------------------------------
      -- TIMEBASE
      ------------------------------------------------------
      i_timebase              : in  std_logic_vector(( G_TIMEBASE_WIDTH      - 1) downto 0);          -- Free running timebase that is used to capture start/stop time

      ------------------------------------------------------
      -- RANDOM GENERATOR SIGNALS
      ------------------------------------------------------
      i_seed                  : in  std_logic_vector(( G_AXI_DATA_WIDTH      - 1) downto 0);
      i_load                  : in  std_logic;

      ------------------------------------------------------
      -- STATISTIC COUNTERS
      ------------------------------------------------------
      o_read_count            : out std_logic_vector(( G_COUNTERS_WIDTH      - 1) downto 0);          -- Total number of read transfers
      o_write_count           : out std_logic_vector(( G_COUNTERS_WIDTH      - 1) downto 0);          -- Total number of write transfers
      o_error_count           : out std_logic_vector(( G_COUNTERS_WIDTH      - 1) downto 0);          -- Total number of error
      o_start                 : out std_logic_vector(( G_TIMEBASE_WIDTH      - 1) downto 0);          -- Transfer start timestamp
      o_stop                  : out std_logic_vector(( G_TIMEBASE_WIDTH      - 1) downto 0);          -- Transfer stop timestamp

      ------------------------------------------------------
      -- MEMORY-MAPPED AXI
      ------------------------------------------------------
      -- AXI write address channel
      o_axi_awaddr            : out std_logic_vector(( G_AXI_ADDR_WIDTH      - 1) downto 0);
      o_axi_awlen             : out std_logic_vector(                          7  downto 0);
      o_axi_awsize            : out std_logic_vector(                          2  downto 0);
      o_axi_awburst           : out std_logic_vector(                          1  downto 0);
      o_axi_awcache           : out std_logic_vector(                          3  downto 0);
      o_axi_awprot            : out std_logic_vector(                          2  downto 0);
      o_axi_awid              : out std_logic_vector(                          5  downto 0);
      o_axi_awuser            : out std_logic;
      i_axi_awready           : in  std_logic;
      o_axi_awvalid           : out std_logic;

      -- AXI write channel
      o_axi_wdata             : out std_logic_vector(( G_AXI_DATA_WIDTH      - 1) downto 0);
      o_axi_wstrb             : out std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0);
      o_axi_wlast             : out std_logic;
      i_axi_wready            : in  std_logic;
      o_axi_wvalid            : out std_logic;

      -- AXI write response channel
      i_axi_bid               : in  std_logic_vector(                          5  downto 0);
      i_axi_bresp             : in  std_logic_vector(                          1  downto 0);
      o_axi_bready            : out std_logic;
      i_axi_bvalid            : in  std_logic;
      
      -- AXI read address channel
      o_axi_araddr            : out std_logic_vector(( G_AXI_ADDR_WIDTH      - 1) downto 0);
      o_axi_arlen             : out std_logic_vector(                          7  downto 0);
      o_axi_arsize            : out std_logic_vector(                          2  downto 0);
      o_axi_arburst           : out std_logic_vector(                          1  downto 0);
      o_axi_arcache           : out std_logic_vector(                          3  downto 0);
      o_axi_arprot            : out std_logic_vector(                          2  downto 0);
      o_axi_arid              : out std_logic_vector(                          5  downto 0);
      o_axi_aruser            : out std_logic;
      i_axi_arready           : in  std_logic;
      o_axi_arvalid           : out std_logic;

      -- AXI read channel
      i_axi_rdata             : in  std_logic_vector(( G_AXI_DATA_WIDTH      - 1) downto 0);
      i_axi_rid               : in  std_logic_vector(                          5  downto 0);
      i_axi_rresp             : in  std_logic_vector(                          1  downto 0);
      i_axi_rlast             : in  std_logic;
      o_axi_rready            : out std_logic;
      i_axi_rvalid            : in  std_logic
    );
  end component;
end package;
