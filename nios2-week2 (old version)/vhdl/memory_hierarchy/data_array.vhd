library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;

entity DataArray is

  port (
    clk                            : in  std_logic;
    dataArrayWrEn, dataArrayWrWord : in  std_logic;
    dataArrayWrSetIdx              : in  std_logic_vector(WORD_OFFSET_WIDTH-1 downto 0);
    dataArrayAddr                  : in  std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    dataArrayWrData                : in  data_block_t;
    dataArrayRdData                : out data_set_t);

end entity DataArray;

architecture rtl of DataArray is
  type data_set_array_t is array (0 to NUM_BLOCKS-1) of data_block_t;
  type data_array_t is array (0 to NUM_SETS-1) of data_set_array_t;
  signal dataArray : data_array_t;

  signal dataReadout, dataWrite : data_block_flat_t;

  signal blockAddr  : integer;
  signal wordOffset : integer;
  signal setIdx     : integer;
begin  -- architecture rtl

  blockAddr  <= getBlockIdx(dataArrayAddr);
  wordOffset <= getWordOffset(dataArrayAddr);
  setIdx     <= to_integer(unsigned(dataArrayWrSetIdx));

  clk_proc : process (clk) is
  begin  -- process clk_proc
    if clk'event and clk = '1' then     -- rising clock edge
      -- write
      if dataArrayWrEn = '1' then
        if dataArrayWrWord = '1' then
          dataArray(setIdx)(blockAddr)(wordOffset) <= dataArrayWrData(0);
        else
          dataArray(setIdx)(blockAddr) <= dataArrayWrData;
        end if;
      -- lookup
      else
        for i in 0 to NUM_SETS-1 loop
          dataArrayRdData(i) <= dataArray(i)(blockAddr);
        end loop;  -- i
      end if;
    end if;
  end process clk_proc;

end architecture rtl;
