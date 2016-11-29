library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mem_types.all;
use work.soc_components.all;

entity bus_controller_tb is
end entity bus_controller_tb;

architecture test of bus_controller_tb is
  constant CLK_PERIOD : time := 40 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '0';

  signal busReq                                 : std_logic_vector(N_CACHES-1 downto 0);
  signal busSnoopValid : std_logic;
  signal busAddr                                : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal busCmd                                 : bus_cmd_t;
  signal busData                                : data_block_t;
  signal busGrant                               : std_logic_vector(N_CACHES-1 downto 0);
  signal memCs, memRead, memWrite, memWriteWord : std_logic;
  signal memWrData                              : data_block_t;
  signal memRdData                              : data_block_t;
  signal memDone                                : std_logic;
  signal memAddr                                : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);

  type cmd_state_t is (PENDING, GRANTED, WAITING_COMPLETION, IDLE);
  type cache_cmd_t is record
    cmd    : bus_cmd_t;
    addr   : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    rdData : data_block_t;
    wrData : data_block_t;
    state  : cmd_state_t;
  end record cache_cmd_t;

  type cache_cmd_array_t is array (0 to N_CACHES) of cache_cmd_t;
  signal cacheCmd : cache_cmd_array_t;


  function decodeCmd (
    ramRead, ramWrite, ramWriteWord : std_logic)
    return bus_cmd_t is
  begin  -- function decodeCmd
    if ramRead = '1' then
      return BUS_READ;
    else
      return BUS_WRITE;
    end if;

    assert false report "Error: tb detected malformed command from bus controller" severity failure;
    return (others => 'Z');

  end function decodeCmd;

  function nextCmd (
    currCmd : bus_cmd_t)
    return bus_cmd_t is
  begin
    case currCmd is
      when BUS_READ       => return BUS_WRITE;
      when BUS_WRITE      => return BUS_READ;
      when others         => return (others => 'Z');
    end case;
  end function nextCmd;


