library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;


package soc_components is
  component buttons is
    port (
      clk      : in  std_logic;
      reset_n  : in  std_logic;
      cs0      : in  std_logic;
      read0    : in  std_logic;
      write0   : in  std_logic;
      address0 : in  std_logic;
      rddata0  : out std_logic_vector(31 downto 0);
      cs1      : in  std_logic;
      read1    : in  std_logic;
      write1   : in  std_logic;
      address1 : in  std_logic;
      rddata1  : out std_logic_vector(31 downto 0);
      buttons  : in  std_logic_vector(3 downto 0));
  end component buttons;

  component LEDs is
    port (
      clk      : in  std_logic;
      reset_n  : in  std_logic;
      cs0      : in  std_logic;
      read0    : in  std_logic;
      write0   : in  std_logic;
      address0 : in  std_logic_vector(1 downto 0);
      rddata0  : out std_logic_vector(31 downto 0);
      wrdata0  : in  std_logic_vector(31 downto 0);
      cs1      : in  std_logic;
      read1    : in  std_logic;
      write1   : in  std_logic;
      address1 : in  std_logic_vector(1 downto 0);
      rddata1  : out std_logic_vector(31 downto 0);
      wrdata1  : in  std_logic_vector(31 downto 0);
      LEDs     : out std_logic_vector(95 downto 0));
  end component LEDs;

  component ROM is
    port (
      clk      : in  std_logic;
      cs0      : in  std_logic;
      read0    : in  std_logic;
      address0 : in  std_logic_vector(9 downto 0);
      rddata0  : out std_logic_vector(31 downto 0);
      cs1      : in  std_logic;
      read1    : in  std_logic;
      address1 : in  std_logic_vector(9 downto 0);
      rddata1  : out std_logic_vector(31 downto 0));
  end component ROM;

  component BusController is
    port (
      clk, rst                               : in    std_logic;
      busReq                                 : in    std_logic_vector(N_CACHES-1 downto 0);
      busAddr                                : in    std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      busCmd                                 : in    bus_cmd_t;
      busData                                : inout data_block_t;
      busGrant                               : out   std_logic_vector(N_CACHES-1 downto 0);
      busSnoopValid                          : out   std_logic;
      memCs, memRead, memWrite, memWriteWord : out   std_logic;
      memAddr                                : out   std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      memWrData                              : out   data_block_t;
      memRdData                              : in    data_block_t;
      memDone                                : in    std_logic);
  end component BusController;

  component CacheController is
    port (
      clk, rst                       : in    std_logic;
      cacheCs, cacheRead, cacheWrite : in    std_logic;
      cacheAddr                      : in    std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      cacheWrData                    : in    data_word_t;
      cacheDone                      : out   std_logic;
      cacheRdData                    : out   data_word_t;
      busReq                         : out   std_logic;
      busCmd                         : inout bus_cmd_t;
      busGrant                       : in    std_logic;
      busSnoopValid                  : in    std_logic;
      busAddr                        : inout std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
      busData                        : inout data_block_t);
  end component CacheController;

  component decoder is
    port (
      address    : in  std_logic_vector(15 downto 0);
      cs_Buttons : out std_logic;
      cs_LEDS    : out std_logic;
      cs_RAM     : out std_logic;
      cs_ROM     : out std_logic);
  end component decoder;

  component CPU is
    port (
      reset_n : in  std_logic;
      clk     : in  std_logic;
      hit     : in  std_logic;
      data    : in  std_logic;
      rddata  : in  std_logic_vector(31 downto 0);
      write   : out std_logic;
      read    : out std_logic;
      address : out std_logic_vector(15 downto 0);
      wrdata  : out std_logic_vector(31 downto 0));
  end component CPU;

end package soc_components;
