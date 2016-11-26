library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;

package mem_components is

  component CacheController is
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
  end component CacheController;

  component TagArray is
    port (
      clk, rst                       : in  std_logic;
      tagLookupEn, tagWrEn, tagInvEn : in  std_logic;
      tagWrSet                       : in  std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
      tagAddr, tagInvAddr            : in  std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      tagHitEn                       : out std_logic;
      tagHitSet, tagVictimSet        : out std_logic_vector(SET_ADDR_WIDTH-1 downto 0));
  end component TagArray;

  component DataArray is
    port (
      clk                            : in  std_logic;
      dataArrayWrEn, dataArrayWrWord : in  std_logic;
      dataArrayWrSetIdx              : in  std_logic_vector(WORD_OFFSET_WIDTH-1 downto 0);
      dataArrayAddr                  : in  std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      dataArrayWrData                : in  data_block_t;
      dataArrayRdData                : out data_set_t);
  end component DataArray;

  component BusController is
    port (
      clk, rst                               : in    std_logic;
      busReq                                 : in    std_logic_vector(N_CACHES-1 downto 0);
      busAddr                                : in    std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      busCmd                                 : in    bus_cmd_t;
      busData                                : inout data_block_t;
      busGrant                               : out   std_logic_vector(N_CACHES-1 downto 0);
      memCs, memRead, memWrite, memWriteWord : out   std_logic;
      memAddr                                : out   std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      memWrData                              : in    data_block_t;
      memRdData                              : out   data_block_t;
      memDone                                : in    std_logic);
  end component BusController;
  
  component busArbiter is
    port (
      clk              :     std_logic;
      arbiterArbitrate : in  std_logic;
      arbiterBusReqIn  : in  std_logic_vector(N_CACHES-1 downto 0);
      arbiterReqValid  : out std_logic;
      arbiterReqId     : out std_logic_vector(CACHE_IDX_WIDTH-1 downto 0));
  end component busArbiter;

end package mem_components;
