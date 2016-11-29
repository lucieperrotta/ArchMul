library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;
use work.mem_components.all;

entity CacheController is

  port (
    clk, rst                       : in    std_logic;
    cacheCs, cacheRead, cacheWrite : in    std_logic;
    cacheAddr                      : in    std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    cacheWrData                    : in    data_word_t;
    cacheDone                      : out   std_logic;
    cacheRdData                    : out   data_word_t;
    busReq                         : out   std_logic;
    busCmd                         : out   bus_cmd_t;
    busGrant                       : in    std_logic;
    busAddr                        : out   std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    busData                        : inout data_block_t);
end entity CacheController;

architecture rtl of CacheController is
  type cpu_req_reg_t is record
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    data : data_word_t;
  end record cpu_req_reg_t;

  signal cpuReqRegWrEn : std_logic;
  signal cpuReqReg     : cpu_req_reg_t;
  signal cpuReqRegWord : std_logic_vector(WORD_OFFSET_WIDTH-1 downto 0);

  type victim_reg_t is record
    set   : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
    dirty : std_logic;
    addr  : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    data  : data_block_t;
  end record victim_reg_t;
  signal victimRegWrEn : std_logic;
  signal victimReg     : victim_reg_t;

  type cache_ctrl_state_t is (ST_IDLE, ST_RD_HIT_TEST, ST_RD_WAIT_BUS_GRANT_ACC,
                              ST_RD_WAIT_BUS_COMPLETE_ACC, ST_RD_WAIT_BUS_GRANT_WB,
                              ST_RD_WAIT_BUS_COMPLETE_WB,
                              ST_WR_HIT_TEST, ST_WR_WAIT_BUS_GRANT, ST_WR_WAIT_BUS_COMPLETE);

  signal cacheStNext, cacheSt                : cache_ctrl_state_t := ST_IDLE;
  -- tag Array
  signal tagLookupEn, tagWrEn, tagWrSetDirty : std_logic;
  signal tagWrSet                            : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal tagAddr                             : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal tagHitEn, tagVictimDirty            : std_logic;
  signal tagHitSet, tagVictimSet             : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal tagVictimAddr                       : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  -- data array
  signal dataArrayWrEn, dataArrayWrWord      : std_logic;
  signal dataArrayWrSetIdx                   : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal dataArrayAddr                       : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal dataArrayWrData                     : data_block_t;
  signal dataArrayRdData                     : data_set_t;

  -- bus tri state buffer
  signal busOutEn  : std_logic;
  signal busAddrIn : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal busCmdIn  : bus_cmd_t;
  signal busDataIn : data_block_t;
