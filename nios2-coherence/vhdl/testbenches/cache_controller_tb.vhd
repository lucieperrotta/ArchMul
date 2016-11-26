library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mem_types.all;
use work.soc_components.all;

entity cache_controller_tb is

end entity cache_controller_tb;

architecture test of cache_controller_tb is
  signal clk                            : std_logic := '0';
  signal rst                            : std_logic := '0';
  signal cacheCs, cacheRead, cacheWrite : std_logic;
  signal cacheAddr                      : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal cacheWrData                    : data_word_t;
  signal cacheDone                      : std_logic;
  signal cacheRdData                    : data_word_t;
  signal busReq                         : std_logic;
  signal busCmd                         : bus_cmd_t;
  signal busSnoopValid                  : std_logic;
  signal busGrant                       : std_logic;
  signal busAddr                        : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal busData                        : data_block_t;

  signal invalidateAddr                   : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal busInvalidate, busFakeInvalidate : std_logic := '0';
  signal busRdDataAux                     : data_block_t;
  type bus_st_t is (IDLE, WORKING);
  signal busSt                            : bus_st_t;
  type request_type_t is record
    hitExpected              : std_logic;
    concurrentInvalidate     : std_logic;
    concurrentFakeInvalidate : std_logic;
    wrEn                     : std_logic;
    addr                     : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    invAddr                  : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    wrData                   : data_word_t;
    rdData                   : data_block_t;
  end record request_type_t;

  constant CLK_PERIOD : time := 40 ns;

