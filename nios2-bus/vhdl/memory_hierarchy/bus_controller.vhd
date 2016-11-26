library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;
use work.mem_components.all;

entity BusController is

  port (
    clk, rst                               : in    std_logic;
    busReq                                 : in    std_logic_vector(N_CACHES-1 downto 0);
    busAddr                                : in    std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    busCmd                                 : in    bus_cmd_t;
    busData                                : inout data_block_t;
    busGrant                               : out   std_logic_vector(N_CACHES-1 downto 0);
    memCs, memRead, memWrite, memWriteWord : out   std_logic;
    memAddr                                : out   std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    memWrData                              : out   data_block_t;
    memRdData                              : in    data_block_t;
    memDone                                : in    std_logic);

end entity BusController;

architecture rtl of BusController is
  -- tri state buffer
  signal busOutEn : std_logic;

  signal reqValid         : std_logic;
  type bus_state_t is (ST_IDLE, ST_GRANT, ST_WAIT_MEM);
  signal busSt, busStNext : bus_state_t := ST_IDLE;

  signal arbiterArbitrate : std_logic;
  signal arbiterReqValid  : std_logic;
  signal arbiterReqId     : std_logic_vector(CACHE_IDX_WIDTH-1 downto 0);
begin  -- architecture rtl

  comb_proc : process (arbiterReqId, arbiterReqValid, busAddr, busCmd,
                       busOutEn, busSt, memDone, memRdData) is
    variable priorityReq : integer;
  begin  -- process comb_proc
    -- signals that need initialization
    busStNext        <= busSt;
    busGrant         <= (others => '0');
    arbiterArbitrate <= '0';
    busOutEn         <= '0';
    memCs            <= '0';

    -- signal with dont care initialization

    -- control: state machine
    case busSt is
      when ST_IDLE =>
        if arbiterReqValid = '1' then
          busStNext <= ST_GRANT;
        end if;
      when ST_GRANT =>
        memCs                                        <= '1';
        arbiterArbitrate                             <= '1';
        busGrant(to_integer(unsigned(arbiterReqId))) <= '1';
        busStNext                                    <= ST_WAIT_MEM;
      when ST_WAIT_MEM =>
        if memDone = '1' then
          busStNext <= ST_IDLE;
          busOutEn  <= '1';
        else
          busGrant(to_integer(unsigned(arbiterReqId))) <= '1';
        end if;
      when others => null;
    end case;

    -- datapath
    -- decoder
    memRead      <= '0';
    memWrite     <= '0';
    memWriteWord <= '0';

    case busCmd is
      when BUS_READ =>
        memRead      <= '1';
        memWrite     <= '0';
        memWriteWord <= '0';
      when BUS_WRITE =>
        memRead      <= '0';
        memWrite     <= '1';
        memWriteWord <= '0';
      when BUS_WRITE_WORD =>
        memRead      <= '0';
        memWrite     <= '1';
        memWriteWord <= '1';
      when others => null;
    end case;

    -- tri state buffer
    if busOutEn = '1' then
      busData <= memRdData;
    else
      busData <= DATA_BLOCK_HIGH_IMPEDANCE;
    end if;

    memAddr   <= busAddr;
    memWrData <= busData;
  end process comb_proc;

  busArbiter_1 : busArbiter
    port map (
      clk              => clk,
      arbiterArbitrate => arbiterArbitrate,
      arbiterBusReqIn  => busReq,
      arbiterReqValid  => arbiterReqValid,
      arbiterReqId     => arbiterReqId);

  clk_proc : process (clk, rst) is
  begin  -- process clk_proc
    if rst = '0' then                   -- asynchronous reset (active low)
      busSt <= ST_IDLE;
    elsif clk'event and clk = '1' then  -- rising clock edge
      busSt <= busStNext;
    end if;
  end process clk_proc;

end architecture rtl;
