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

  -- READ DATA tri state buffer
  signal busDataWord			: data_word_t;

  -- BUS tri state buffer
  signal cpuReqRegWrEn 			: std_logic;
  signal victimRegWrEn 			: std_logic;
  signal busOutEn 				: std_logic;
  signal cacheRdOutEn 			: std_logic;

  -- victimReg
  signal victimRegDirty 		: std_logic;
  signal victimRegAddr 			: std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal victimRegSet 			: std_logic;

  -- cpuRegReq
  signal cpuReqRegWord 			: std_logic;
  signal cpuReqRegAddr 			: std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal cpuReqRegData 			: data_block_t;  


begin  -- architecture rtl

  comb_proc : process () is
   begin  -- process comb_proc
    -- signals that need initialization
    cacheStNext <= cacheSt;
	-- Default values (internal flags):
	tagLookupEn <= 0;
	tagWrEn <= 0;
	tagWrSetDirty <= 0;
	dataArrayWrEn <= 0;
	dataArrayWrWord <= 0;
	
	-- Default values (outputs):
	cacheDone <= 0;
	busReq <= 0;

	-- Tri State Buffer READ DATA Default Outputs ( cacheRdOutEn <= '0' )
	cacheRdData <= (others => 'Z'); 

	-- Tri State Buffer BUS Default Outputs ( busOutEn <= '0' )
	busCmd <= (others => 'Z'); 
	busAddr <= (others => 'Z'); 
	busData <= (others => 'Z'); 

	-- cpuRegReq
	cpuReqRegWrEn <= '0';
	
 	-- victimReg
	victimRegWrEn <= '0';
	victimRegAddr <= '0';
	victimRegData <= '0';


    -- signals with dont care initialization

    -- control: state machine
    case cacheSt is
      when ST_IDLE =>
	if cacheCs = '1' then
	  cpuReqRegWrEn <= '1';
	  dataArrayAddr <= cacheAddr; -- not sure how to copy arrays
	  tagAddr <= cacheAddr;
	  tagLookupEn <= '1';
	  if cacheWrite = '1' then
		cacheStNext <= ST_WR_HIT_TEST;
	  elsif cacheRead = '1' then
		cacheStNext <= ST_RD_HIT_TEST;
	  end if;
    end if;
      -----------------------------------------------------------------------
      -- rd state machine
      -----------------------------------------------------------------------
      when ST_RD_HIT_TEST =>
	if tagHitEn = '1' then
		cacheDone <= '1';

		--TRI STATE READ DATA (cacheRdOutEn <= '1' )
		cacheRdOutEn <= '1';
		cacheRdData <= dataArrayRdData(tagHitSet)(to_integer(unsigned(cpuReqRegWord)));
		
		cacheStNext <= ST_IDLE;
	else
		victimRegWrEn <= '1';
		cacheStNext <= ST_RD_WAIT_BUS_GRANT_ACC;
	end if;

      when ST_RD_WAIT_BUS_GRANT_ACC =>
	if busGrant = '1' then
		busReq <= '1';

		--TRI STATE BUS ( busOutEn <= '1' )
		busAddr <= cpuReqRegAddr;
		busOutEn <= '1'; 

		busCmd <= BUS_READ;		
		cacheStNext <= ST_RD_WAIT_BUS_COMPLETE_ACC;
	else
		busReq <= '1';
	end if;

      when ST_RD_WAIT_BUS_COMPLETE_ACC =>
	if busGrant != '1' then
		if victimRegDirty = '1' then
			-- writing cache block
			tagWrEn <= '1';
			tagWrSet <= victimSet;
			tagWrSetDirty <= '0';
			tagAddr <= cpuReqRegAddr;
			dataArrayWrEn <= '1';
			dataArrayWrSetIdx <= victimSet;
			dataArrayWrWord <= '0';
			dataArrayData <= busData;
			
			cacheStNext <= ST_RD_WAIT_BUS_GRANT_WB;
		
		else
			cacheDone <= '1';

 			-- TRI STATE READ DATA (cacheRdOutEn <= '1')
			cacheRdData <= busDataWord;
			cacheRdOutEn <= '1';
			

			-- writing cache block
			tagWrEn <= '1';
			tagWrSet <= victimSet;
			tagWrSetDirty <= '0';
			tagAddr <= cpuReqRegAddr;
			dataArrayWrEn <= '1';
			dataArrayWrSetIdx <= victimSet;
			dataArrayWrWord <= '0';
			dataArrayData <= busData;
			
			cacheStNext <= ST_IDLE;
		end if;
	end if;

      when ST_RD_WAIT_BUS_GRANT_WB =>
	if busGrant = '1' then
		busReq <= '1';

		--TRI STATE BUS ( busOutEn <= '1' )
		busOutEn <= '1';
		busCmd <= BUS_WRITE;
		busAddr <= victimRegAddr;
		busData <= victimRegData;
		
		cacheStNext <= ST_RD_WAIT_BUS_GRANT COMPLETE;
	else
		busReq <= '1';
	end if;

      when ST_RD_WAIT_BUS_GRANT COMPLETE =>
	if busGrant = '1' then
		dataArrayAddr <= cpuReqRegAddr;
	else 
		cacheDone <= '1';

		-- TRI STATE READ DATA (cacheRdOutEn <= '1')
		cacheRdOutEn <= '1'; 
		cacheRdData <= rrayRdData(tagHitSet)(to_integer(unsigned(cpuReqRegWord)));
		
		cacheStNext <= ST_IDLE;
	end if;

      -----------------------------------------------------------------------
      -- wr state machine
      -----------------------------------------------------------------------
      when ST_WR_HIT_TEST =>
	if tagHitEn = '1' then
		cacheDone <= '1';
		tagWrEn <= '1';
		tagWrSet <= tagHitSet;
		tagWrSetDirty <= '1';
		tagAddr <= cpuReqRegAddr;
		dataArrayWrEn <= '1';
		dataArrayWrWord <= '1';
		dataArrayWrSetIdx <= tagHitSet;
		dataArrayWrData <= cpuReqRegData;
		
		cacheStNext <= ST_IDLE;
	else
		cacheStNext <= ST_WR_WAIT_BUS_GRANT;
	end if;

      when ST_WR_WAIT_BUS_GRANT =>
	if busGrant = '1' then
		busReq <= '1';

		--TRI STATE BUS ( busOutEn <= '1' )
		busOutEn <= '1';
		busCmd <= BUS_WRITE_WORD;
		busAddr <= cpuRegReqAddr;
		busData <= cpuReqRegData;
		
		cacheStNext <= ST_WR_WAIT_BUS_COMPLETE;
	else
		busReq <= '1';
	end if;

      when ST_WR_WAIT_BUS_COMPLETE =>
	if busGrant != '1' then
		cacheDone <= '1';
		cacheStNext <= ST_IDLE;
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
  
  end process clk_proc;

-- there should be more stuff here (combinational)

-- budDataWord
busDataword : process(cpuRegReqWord, busData) is 
begin
	busDataWord <= busData(getWordOffset(cpuReqReqAddr));
end process busDataword;
		 
-- here is the CpuReqReg block
cpuReqReg : process(cpuReqRegWrEn, cacheAddr, cacheWrData) is
begin
	if cpuReqRegWrEn = '1' then
		cpuReqRegAddr <= cacheAddr;
		cpuReqRegData <= cacheWrData;
	end if;
end process cpuReqReg

-- here is the VictimReg block
victimReg : process(tagHitEn, tagVictimDirty, tagVictimAddr, tagVictimSet, dataArrayRdData) is 
begin
	if tagHitEn = '1' then
		victimReqSet <= tagVictimSet;
		victimRegDirty <= tagVictimDirty;
		victimRegAddr <= tagVictimAddr;
		victimRegData <= dataArrayRdDat(to_integer(unsigned(tagVictimSet)));
	end if;
end process victimReg;

end architecture rtl;