begin  -- architecture test

  DUT : entity work.BusController
    port map (
      clk           => clk,
      rst           => rst,
      busReq        => busReq,
      busAddr       => busAddr,
      busCmd        => busCmd,
      busData       => busData,
      busGrant      => busGrant,
      busSnoopValid => busSnoopValid,
      memCs         => memCs,
      memRead       => memRead,
      memWrite      => memWrite,
      memWriteWord  => memWriteWord,
      memWrData     => memWrData,
      memRdData     => memRdData,
      memDone       => memDone,
      memAddr       => memAddr);
  -- clk generator process
  process
  begin
    clk <= not clk;
    wait for CLK_PERIOD/2;
  end process;

  -- models combinaional logic
  process(busGrant, busReq, cacheCmd)
    variable grantedCache : integer;
    variable granted      : std_logic;
  begin
    granted      := '0';
    grantedCache := 0;
    for i in 0 to N_CACHES-1 loop
      if busGrant(i) = '1' and busReq(i) = '1' then
        granted      := '1';
        grantedCache := i;

      end if;

      if granted = '1' then
        busCmd  <= cacheCmd(grantedCache).cmd;
        busAddr <= cacheCmd(grantedCache).addr;
        busData <= cacheCmd(grantedCache).wrData;
      else
        busCmd  <= (others => 'Z');
        busAddr <= (others => 'Z');
        busData <= DATA_BLOCK_HIGH_IMPEDANCE;

      end if;
    end loop;  -- i
  end process;

  -- drives the requests
  process
    variable currAddr : unsigned(WORD_ADDR_WIDTH-1 downto 0);
    variable currData : unsigned(WORD_WIDTH-1 downto 0);
    variable currCmd  : bus_cmd_t;

    variable cacheGranted : integer;

    procedure issueReq (
      cacheId         :     integer;
      signal cacheCmd : out cache_cmd_array_t) is
    begin  -- procedure issueReq
      cacheCmd(cacheId).state     <= PENDING;
      cacheCmd(cacheId).cmd       <= currCmd;
      cacheCmd(cacheId).addr      <= std_logic_vector(currAddr);
      cacheCmd(cacheId).wrData(0) <= std_logic_vector(currData);
      cacheCmd(cacheId).wrData(1) <= std_logic_vector(currData);
      currAddr                    := currAddr + 1;
      currData                    := currData + 1;
      currCmd                     := nextCmd(currCmd);
    end procedure issueReq;


    procedure waitGrant (
      variable cacheGranted : out   integer;
      signal cacheCmd       : inout cache_cmd_array_t) is
      variable busGranted     : std_logic;
      constant CACHE_TIMEOUT  : integer := 10;
      variable timeoutCounter : integer := 0;

    begin  -- procedure waitGrant
      busGranted := '0';
      while busGranted = '0' and timeoutCounter < CACHE_TIMEOUT loop
        for i in 0 to N_CACHES-1 loop
          -- keep bus req up
          if cacheCmd(i).state = PENDING then
            busReq(i) <= '1';
          else
            busReq(i) <= '0';
          end if;
          -- check for grants
          if busGrant(i) = '1' then
            busGranted := '1';
            -- got grant, issue request
            cacheGranted := i;
            assert busSnoopValid = '1' report "Grant raised, but we busSnoopValid not raised" severity failure;
            assert cacheCmd(i).state = PENDING
              report "Bus was granted to a cache that was not requesting it" severity failure;
            cacheCmd(i).state <= GRANTED;
          end if;
        end loop;  -- i

        if busGranted = '0' then
          wait until clk'event and clk = '0';

        end if;
        timeoutCounter := timeoutCounter + 1;
      end loop;

      assert timeoutCounter < CACHE_TIMEOUT
        report "Timeout waiting for bus to answer." severity failure;

    end procedure waitGrant;


    -- purpose: Issues a bus transaction
    procedure sendBusTransaction (
      cacheId         :     natural;
      signal cacheCmd : out cache_cmd_array_t) is
      constant CACHE_TIMEOUT  : integer := 30;
      variable timeoutCounter : integer := 0;
      variable busDone        : std_logic;

    begin  -- procedure sendBusTransaction
      busDone := '0';
      wait until clk'event and clk = '0';

      cacheCmd(cacheId).state <= WAITING_COMPLETION;
      busReq(cacheId)         <= '0';

      while busDone = '0' and timeoutCounter < CACHE_TIMEOUT loop
        for i in 0 to N_CACHES-1 loop
          if i = cacheId then
            if busGrant(i) = '0' then
              cacheCmd(cacheId).state <= IDLE;
              busDone                 := '1';
            end if;
          else
            assert busGrant(i) = '0'
              report "Bus is granting to two simultaneous caches. Giving up" severity failure;
          end if;
        end loop;  -- i

        if busDone = '0' then
          wait until clk'event and clk = '0';
        end if;
        timeoutCounter := timeoutCounter + 1;

      end loop;

    end procedure sendBusTransaction;

  begin
    rst    <= '0';
    busReq <= (others => '0');

    currAddr     := (others => '0');
    currData     := to_unsigned(1000, currData'length);
    currCmd      := BUS_READ;
    cacheGranted := 0;
    for i in 0 to N_CACHES-1 loop
      cacheCmd(i).state <= IDLE;
    end loop;

    wait for CLK_PERIOD;
    wait for CLK_PERIOD;
    wait for CLK_PERIOD;
    rst <= '1';

    wait for CLK_PERIOD;
    wait for CLK_PERIOD;
    wait for CLK_PERIOD;

    -- issue from cache 0
    report "Issuing request from cache 0" severity note;
    issueReq(0, cacheCmd);
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 0
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);
    -- issue from cache 1
    report "Issuing request from cache 1" severity note;
    issueReq(1, cacheCmd);
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 1
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);

    -- issue 2 concurrent requests
    report "Issuing 2 concurrent requests, cache 0 should be serviced first" severity note;
    issueReq(0, cacheCmd);
    issueReq(1, cacheCmd);

    -- last issued was 1, 0 should get priority
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 0
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);

    report "Saw grant to cache 0, waiting for cache 1 to be serviced" severity note;
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 1
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);


    -- issue from cache 0
    report "Issuing request from cache 0" severity note;
    issueReq(0, cacheCmd);
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 0
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);

    -- issue 2 concurrent requests
    report "Issuing 2 concurrent requests, cache 1 should be serviced first" severity note;
    issueReq(1, cacheCmd);
    issueReq(0, cacheCmd);

    -- last issued was 0, 1 should get priority
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 1
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);

    report "Saw grant to cache 1, waiting for cache 0 to be serviced" severity note;
    waitGrant(cacheGranted, cacheCmd);
    assert cacheGranted = 0
      report "Wrong cache granted, giving up" severity failure;
    sendBusTransaction(cacheGranted, cacheCmd);


    assert false
      report "simulation ended - everything probably went well"
      severity failure;
  end process;

  -- ram sim
  process
    constant waitCycles     : integer                              := 10;
    variable cycleCount     : integer                              := 0;
    variable lastSeenAddr   : unsigned(WORD_ADDR_WIDTH-1 downto 0) := (others => '0');
    variable lastSeenCmd    : bus_cmd_t                            := BUS_READ;
    variable lastSentRdData : unsigned(WORD_WIDTH-1 downto 0)      := (others => '0');
    variable lastSeenWrData : unsigned(WORD_WIDTH-1 downto 0)      := to_unsigned(1000, WORD_WIDTH);

    variable seenCmd : bus_cmd_t;
  begin

    memDone <= '0';
    while true loop

      if memCs = '1' then
        seenCmd := decodeCmd(memRead, memWrite, memWriteWord);
        assert lastSeenAddr = unsigned(memAddr) report "Bad addr from bus" severity failure;
        assert lastSeenCmd = seenCmd report "Bad cmd from bus" severity failure;
        assert lastSeenWrData = unsigned(memWrData(0)) report "Bad data from bus" severity failure;
        while cycleCount /= waitCycles loop
          wait until clk'event and clk = '0';
          cycleCount := cycleCount + 1;
        end loop;
        cycleCount     := 0;
        lastSeenAddr   := lastSeenAddr + 1;
        lastSeenWrData := lastSeenWrData + 1;
        lastSeenCmd    := nextCmd(seenCmd);
        memDone        <= '1';
        memRdData(0)   <= std_logic_vector(lastSentRdData);
        memRdData(1)   <= std_logic_vector(lastSentRdData);
        wait until clk'event and clk = '0';
        memDone        <= '0';
      else
        wait until clk'event and clk = '0';
      end if;

    end loop;

  end process;

end architecture test;