-- 
begin  -- architecture rtl

  comb_proc : process (busAddrIn, busCmdIn, busData, busDataIn, busGrant,
                       busOutEn, cacheAddr, cacheCs, cacheRead, cacheSt,
                       cacheWrite, cpuReqReg, cpuReqRegWord,
                       dataArrayRdData, tagHitEn, tagHitSet,
                       tagVictimSet, victimReg) is
  begin  -- process comb_proc
    -- signals that need initialization
    cacheStNext <= cacheSt;
    cacheDone   <= '0';

    cpuReqRegWrEn <= '0';
    victimRegWrEn <= '0';

    tagLookupEn   <= '0';
    tagWrEn       <= '0';
    tagWrSetDirty <= '0';

    dataArrayWrEn   <= '0';
    dataArrayWrWord <= '0';

    busReq   <= '0';
    busOutEn <= '0';


    -- signals with dont care initialization
    cacheRdData   <= (others => 'Z');
    dataArrayAddr <= cacheAddr;

    busCmdIn  <= BUS_READ;
    busAddrIn <= cpuReqReg.addr;
    busDataIn <= victimReg.data;

    tagWrSet <= victimReg.set;
    tagAddr  <= cpuReqReg.addr;

    dataArrayWrData   <= busData;
    dataArrayAddr     <= cpuReqReg.addr;
    dataArrayWrSetIdx <= tagVictimSet;

    -- control: state machine
    case cacheSt is
      when ST_IDLE =>
        if cacheCs = '1' then
          cpuReqRegWrEn <= '1';
          tagLookupEn   <= '1';
          tagAddr <= cacheAddr;
          dataArrayAddr <= cacheAddr;
        end if;

        if cacheCs = '1' and cacheRead = '1' then
          cacheStNext <= ST_RD_HIT_TEST;
        elsif cacheCs = '1' and cacheWrite = '1' then
          cacheStNext <= ST_WR_HIT_TEST;
        end if;

      -----------------------------------------------------------------------
      -- rd state machine
      -----------------------------------------------------------------------
      when ST_RD_HIT_TEST =>
        if tagHitEn = '1' then
          cacheStNext <= ST_IDLE;
          cacheDone   <= '1';
          cacheRdData <= dataArrayRdData(to_integer(unsigned(tagHitSet)))(to_integer(unsigned(cpuReqRegWord)));
        else
          victimRegWrEn <= '1';
          cacheStNext   <= ST_RD_WAIT_BUS_GRANT_ACC;
        end if;

      when ST_RD_WAIT_BUS_GRANT_ACC =>
        busReq <= '1';
        -- we got the bus
        if busGrant = '1' then
          busOutEn    <= '1';
          busCmdIn    <= BUS_READ;
          busAddrIn   <= cpuReqReg.addr;
          cacheStNext <= ST_RD_WAIT_BUS_COMPLETE_ACC;
        end if;

      when ST_RD_WAIT_BUS_COMPLETE_ACC =>
        -- request is done, bus data has our data
        -- write tags and data
        if busGrant = '0' then
          tagWrEn         <= '1';
          tagWrSet        <= victimReg.set;
          tagWrSetDirty   <= '0';
          tagAddr         <= cpuReqReg.addr;
          dataArrayWrEn   <= '1';
          dataArrayWrWord <= '0';
          dataArrayWrData <= busData;
          dataArrayAddr   <= cpuReqReg.addr;
          -- chose the next state
          if victimReg.dirty = '1' then
            cacheStNext <= ST_RD_WAIT_BUS_GRANT_WB;
          else
            cacheStNext <= ST_IDLE;
            cacheRdData <= busData(to_integer(unsigned(cpuReqRegWord)));
            cacheDone   <= '1';
          end if;
        end if;

      when ST_RD_WAIT_BUS_GRANT_WB =>
        busReq        <= '1';
        dataArrayAddr <= cpuReqReg.addr;
        -- we got the bus
        if busGrant = '1' then
          cacheStNext <= ST_RD_WAIT_BUS_COMPLETE_WB;
          busOutEn    <= '1';
          busCmdIn    <= BUS_WRITE;
          busAddrIn   <= victimReg.addr;
          busDataIn   <= victimReg.data;
        end if;

      when ST_RD_WAIT_BUS_COMPLETE_WB =>
        if busGrant = '0' then
          cacheStNext <= ST_IDLE;
          cacheDone   <= '1';
          cacheRdData <= dataArrayRdData(to_integer(unsigned(victimReg.set)))(to_integer(unsigned(cpuReqRegWord)));
        end if;

      -----------------------------------------------------------------------
      -- wr state machine
      -----------------------------------------------------------------------
      when ST_WR_HIT_TEST =>
        if tagHitEn = '1' then
          cacheStNext        <= ST_IDLE;
          cacheDone          <= '1';
          -- write the tag array
          tagWrEn            <= '1';
          tagWrSet           <= tagHitSet;
          tagWrSetDirty      <= '1';
          tagAddr            <= cpuReqReg.addr;
          -- write the data array
          dataArrayWrEn      <= '1';
          dataArrayWrWord    <= '1';
          dataArrayWrSetIdx  <= tagHitSet;
          dataArrayWrData(0) <= cpuReqReg.data;
        else
          cacheStNext <= ST_WR_WAIT_BUS_GRANT;
        end if;

      when ST_WR_WAIT_BUS_GRANT =>
        busReq <= '1';
        if busGrant = '1' then
          cacheStNext  <= ST_WR_WAIT_BUS_COMPLETE;
          busOutEn     <= '1';
          busCmdIn     <= BUS_WRITE_WORD;
          busAddrIn    <= cpuReqReg.addr;
          busDataIn(0) <= cpuReqReg.data;
        end if;

      when ST_WR_WAIT_BUS_COMPLETE =>
        if busGrant = '0' then
          cacheDone   <= '1';
          cacheStNext <= ST_IDLE;
        end if;

      when others => null;
    end case;

    -- datapath:
    if busOutEn = '1' then
      busCmd  <= busCmdIn;
      busAddr <= busAddrIn;
      busData <= busDataIn;
    else
      busCmd  <= (others => 'Z');
      busAddr <= (others => 'Z');
      busData <= DATA_BLOCK_HIGH_IMPEDANCE;
    end if;

    cpuReqRegWord <= std_logic_vector(to_unsigned(getWordOffset(cpuReqReg.addr), cpuReqRegWord'length));

  end process comb_proc;

  TagArray_1 : TagArray
    port map (
      clk            => clk,
      rst            => rst,
      tagLookupEn    => tagLookupEn,
      tagWrEn        => tagWrEn,
      tagWrSetDirty  => tagWrSetDirty,
      tagWrSet       => tagWrSet,
      tagAddr        => tagAddr,
      tagHitEn       => tagHitEn,
      tagHitSet      => tagHitSet,
      tagVictimSet   => tagVictimSet,
      tagVictimDirty => tagVictimDirty,
      tagVictimAddr  => tagVictimAddr);

  DataArray_1 : DataArray
    port map (
      clk               => clk,
      dataArrayWrEn     => dataArrayWrEn,
      dataArrayWrWord   => dataArrayWrWord,
      dataArrayWrSetIdx => dataArrayWrSetIdx,
      dataArrayAddr     => dataArrayAddr,
      dataArrayWrData   => dataArrayWrData,
      dataArrayRdData   => dataArrayRdData);

  clk_proc : process (clk, rst) is
  begin  -- process clk_proc
    if rst = '0' then                   -- asynchronous reset (active low)
      cacheSt <= ST_IDLE;
    elsif clk'event and clk = '1' then  -- rising clock edge
      cacheSt <= cacheStNext;

      if cpuReqRegWrEn = '1' then
        cpuReqReg.addr <= cacheAddr;
        cpuReqReg.data <= cacheWrData;
      end if;

      if victimRegWrEn = '1' then
        victimReg.set   <= tagVictimSet;
        victimReg.dirty <= tagVictimDirty;
        victimReg.addr  <= tagVictimAddr;
        victimReg.data  <= dataArrayRdData(to_integer(unsigned(tagVictimSet)));
      end if;
    end if;
  end process clk_proc;

end architecture rtl;
