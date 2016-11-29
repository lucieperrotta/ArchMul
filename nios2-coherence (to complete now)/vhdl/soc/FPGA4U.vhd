library ieee;
use ieee.std_logic_1164.all;
use work.mem_types.all;
use work.soc_components.all;
library work;

entity FPGA4U is
  port
    (
      clk        : in  std_logic;
      reset_n    : in  std_logic;
      in_buttons : in  std_logic_vector(3 downto 0);
      out_LEDs   : out std_logic_vector(95 downto 0)
      );
end FPGA4U;

architecture rtl of FPGA4U is

  subtype cpu_addr_t is std_logic_vector(15 downto 0);
  type cpu_addr_array_t is array (0 to N_CACHES-1) of cpu_addr_t;
  type data_word_array_t is array (0 to N_CACHES-1) of data_word_t;

  subtype word_addr_t is std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  type word_addr_array_t is array (0 to N_CACHES-1) of word_addr_t;

  signal cpuAddresses : cpu_addr_array_t;

  signal csButtons, csLEDS, csROM : std_logic_vector(N_CACHES-1 downto 0);

  signal cpuWrData         : data_word_array_t;
  signal cacheDone         : std_logic_vector(N_CACHES-1 downto 0);
  signal cpuRdData         : data_word_array_t;
  signal cpuRead, cpuWrite : std_logic_vector(N_CACHES-1 downto 0);

  signal cacheCs : std_logic_vector(N_CACHES-1 downto 0);

  signal busReq   : std_logic_vector(N_CACHES-1 downto 0);
  signal busAddr  : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal busCmd   : bus_cmd_t;
  signal busData  : data_block_t;
  signal busGrant : std_logic_vector(N_CACHES-1 downto 0);
  signal busSnoopValid : std_logic;

  signal memCs, memRead, memWrite, memWriteWord : std_logic;
  signal memAddr                                : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  signal memWrData                              : data_block_t;
  signal memRdData                              : data_block_t;
  signal memDone                                : std_logic;

begin

  cpu_array : for i in 0 to N_CACHES-1 generate
    CPU_1 : CPU
      port map (
        reset_n => reset_n,
        clk     => clk,
        hit     => cacheDone(i),
        data    => cacheCs(i),
        rddata  => cpuRdData(i),
        write   => cpuWrite(i),
        read    => cpuRead(i),
        address => cpuAddresses(i),
        wrdata  => cpuWrData(i));

    b2v_decoder_0 : decoder
      port map(
        address    => cpuAddresses(i),
        cs_Buttons => csButtons(i),
        cs_LEDS    => csLEDS(i),
        cs_RAM     => cacheCs(i),
        cs_ROM     => csROM(i));

    CacheController_1 : CacheController
      port map (
        clk         => clk,
        rst         => reset_n,
        cacheCs     => cacheCs(i),
        cacheRead   => cpuRead(i),
        cacheWrite  => cpuWrite(i),
        cacheAddr   => cpuAddresses(i)(11 downto 2),  --word addr
        cacheWrData => cpuWrData(i),
        cacheDone   => cacheDone(i),
        cacheRdData => cpuRdData(i),
        busReq      => busReq(i),
        busCmd      => busCmd,
        busGrant    => busGrant(i),
        busSnoopValid => busSnoopValid,
        busAddr     => busAddr,
        busData     => busData);
  end generate cpu_array;

  BusController_1 : BusController
    port map (
      clk          => clk,
      rst          => reset_n,
      busReq       => busReq,
      busAddr      => busAddr,
      busCmd       => busCmd,
      busData      => busData,
      busGrant     => busGrant,
      busSnoopValid  => busSnoopValid,
      memCs        => memCs,
      memRead      => memRead,
      memWrite     => memWrite,
      memWriteWord => memWriteWord,
      memAddr      => memAddr,
      memWrData    => memWrData,
      memRdData    => memRdData,
      memDone      => memDone);

  b2v_doubleRom : rom
    port map(
      clk      => clk,
      cs0      => csROM(0),
      read0    => cpuRead(0),
      cs1      => csROM(1),
      read1    => cpuRead(1),
      address0 => cpuAddresses(0)(11 downto 2),
      address1 => cpuAddresses(1)(11 downto 2),
      rddata0  => cpuRdData(0),
      rddata1  => cpuRdData(1));


  b2v_inst : entity work.ram64
    port map(
      clk        => clk,
      rst        => reset_n,
      cs         => memCs,
      read       => memRead,
      write      => memWrite,
      write_word => memWriteWord,
      address    => memAddr,
      wrdata     => memWrData,
      rddata     => memRdData,
      done       => memDone);



  b2v_inst5 : leds
    port map(
      clk      => clk,
      reset_n  => reset_n,
      cs0      => csLEDS(0),
      read0    => cpuRead(0),
      write0   => cpuWrite(0),
      cs1      => csLEDS(1),
      read1    => cpuRead(1),
      write1   => cpuWrite(1),
      address0 => cpuAddresses(0)(3 downto 2),
      address1 => cpuAddresses(1)(3 downto 2),
      wrdata0  => cpuWrData(0),
      wrdata1  => cpuWrData(1),
      LEDs     => out_LEDs,
      rddata0  => cpuRdData(0),
      rddata1  => cpuRdData(1));


  b2v_inst6 : buttons
    port map(
      clk      => clk,
      reset_n  => reset_n,
      cs0      => csButtons(0),
      read0    => cpuRead(0),
      write0   => cpuWrite(0),
      address0 => cpuAddresses(0)(2),
      cs1      => csButtons(1),
      read1    => cpuRead(1),
      write1   => cpuWrite(1),
      address1 => cpuAddresses(1)(2),
      buttons  => in_buttons,
      rddata0  => cpuRdData(0),
      rddata1  => cpuRdData(1));


end rtl;