begin  -- architecture test

  -- clk generator process
  process
  begin
    clk <= not clk;
    wait for CLK_PERIOD/2;
  end process;


  process
    constant BUS_GRANT_DELAY : integer := 5;
    variable busGrantCounter : integer := 0;
  begin
    busSt         <= IDLE;
    busGrant      <= '0';
    busSnoopValid <= '0';
    if busReq = '1' then
      busGrant        <= '1';
      busSnoopValid   <= '1';
      busSt           <= WORKING;
      busGrantCounter := 0;
      while busGrantCounter < BUS_GRANT_DELAY loop
        wait until clk'event and clk = '1';
        busSnoopValid   <= '0';
        busGrantCounter := busGrantCounter + 1;
      end loop;
      busSnoopValid <= '0';
      busGrant      <= '0';
      busData       <= busRdDataAux;
      wait until clk'event and clk = '1';
      busData       <= DATA_BLOCK_HIGH_IMPEDANCE;
    elsif busInvalidate = '1' then
      busSnoopValid <= '1';
      busGrant      <= '0';
      busAddr       <= invalidateAddr;
      busCmd        <= BUS_WRITE;
      wait until clk'event and clk = '1';
      busSnoopValid <= '0';
      busGrant      <= '0';
      busAddr       <= (others => 'Z');
      busCmd        <= (others => 'Z');
    elsif busFakeInvalidate = '1' then
      busSnoopValid <= '1';
      busGrant      <= '0';
      busAddr       <= invalidateAddr;
      busCmd        <= BUS_READ;
      wait until clk'event and clk = '1';
      busSnoopValid <= '0';
      busGrant      <= '0';
      busAddr       <= (others => 'Z');
      busCmd        <= (others => 'Z');
    else
      wait until clk'event and clk = '1';
      busAddr  <= (others => 'Z');
      busCmd   <= (others => 'Z');
      busSt    <= IDLE;
      busGrant <= '0';
      busData  <= DATA_BLOCK_HIGH_IMPEDANCE;
    end if;


  end process;

  -- signal drive process
  process
    procedure issueInvalidate (
      addr : in std_logic_vector(WORD_ADDR_WIDTH-1 downto 0)) is
    begin  -- procedure issueInvalidate
      busInvalidate  <= '1';
      invalidateAddr <= addr;
      wait until clk'event and clk = '1';
      busInvalidate  <= '0';

    end procedure issueInvalidate;

    procedure issueFakeInvalidate (
      addr : in std_logic_vector(WORD_ADDR_WIDTH-1 downto 0)) is
    begin  -- procedure issueInvalidate
      busFakeInvalidate <= '1';
      invalidateAddr    <= addr;
      wait until clk'event and clk = '1';
      busFakeInvalidate <= '0';

    end procedure issueFakeInvalidate;



    procedure issueReq (
      req : in request_type_t) is
    begin
      wait until clk'event and clk = '1';
      cacheCs <= '1';
      if req.wrEn = '1' then
        cacheWrite <= '1';
      else
        cacheRead <= '1';
      end if;
      cacheAddr   <= req.addr;
      cacheWrData <= req.wrData;

      if req.concurrentInvalidate = '1' then
        busInvalidate  <= '1';
        invalidateAddr <= req.invAddr;
      end if;

      if req.concurrentFakeInvalidate = '1' then
        busFakeInvalidate <= '1';
        invalidateAddr    <= req.invAddr;
      end if;

      -- this is writing, wait until end of cycle
      wait until clk'event and clk = '1';
      -- request issued
      busInvalidate     <= '0';
      busFakeInvalidate <= '0';
      cacheCs           <= '0';
      cacheRead         <= '0';
      cacheWrite        <= '0';

    end procedure issueReq;

    procedure waitCacheResp (
      busAccessExpected : in std_logic) is
      constant CACHE_TIMEOUT  : integer := 10;
      variable timeoutCounter : integer := 0;
    begin  -- procedure waitCacheResp
      timeoutCounter := 0;
      while (cacheDone = '0' and busReq = '0'
             and timeoutCounter < CACHE_TIMEOUT) loop
        -- read in the middle of the cycle
        wait until clk'event and clk = '0';
        timeoutCounter := timeoutCounter + 1;
      end loop;

      assert timeoutCounter < CACHE_TIMEOUT
        report "Timeout waiting for cache to answer." severity failure;
      if busAccessExpected = '0' then
        assert cacheDone = '1'
          report "Observed a cache miss while expecting a cache hit" severity failure;
      else
        assert busReq = '1'
          report "Observed a cache hit while expecting a cache miss" severity failure;
      end if;
    end procedure waitCacheResp;

    procedure waitReq (
      req : in request_type_t) is
    begin  -- procedure waitReq
      busRdDataAux <= req.rdData;
      waitCacheResp(not req.hitExpected);
      -- something happened
      if cacheDone = '1' then
        -- hit and read: check if data returned match
        if req.hitExpected = '1' and req.wrEn = '0' then
          assert cacheRdData = req.rdData(0)
            report "Data read during cache hit is corrupted" severity failure;
        end if;
      end if;

      if busReq = '1' then
        wait until busSt = WORKING;
        wait until clk'event and clk = '0';
        -- write miss accessing bus == write through
        if req.wrEn = '1' then
          assert busCmd = BUS_WRITE
            report "Expecting to see write, but saw read" severity failure;
          assert req.addr = busAddr
            report "Cache corrupted addr during write through" severity failure;
          assert req.wrData = busData(0)
            report "Cache corrupted data during write through" severity failure;
          wait until busSt = IDLE;
        -- read miss accessing bus == data fetch
        else
          assert busCmd = BUS_READ
            report "Expecting read but got write" severity failure;
          assert req.addr = busAddr
            report "Cache corrupted addr during read" severity failure;
          wait until busSt = IDLE;
        end if;
      end if;
    end procedure waitReq;

    function get_addr (
      tagAddr, blockAddr, wordOffset : integer)
      return word_addr_t is
    begin  -- function get_addr
      return (std_logic_vector(to_unsigned(tagAddr, CACHE_TAG_WIDTH)) &
              std_logic_vector(to_unsigned(blockAddr, BLOCK_ADDR_WIDTH)) &
              std_logic_vector(to_unsigned(wordOffset, WORD_OFFSET_WIDTH)));
    end function get_addr;

    function get_data_word (
      tagAddr, blockAddr, wordOffset : integer;
      writeEn                        : std_logic)
      return data_word_t is
      variable dataAux : data_word_t;
    begin  -- function get_data_word
      dataAux(WORD_ADDR_WIDTH-1 downto 0) := not get_addr(tagAddr, blockAddr,
                                                          wordOffset);
      dataAux(WORD_ADDR_WIDTH)                       := writeEn;
      dataAux(WORD_WIDTH-1 downto WORD_ADDR_WIDTH+1) := (others => '0');

      return dataAux;
    end function get_data_word;

    function get_data_block (
      tagAddr, blockAddr : integer;
      writeEn            : std_logic)
      return data_block_t is
      variable dataAux : data_block_t;
    begin  -- function get_data_block
      dataAux(1) := get_data_word(tagAddr, blockAddr, 1, writeEn);
      dataAux(0) := get_data_word(tagAddr, blockAddr, 0, writeEn);
      return dataAux;
    end function get_data_block;

    variable req : request_type_t;
  begin
    cacheCs           <= '0';
    cacheRead         <= '0';
    cacheWrite        <= '0';
    busCmd            <= (others => 'Z');
    busInvalidate     <= '0';
    busFakeInvalidate <= '0';

    rst                      <= '0';
    wait until clk'event and clk = '1';
    wait until clk'event and clk = '1';
    wait until clk'event and clk = '1';
    rst                      <= '1';
    wait until clk'event and clk = '1';
    wait until clk'event and clk = '1';
    -- first accesses: always misses
    -- num blocks: NUM_BLOCKS
    report "Issuing first accesses, must miss" severity note;
    req.wrData               := (others => '0');
    -- read blocks 0, 1 and 2
    req.hitExpected          := '0';
    req.concurrentInvalidate := '0';
    req.wrEn                 := '0';
    req.addr                 := get_addr(0, 0, 0);
    req.rdData               := get_data_block(0, 0, '0');
    report "Trying to read block 0, must miss in cache" severity note;
    issueReq(req);
    waitReq(req);

    req.addr   := get_addr(0, 1, 0);
    req.rdData := get_data_block(0, 1, '0');
    report "Trying to read block 1, must miss in cache" severity note;
    issueReq(req);
    waitReq(req);

    req.addr   := get_addr(0, 2, 1);
    req.rdData := get_data_block(0, 2, '0');
    report "Trying to read block 2, must miss in cache" severity note;
    issueReq(req);
    waitReq(req);

    -- read block NUM_BLOCKS - miss and bring it to memory (lru logic cleared)
    report "Trying to read block NUM_BLOCKS (block 0, tag 1), must miss in cache" severity note;
    req.hitExpected := '0';
    req.addr        := get_addr(1, 0, 0);
    req.rdData      := get_data_block(1, 0, '0');
    issueReq(req);
    waitReq(req);

    -- test a hit: read block 0, word 1
    report "Trying to read block 0, should hit, block 0 now is LRU" severity note;
    req.hitExpected := '1';
    req.addr        := get_addr(0, 0, 1);
    req.rdData(1)   := get_data_word(0, 0, 0, '0');
    req.rdData(0)   := get_data_word(0, 0, 1, '0');
    issueReq(req);
    waitReq(req);


    -- trigger clean eviction of NUM_BLOCKS: read block 2*NUM_BLOCKS
    report "Trying to read block 2*NUM_BLOCKS (block 0, tag 2), should miss and evict block NUM_BLOCKS" severity note;
    req.hitExpected := '0';
    req.addr        := get_addr(2, 0, 0);
    req.rdData      := get_data_block(2, 0, '0');
    issueReq(req);
    waitReq(req);

    -- test a write through
    -- write block NUM_BLOCKS -- should miss and write through
    report "Trying to write block NUM_BLOCKS (block 0, tag 1), should miss and write through" severity note;
    req.hitExpected := '0';
    req.wrEn        := '1';
    req.addr        := get_addr(1, 0, 0);
    req.rdData      := get_data_block(1, 0, '0');
    issueReq(req);
    waitReq(req);

    -- test if we did not invalidate anything we did not wanted to invalidate
    report "Trying to read block 0, should hit, block 0 now is LRU" severity note;
    req.hitExpected := '1';
    req.wrEn        := '0';
    req.addr        := get_addr(0, 0, 1);
    req.rdData(1)   := get_data_word(0, 0, 0, '0');
    req.rdData(0)   := get_data_word(0, 0, 1, '0');
    issueReq(req);
    waitReq(req);


    report "Trying to read block 2*NUM_BLOCKS, should hit, block 2*NUM_BLOCKS now is LRU" severity note;
    req.hitExpected := '1';
    req.wrEn        := '0';
    req.addr        := get_addr(2, 0, 1);
    req.rdData(1)   := get_data_word(2, 0, 0, '0');
    req.rdData(0)   := get_data_word(2, 0, 1, '0');
    issueReq(req);
    waitReq(req);

    report "Fake invalidation of block 0 (remote read)" severity note;
    issueFakeInvalidate(get_addr(0, 0, 1));

    report "Trying to read block 0, should hit, block 0 now is LRU" severity note;
    req.hitExpected := '1';
    req.wrEn        := '0';
    req.addr        := get_addr(0, 0, 1);
    req.rdData(1)   := get_data_word(0, 0, 0, '0');
    req.rdData(0)   := get_data_word(0, 0, 1, '0');
    issueReq(req);
    waitReq(req);

    report "True invalidation of block 0 (remote write)" severity note;
    issueInvalidate(get_addr(0, 0, 1));

    report "Trying to read block 0, should miss" severity note;
    req.hitExpected := '0';
    req.wrEn        := '0';
    req.addr        := get_addr(0, 0, 1);
    req.rdData(1)   := get_data_word(0, 0, 0, '0');
    req.rdData(0)   := get_data_word(0, 0, 1, '0');
    issueReq(req);
    waitReq(req);

    report "Trying to read block 0, should hit, block 0 now is LRU" severity note;
    req.hitExpected := '1';
    req.wrEn        := '0';
    req.addr        := get_addr(0, 0, 1);
    req.rdData(1)   := get_data_word(0, 0, 1, '0');
    req.rdData(0)   := get_data_word(0, 0, 0, '0');
    issueReq(req);
    waitReq(req);

    report "Trying to read block 0 and invalidate other block at same time it at the same time, should hit" severity note;
    req.hitExpected          := '1';
    req.wrEn                 := '0';
    req.concurrentInvalidate := '1';
    req.invAddr              := get_addr(0, 1, 1);
    req.addr                 := get_addr(0, 0, 1);
    req.rdData(1)            := get_data_word(0, 0, 1, '0');
    req.rdData(0)            := get_data_word(0, 0, 0, '0');
    issueReq(req);
    waitReq(req);

    report "Trying to read block 0 and fake invalidate at same time it at the same time, should hit" severity note;
    req.hitExpected              := '1';
    req.wrEn                     := '0';
    req.concurrentInvalidate     := '0';
    req.concurrentFakeInvalidate := '1';
    req.invAddr                  := get_addr(0, 0, 1);
    req.addr                     := get_addr(0, 0, 1);
    req.rdData(1)                := get_data_word(0, 0, 1, '0');
    req.rdData(0)                := get_data_word(0, 0, 0, '0');
    issueReq(req);
    waitReq(req);

    report "Trying to write block 0, should miss (write miss)" severity note;
    req.hitExpected              := '0';
    req.wrEn                     := '1';
    req.concurrentInvalidate     := '0';
    req.concurrentFakeInvalidate := '1';
    req.invAddr                  := get_addr(0, 0, 1);
    req.addr                     := get_addr(0, 0, 1);
    req.rdData(1)                := get_data_word(0, 0, 1, '0');
    req.rdData(0)                := get_data_word(0, 0, 0, '0');
    issueReq(req);
    waitReq(req);
    
    report "Trying to read block 0 and invalidate it at the same time, should miss" severity note;
    req.hitExpected              := '0';
    req.wrEn                     := '0';
    req.concurrentInvalidate     := '1';
    req.concurrentFakeInvalidate := '0';
    req.invAddr                  := get_addr(0, 0, 0);
    req.addr                     := get_addr(0, 0, 1);
    req.rdData(1)                := get_data_word(0, 0, 0, '0');
    req.rdData(0)                := get_data_word(0, 0, 1, '0');
    issueReq(req);
    waitReq(req);


    -- we tested all mechanisms, the controller is ready for integration
    assert false
      report "simulation ended"
      severity failure;

  end process;

  CacheController_1 : entity work.CacheController
    port map (
      clk           => clk,
      rst           => rst,
      cacheCs       => cacheCs,
      cacheRead     => cacheRead,
      cacheWrite    => cacheWrite,
      cacheAddr     => cacheAddr,
      cacheWrData   => cacheWrData,
      cacheDone     => cacheDone,
      cacheRdData   => cacheRdData,
      busReq        => busReq,
      busCmd        => busCmd,
      busGrant      => busGrant,
      busSnoopValid => busSnoopValid,
      busAddr       => busAddr,
      busData       => busData);

end architecture test;
