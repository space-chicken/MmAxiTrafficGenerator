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

entity TrafficGenerator is
  generic
  (
    G_TIMEBASE_WIDTH        : integer := 32;
    G_ADDRESS_WIDTH         : integer := 32;
    G_COUNTERS_WIDTH        : integer := 32;
    G_AXI_DATA_WIDTH        : integer := 128;
    G_AXI_ADDR_WIDTH        : integer := 49;
    G_USE_TIME_COUNTER      : boolean := FALSE;
    G_READ_IDLE_CYCLES      : integer := 0;
    G_WRITE_IDLE_CYCLES     : integer := 0
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
    i_transfers_count       : in  std_logic_vector(( G_COUNTERS_WIDTH        - 1) downto 0);        -- Total number of transfers
    i_burst_size            : in  std_logic_vector(( G_COUNTERS_WIDTH        - 1) downto 0);        -- Burst size in bytes
    i_address               : in  std_logic_vector(( G_ADDRESS_WIDTH         - 1) downto 0);        -- Start address for sequential and random accesses
    i_boundary              : in  std_logic_vector(( G_ADDRESS_WIDTH         - 1) downto 0);        -- Last address
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
    o_axi_awprot            : out std_logic_vector(                          2  downto 0)   := (others => '0');
    o_axi_awid              : out std_logic_vector(                          5  downto 0)   := (others => '0');
    o_axi_awuser            : out std_logic                                                 := '0';
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
    o_axi_arprot            : out std_logic_vector(                          2  downto 0)   := (others => '0');
    o_axi_arid              : out std_logic_vector(                          5  downto 0)   := (others => '0');
    o_axi_aruser            : out std_logic                                                 := '0';
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
end entity;

architecture RTL of TrafficGenerator is

  ------------------------------------------------------
  -- CONSTANTS
  ------------------------------------------------------
  constant K_MAX_BURST_SIZE             : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := x"00001000";   -- 4096 bytes
  constant K_MIN_BURST_SIZE             : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := x"00000020";   -- 32 bytes
  constant K_AXI_CACHE_CONFIG           : std_logic_vector(                    3  downto 0) := b"0000";       -- Device is not bufferable

  -- AXI xRESP values
  constant AXI_BRESP_OKAY               : std_logic_vector(                    1  downto 0) := b"00";
  constant AXI_BRESP_EXOKAY             : std_logic_vector(                    1  downto 0) := b"01";
  constant AXI_BRESP_SLVERR             : std_logic_vector(                    1  downto 0) := b"10";
  constant AXI_BRESP_DECERR             : std_logic_vector(                    1  downto 0) := b"11";

  ------------------------------------------------------
  -- TYPES
  ------------------------------------------------------
  subtype  T_TIME_COUNTER               is integer range 0 to G_TIME_COUNTER_DIVIDER;
  subtype  T_IDLE_COUNTER               is integer range 0 to G_IDLE_CLOCK_CYCLES;

  ------------------------------------------------------
  -- SIGNALS
  ------------------------------------------------------
  signal burst_size_valid               : std_logic                                         := '0';
  signal transfer_count_valid           : std_logic                                         := '0';
  signal ready                          : std_logic                                         := '0';
  signal run                            : std_logic                                         := '0';
  signal enable                         : std_logic                                         := '0';
  signal done                           : std_logic                                         := '0';
  signal busy                           : std_logic                                         := '0';
  signal completed                      : std_logic                                         := '0';
  signal wait_response                  : std_logic                                         := '0';
  signal wait_data                      : std_logic                                         := '0';
  signal axi_awvalid                    : std_logic                                         := '0';
  signal axi_arvalid                    : std_logic                                         := '0';
  signal axi_rready                     : std_logic                                         := '0';
  signal axi_bready                     : std_logic                                         := '0';
  signal axi_wvalid                     : std_logic                                         := '0';
  signal axi_wlast                      : std_logic                                         := '0';
  signal timestamp_captured             : std_logic                                         := '0';
  signal wr_nxt_address_valid           : std_logic                                         := '0';
  signal rd_nxt_address_valid           : std_logic                                         := '0';
  signal hold                           : std_logic                                         := '0';
  signal read_hold                      : std_logic                                         := '0';
  signal write_hold                     : std_logic                                         := '0';
  signal beat_count                     : std_logic_vector(                    8  downto 0) := (others => '0');
  signal beat_counter                   : std_logic_vector(                    8  downto 0) := (others => '0');
  signal nxt_write_addr                 : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal write_boundary                 : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal wr_random_value                : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal write_address                  : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal nxt_read_addr                  : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal read_boundary                  : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal rd_random_value                : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal read_address                   : std_logic_vector((G_ADDRESS_WIDTH  - 1) downto 0) := (others => '0');
  signal write_data                     : std_logic_vector((G_AXI_DATA_WIDTH - 1) downto 0) := (others => '0');
  signal write_responses                : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := (others => '0');
  signal write_errors                   : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := (others => '0');
  signal read_errors                    : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := (others => '0');
  signal axi_awaddr                     : std_logic_vector((G_AXI_DATA_WIDTH - 1) downto 0) := (others => '0');
  signal axi_araddr                     : std_logic_vector((G_AXI_DATA_WIDTH - 1) downto 0) := (others => '0');
  signal read_counter                   : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := (others => '0');
  signal write_counter                  : std_logic_vector((G_COUNTERS_WIDTH - 1) downto 0) := (others => '0');
  signal random_data                    : std_logic_vector((G_AXI_DATA_WIDTH - 1) downto 0) := (others => '0');
  signal start_timestamp                : std_logic_vector((G_TIMEBASE_WIDTH - 1) downto 0) := (others => '0');
  signal stop_timestamp                 : std_logic_vector((G_TIMEBASE_WIDTH - 1) downto 0) := (others => '0');
  signal timebase                       : std_logic_vector((G_TIMEBASE_WIDTH - 1) downto 0) := (others => '0');
  signal time_counter                   : T_TIME_COUNTER;
  signal read_idle_count                : T_IDLE_COUNTER;
  signal write_idle_count               : T_IDLE_COUNTER;

  ------------------------------------------------------
  -- ATTRIBUTES (DEBUG)
  ------------------------------------------------------
  attribute KEEP                        : string;
  attribute KEEP of ready               : signal is "TRUE";
  attribute KEEP of run                 : signal is "TRUE";
  attribute KEEP of enable              : signal is "TRUE";
  attribute KEEP of done                : signal is "TRUE";
  attribute KEEP of busy                : signal is "TRUE";
  attribute KEEP of wait_response       : signal is "TRUE";
  attribute KEEP of wait_data           : signal is "TRUE";
  attribute KEEP of beat_count          : signal is "TRUE";
  attribute KEEP of beat_counter        : signal is "TRUE";
  attribute KEEP of write_data          : signal is "TRUE";
  attribute KEEP of read_address        : signal is "TRUE";
  attribute KEEP of write_responses     : signal is "TRUE";
  attribute KEEP of read_counter        : signal is "TRUE";
  attribute KEEP of write_counter       : signal is "TRUE";
  attribute KEEP of start_timestamp     : signal is "TRUE";
  attribute KEEP of stop_timestamp      : signal is "TRUE";
  attribute KEEP of read_idle_count     : signal is "TRUE";
  attribute KEEP of write_idle_count    : signal is "TRUE";

  ------------------------------------------------------
  -- FUNCTIONS
  ------------------------------------------------------
  function log2 (number : integer) return integer is
    variable index  : integer;
  begin
    index := 0;  
    while (2**index < number) and index < 31 loop
      index         := index + 1;
    end loop;
    return index;
  end function;
  
begin

  -- =======================
  --         OUTPUTS        
  -- =======================
  assert (log2(G_AXI_DATA_WIDTH / 8) + beat_count'high) <= i_burst_size report "G_COUNTER_WIDTH is to small" severity error;

  -- =======================
  --         OUTPUTS        
  -- =======================
  o_error_count             <= read_errors + write_errors;
  o_write_count             <= write_responses;
  o_read_count              <= read_counter;
  o_done                    <= done;
  o_busy                    <= busy;

  -- =======================
  --      CONTROL LOGIC
  -- =======================
  -- AXI signals
  o_axi_araddr((G_COUNTERS_WIDTH - 1) downto 0) <= read_address  when i_run = '1' else (others => '0');
  o_axi_awaddr((G_COUNTERS_WIDTH - 1) downto 0) <= write_address when i_run = '1' else (others => '0');

  UnusedAddressBits: if G_AXI_ADDR_WIDTH > G_COUNTERS_WIDTH generate
    o_axi_araddr((G_AXI_ADDR_WIDTH - 1) downto G_COUNTERS_WIDTH) <= (others => '0');
    o_axi_awaddr((G_AXI_ADDR_WIDTH - 1) downto G_COUNTERS_WIDTH) <= (others => '0');
  end generate;

  -- AXI specification require o_axi_awlen to be (beat_count - 1)
  o_axi_awlen               <= ((beat_count(7 downto 0)) - 1) when i_run = '1' else (o_axi_awlen'range   => '0');
  o_axi_awburst             <= "01"                           when i_run = '1' else (o_axi_awburst'range => '0');
  o_axi_awsize              <= "001" when G_AXI_DATA_WIDTH =   16 and i_run = '1' else
                               "010" when G_AXI_DATA_WIDTH =   32 and i_run = '1' else
                               "011" when G_AXI_DATA_WIDTH =   64 and i_run = '1' else
                               "100" when G_AXI_DATA_WIDTH =  128 and i_run = '1' else
                               "101" when G_AXI_DATA_WIDTH =  256 and i_run = '1' else
                               "110" when G_AXI_DATA_WIDTH =  512 and i_run = '1' else
                               "111" when G_AXI_DATA_WIDTH = 1024 and i_run = '1' else "000";

  -- AXI specification require o_axi_arlen to be (beat_count - 1)
  o_axi_arlen               <= ((beat_count(7 downto 0)) - 1) when i_run = '1' else (o_axi_arlen'range   => '0');
  o_axi_arburst             <= "01"                           when i_run = '1' else (o_axi_arburst'range => '0');
  o_axi_arsize              <= "001" when G_AXI_DATA_WIDTH =   16 and i_run = '1' else
                               "010" when G_AXI_DATA_WIDTH =   32 and i_run = '1' else
                               "011" when G_AXI_DATA_WIDTH =   64 and i_run = '1' else
                               "100" when G_AXI_DATA_WIDTH =  128 and i_run = '1' else
                               "101" when G_AXI_DATA_WIDTH =  256 and i_run = '1' else
                               "110" when G_AXI_DATA_WIDTH =  512 and i_run = '1' else
                               "111" when G_AXI_DATA_WIDTH = 1024 and i_run = '1' else "000";

  o_axi_rready              <= axi_rready;
  o_axi_bready              <= axi_bready;

  o_axi_wvalid              <= axi_wvalid and i_axi_wready;
  o_axi_wlast               <= axi_wlast  and i_axi_wready;

  o_axi_awvalid             <= axi_awvalid and i_axi_awready;
  o_axi_arvalid             <= axi_arvalid and i_axi_arready;

  -- Valid input parameters
  burst_size_valid          <= '1' when (i_burst_size <= K_MAX_BURST_SIZE and i_burst_size >= K_MIN_BURST_SIZE) else '0';
  transfer_count_valid      <= '1' when (i_transfers_count > (i_transfers_count'range => '0'))                  else '0';
  
  -- Beat count = (Burst size in bytes) / ((AXI data width) / 8);
  beat_count                <= i_burst_size((log2(G_AXI_DATA_WIDTH / 8) + beat_count'high) downto log2(G_AXI_DATA_WIDTH / 8));

  -- Control signals
  ready                     <= burst_size_valid and transfer_count_valid;
  run                       <= enable and ready;
  completed                 <= '1' when ((read_counter = i_transfers_count and wait_data = '0') or i_read_enb = '0') and ((write_counter = i_transfers_count and wait_response = '0') or i_write_enb = '0') and ready = '1' and (i_write_enb = '1' or i_read_enb = '1') else '0';
  busy                      <= (enable or wait_response or wait_data) and ready;
  hold                      <= read_hold or write_hold;

  -- Module run control
  RunStopControl: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' then
        enable              <= '0';
        done                <= '0';
      else
        if i_run = '1' and ready = '1' and completed = '0' then
          enable            <= '1';
          done              <= '0';
        elsif i_run = '0' or ready = '0' or completed = '1' then
          enable            <= '0';
          if completed = '1' then
            done            <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Requests sender
  FastReadRequester: if G_READ_IDLE_CYCLES = 0 then
    ReadRequester: process(i_clock)
    begin
      if rising_edge(i_clock) then
        if i_reset = '1' or i_read_enb = '0' or run = '0' then
          axi_arvalid         <= '0';
          read_address        <= i_address;
        else
          if read_counter < i_transfers_count and i_axi_arready = '1' and wait_data = '0' then
            -- Send request
            axi_arvalid       <= '1';
            wait_data         <= '1';
          elsif axi_arvalid = '1' then
            -- Update address
            axi_arvalid       <= '0';
            read_address      <= nxt_read_addr;
          elsif i_axi_rlast = '1' and wait_data = '1' then
            -- Data received
            wait_data         <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  SlowReadRequester: if G_READ_IDLE_CYCLES > 0 then
    ReadRequester: process(i_clock)
    begin
      if rising_edge(i_clock) then
        if i_reset = '1' or i_read_enb = '0' or run = '0' then
          axi_arvalid         <= '0';
          read_address        <= i_address;
          read_idle_count     <=  0;
          read_hold           <= '0';
        else
          if read_counter < i_transfers_count and i_axi_arready = '1' and wait_data = '0' then
            if read_idle_count = G_READ_IDLE_CYCLES then
              -- Send request
              axi_arvalid       <= '1';
              wait_data         <= '1';
              read_idle_count   <=  0;
              read_hold         <= '0';
            else
              -- Wait x number of clock cycles
              read_idle_count   <= read_idle_count + 1;
              read_hold         <= '1';
            end if;
          elsif axi_arvalid = '1' then
            -- Update address
            axi_arvalid       <= '0';
            read_address      <= nxt_read_addr;
          elsif i_axi_rlast = '1' and wait_data = '1' then
            -- Data received
            wait_data         <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  FastWriteRequester: if G_WRITE_IDLE_CYCLES = 0 then
    WriteRequester: process(i_clock)
    begin
      if rising_edge(i_clock) then
        if i_reset = '1' or i_write_enb = '0' or run = '0' then
          axi_awvalid         <= '0';
          wait_response       <= '0';
          write_address       <= i_address;
        else
          if write_counter < i_transfers_count and i_axi_awready = '1' and wait_response = '0' then
            -- Send request
            axi_awvalid       <= '1';
            wait_response     <= '1';
          elsif axi_awvalid = '1' then
            -- Update address
            axi_awvalid       <= '0';
            write_address     <= nxt_write_addr;
          elsif i_axi_bvalid = '1' and wait_response = '1' then
            -- Response received
            wait_response     <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  SlowWriteRequester: if G_WRITE_IDLE_CYCLES > 0 then
    WriteRequester: process(i_clock)
    begin
      if rising_edge(i_clock) then
        if i_reset = '1' or i_write_enb = '0' or run = '0' then
          axi_awvalid         <= '0';
          wait_response       <= '0';
          write_address       <= i_address;
          write_idle_count    <=  0;
          write_hold          <= '0';
        else
          if write_counter < i_transfers_count and i_axi_awready = '1' and wait_response = '0' then
            if write_idle_count = G_WRITE_IDLE_CYCLES then
              -- Send request
              axi_awvalid       <= '1';
              wait_response     <= '1';
              write_idle_count  <=  0;
              write_hold        <= '0';
            else
              write_idle_count  <= write_idle_count + 1;
              write_hold        <= '1';
            end if;
          elsif axi_awvalid = '1' then
            -- Update address
            axi_awvalid       <= '0';
            write_address     <= nxt_write_addr;
          elsif i_axi_bvalid = '1' and wait_response = '1' then
            -- Response received
            wait_response     <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  -- =======================
  --     DATA GENERATOR     
  -- =======================
  PseudoRandomDataGenerator: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_load = '1' then
        random_data         <= i_seed;
      elsif random_data > (random_data'range => '0') then
        random_data((G_AXI_DATA_WIDTH - 1) downto 1) <= random_data((G_AXI_DATA_WIDTH - 2) downto 0);
        random_data(0)      <= random_data(126) xor random_data(125) xor random_data(124) xor random_data(89) xor random_data(88);
      end if;

      write_data            <= random_data;
    end if;
  end process;

  -- =======================
  --    ADDRESS GENERATOR     
  -- =======================
  read_boundary             <= rd_random_value + i_burst_size;
  NextReadAddress: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if enable = '1' and i_read_enb = '1' then
        if i_random = '1' then
          if (rd_nxt_address_valid = '0' or axi_arvalid = '1') then
            rd_nxt_address_valid    <= '0';
            rd_random_value         <= write_data(45 downto 26) & b"000000000000";
            if read_boundary < i_boundary and rd_random_value > i_address then
              nxt_read_addr         <= rd_random_value;

              -- Generate random address until the value is
              -- within the range of allowed addresses
              rd_nxt_address_valid  <= '1';
            end if;
          end if;
        else
          if axi_arvalid = '1' then
            nxt_read_addr   <= nxt_read_addr + i_burst_size;
            if nxt_read_addr >= i_boundary then
              nxt_read_addr <= i_address;
            end if;
          end if;
        end if;
      else
        if i_random = '0' then
          nxt_read_addr     <= i_address + i_burst_size;
        else
          nxt_read_addr     <= i_address;
        end if;
      end if;
    end if;
  end process;

  write_boundary            <= wr_random_value + i_burst_size;
  NextWriteAddress: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if enable = '1' and i_write_enb = '1' then
        if i_random = '1' then
          if (wr_nxt_address_valid = '0' or axi_awvalid = '1') then
            wr_nxt_address_valid    <= '0';
            wr_random_value         <= write_data(71 downto 52) & b"000000000000";
            if write_boundary < i_boundary and wr_random_value > i_address then
              nxt_write_addr        <= wr_random_value;

              -- Generate random address until the value is
              -- within the range of allowed addresses
              wr_nxt_address_valid  <= '1';
            end if;
          end if;
        else
          if axi_awvalid = '1' then
            nxt_write_addr  <= nxt_write_addr + i_burst_size;
            if nxt_write_addr >= i_boundary then
              nxt_write_addr <= i_address;
            end if;
          end if;
        end if;
      else
        if i_random = '0' then
          nxt_write_addr    <= i_address + i_burst_size;
        else
          nxt_write_addr    <= i_address;
        end if;
      end if;
    end if;
  end process;

  -- =======================
  --      READ CHANNEL     
  -- =======================
  ReadCompleter: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' or i_run = '0' or i_read_enb = '0' then
        read_counter        <= (others => '0');
        read_errors         <= (others => '0');
        axi_rready          <= '0';
      else
        axi_rready          <= '1';

        if i_axi_rvalid = '1' then
          if i_axi_rresp = AXI_BRESP_SLVERR or i_axi_rresp = AXI_BRESP_DECERR then
            read_errors     <= read_errors + 1;
          end if;

          if i_axi_rlast = '1' then
            read_counter    <= read_counter + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- =======================
  --      WRITE CHANNEL     
  -- =======================
  DataWriter: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' or i_write_enb = '0' or i_run = '0' then
        write_counter       <= (others => '0');
        beat_counter        <= (others => '0');
        axi_wvalid          <= '0';
        axi_wlast           <= '0';
        o_axi_wstrb         <= (others => '0');
      else
        axi_wlast           <= '0';
        axi_wvalid          <= '0';
        o_axi_wstrb         <= (others => '0');

        if wait_response = '1' then
          if i_axi_wready = '1' then
            if write_counter < i_transfers_count then
              if beat_counter < beat_count then
                if beat_counter = (beat_count - 1) then
                  axi_wlast     <= '1';
                  write_counter <= write_counter + 1;
                end if;

                beat_counter  <= beat_counter + 1;

                o_axi_wdata   <= write_data;
                o_axi_wstrb   <= (others => '1');
                axi_wvalid    <= '1';
              end if;
            end if;
          end if;
        else
          beat_counter        <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  WriteCompleter: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' or i_write_enb = '0' then
        axi_bready          <= '0';
        write_responses     <= (others => '0');
        write_errors        <= (others => '0');
      else
        axi_bready          <= '1';

        if i_axi_bvalid = '1' then
          write_responses   <= write_responses + 1;

          if i_axi_bresp = AXI_BRESP_SLVERR or i_axi_bresp = AXI_BRESP_DECERR then
            write_errors    <= write_errors + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- =======================
  --       TIMESTAMPS       
  -- =======================
  -- Use external timebase
  UseExternalTimebase: if G_USE_TIME_COUNTER = FALSE generate
    timebase                <= i_timebase;
  end generate;

  -- Use internal timebase
  UseInternalTimebase: if G_USE_TIME_COUNTER = TRUE generate
    TimebaseProcess: process(i_clock)
    begin
      if rising_edge(i_clock) then
        if hold = '0' then
          if time_counter < G_TIME_COUNTER_DIVIDER then
            time_counter    <= time_counter + 1;
          else
            time_counter    <= 0;
            timebase        <= timebase + 1;
          end if;
        end if;
      end if;
    end process;
  end generate;
  

  -- Capture start/stop timestamps
  StartStopTime: process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' then
        start_timestamp       <= (others => '0');
        stop_timestamp        <= (others => '0');
        timestamp_captured    <= '0';
      else
        if run = '1' and timestamp_captured = '0' then
          start_timestamp     <= timebase;
          timestamp_captured  <= '1';
        elsif completed = '1' and timestamp_captured = '1' then
          stop_timestamp      <= timebase;
          timestamp_captured  <= '0';
        end if;
      end if;
    end if;
  end process;

  -- =======================
  --       UNUSED AXI      
  -- =======================
  o_axi_awcache             <= K_AXI_CACHE_CONFIG;
  o_axi_arcache             <= K_AXI_CACHE_CONFIG;

end architecture;