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
  type cache_ctrl_state_t is (ST_IDLE, ST_RD_HIT_TEST, ST_RD_WAIT_BUS_GRANT_ACC,
                              ST_RD_WAIT_BUS_COMPLETE_ACC, ST_RD_WAIT_BUS_GRANT_WB,
                              ST_RD_WAIT_BUS_COMPLETE_WB,
                              ST_WR_HIT_TEST, ST_WR_WAIT_BUS_GRANT, ST_WR_WAIT_BUS_COMPLETE);

  signal cacheStNext, cacheSt                : cache_ctrl_state_t := ST_IDLE;

  signal tagLookupEn, tagWrEn, tagWrSetDirty : std_logic;
  signal tagWrSet                            : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal tagAddr                             : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal tagHitEn, tagVictimDirty            : std_logic;
  signal tagHitSet, tagVictimSet             : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal tagVictimAddr                       : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);

  signal dataArrayWrEn, dataArrayWrWord : std_logic;
  signal dataArrayWrSetIdx              : std_logic_vector(WORD_OFFSET_WIDTH-1 downto 0);
  signal dataArrayAddr                  : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal dataArrayWrData                : data_block_t;
  signal dataArrayRdData                : data_set_t;
  
begin  -- architecture rtl

  comb_proc : process () is
  begin  -- process comb_proc
    -- signals that need initialization
    cacheStNext <= cacheSt;

    -- signals with dont care initialization

    -- control: state machine
    case cacheSt is
      when ST_IDLE =>
	if cacheCs = '1' then
	  cpuReqRegWrEn <= '1'; -- ?????? what is that signal
	  dataArrayAddr <= cacheAddr; -- not sure how to copy arrays
	  tagAddr <= cacheAddr;
	  tagLookupEn <= '1';
	  if cacheWrite = '1' then
		cacheSt <= ST_WR_HIT_TEST;
	  elsif cacheRead = '1' then
		cacheSt <= ST_RD_HIT_TEST;
	  end if;
      end if;
      -----------------------------------------------------------------------
      -- rd state machine
      -----------------------------------------------------------------------
      when ST_RD_HIT_TEST =>
	if tagHitEn = '1' then
		cacheRdOutEn<='1';
		cacheRdData<=dataArrayRdData;
		[tagHitSet][cpuReqReg] -- what is this line ?
		cacheDone <= '1';
		cacheSt <= ST_IDLE;
	else	victimRegWrEn<='1';
		cacheSt <= ST_RD_WAIT_BUS_GRANT_ACC;

      when ST_RD_WAIT_BUS_GRANT_ACC =>
	if busGrant = '1' then
		busReq<='1';
		busOutEn<='1';
		busCmd<= BUS_READ;
		busAddrIn<=cpuReqRegAddr;
		cacheSt <= ST_RD_WAIT_BUS_COMPLETE_ACC;
	else	busReq<='1';

      when ST_RD_WAIT_BUS_COMPLETE_ACC =>
	if busGrant != '1' then
		if tagVictimDirty = '1' then
			-- writing cache block
			tagWrEn<='1';
			tagWrSet<=victimSet;
			tagWrDirty<='0';
			tagAddr<=cpuReqRegAddr;
			dataArrayWrEn<='1';
			dataArrayWrSetIdx <=victimSet;
			dataArrayWrWord<='0';
			dataArrayData<=busData;
			cacheSt <= ST_RD_WAIT_BUS_GRANT_WB;
		
		else 	cacheRdData<=busDataWord;
			cacheRdOutEn<='1';
			[cpuReqRegWord] -- ???
			cacheDone<='1';
			-- writing cache block
			tagWrEn<='1';
			tagWrSet<=victimSet;
			tagWrDirty<='0';
			tagAddr<=cpuReqRegAddr;
			dataArrayWrEn<='1';
			dataArrayWrSetIdx<=victimSet;
			dataArrayWrWord<='0';
			dataArrayData<=busData;
			cacheSt <= ST_IDLE;
		end if;
	end if;

      when ST_RD_WAIT_BUS_GRANT_WB =>
	if busGrant = '1' then
		busReq<='1';
		busOutEn<='1';
		busCmdIn<=BUS_WRITE;
		busAddrIn<=victimRegAddr;
		busDataIn<=victimRegData;
		cacheSt <= ST_RD_WAIT_BUS_GRANT COMPLETE;
	else busReq<='1';
	end if;

      when ST_RD_WAIT_BUS_GRANT COMPLETE =>
	if busGrant = '1' =>
		dataArrayAddr<=cpuReqRegAddr;
	else 	cacheRdData<=dataArrayRdData[tagHitSet][cpuReqRegWord];
		cacheDone<='1';
		cacheSt <= ST_IDLE;
	end if;

      -----------------------------------------------------------------------
      -- wr state machine
      -----------------------------------------------------------------------
      when ST_WR_HIT_TEST =>
	if tagHitEn = '1' then
		cacheDone<='1';
		tagWrEn<='1';
		tagWrSet<=tagHitSet;
		tagWrDirty<='1';
		tagAddr<=cpuReqRegAddr;
		dataArrayWrEn<='1';
		dataArrayWrWord<='1';
		dataArrayWrSetIdx<=tagHitSet;
		dataArrayWrData<=cpuReqRegData;
		cacheSt <= ST_IDLE;
	else cacheSt <= ST_WR_WAIT_BUS_GRANT;
	end if;

      when ST_WR_WAIT_BUS_GRANT =>
	if busGrant = '1' then
		busReq<='1';
		busOutEn<='1';
		busCmd<=BUS_WRITE_WORD;
		busAddrIn<=cpuRegReqAddr;
		busDataIn<=cpuReqRegData;
		cacheSt <= ST_WR_WAIT_BUS_COMPLETE;
	else busReq <= '1';
	end if;

      when ST_WR_WAIT_BUS_COMPLETE =>
	if busGrant != '1' then
		cacheDone <= '1';
		cacheSt <= ST_IDLE;
	end if;

      when others => null;
    end case;

    -- datapath:

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

      -- there should be more stuff here
  end process clk_proc;

end architecture rtl;