library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mem_types is
  constant WORD_ADDR_WIDTH : integer := 10;
  subtype word_addr_t is std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
  -- cache description
  constant WORD_WIDTH               : integer     := 32;
  subtype data_word_t is std_logic_vector(WORD_WIDTH-1 downto 0);
  constant DATA_WORD_HIGH_IMPEDANCE : data_word_t := (others => 'Z');

  constant NUM_WORDS_BLOCK   : integer := 2;
  constant WORD_OFFSET_WIDTH : integer := 1;
  constant BLOCK_WIDTH       : integer := NUM_WORDS_BLOCK*WORD_WIDTH;

  type data_block_t is array (0 to NUM_WORDS_BLOCK-1) of data_word_t;
  constant DATA_BLOCK_HIGH_IMPEDANCE : data_block_t := (others => DATA_WORD_HIGH_IMPEDANCE);

  subtype data_block_flat_t is std_logic_vector(BLOCK_WIDTH-1 downto 0);

  function flattenBlock (
    signal dataBlock : data_block_t)
    return data_block_flat_t;

  function unflattenBlock (
    signal dataBlock : data_block_flat_t)
    return data_block_t;

  constant NUM_SETS       : integer := 2;
  constant SET_ADDR_WIDTH : integer := 1;
  type data_set_t is array (0 to NUM_SETS-1) of data_block_t;

  constant NUM_BLOCKS       : integer := 64;
  constant BLOCK_ADDR_WIDTH : integer := 6;

  constant CACHE_TAG_WIDTH : integer := 3;
  subtype tag_addr_t is std_logic_vector(CACHE_TAG_WIDTH-1 downto 0);

  constant N_CACHES        : integer := 2;
  constant CACHE_IDX_WIDTH : integer := 1;

  constant NUM_MEM_BLOCKS : integer := 512;

  constant BUS_CMD_WIDTH  : integer   := 2;
  subtype bus_cmd_t is std_logic_vector(BUS_CMD_WIDTH-1 downto 0);
  constant BUS_READ       : bus_cmd_t := "00";
  constant BUS_WRITE      : bus_cmd_t := "01";
  constant BUS_WRITE_WORD : bus_cmd_t := "10";

  type bus_cmd_array_t is array (0 to N_CACHES-1) of bus_cmd_t;

  function getBlockIdx (
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0))
    return natural;

  function getTag (
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0))
    return tag_addr_t;

  function getWordOffset (
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0))
    return natural;

end package mem_types;


package body mem_types is

  function flattenBlock (
    signal dataBlock : data_block_t)
    return data_block_flat_t is
  begin  -- function flattenBlock
    return dataBlock(1) & dataBlock(0);
  end function flattenBlock;

  function unflattenBlock (
    signal dataBlock : data_block_flat_t)
    return data_block_t is
    variable dataBlockIn : data_block_t;
  begin  -- function unflattenBlock
    dataBlockIn(1) := dataBlock(NUM_WORDS_BLOCK*WORD_WIDTH-1 downto WORD_WIDTH);
    dataBlockIn(0) := dataBlock(WORD_WIDTH-1 downto 0);
    return dataBlockIn;
  end function unflattenBlock;

  function getBlockIdx (
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0))
    return natural is
  begin
    return to_integer(unsigned(addr(WORD_OFFSET_WIDTH+BLOCK_ADDR_WIDTH-1 downto WORD_OFFSET_WIDTH)));
  end function getBlockIdx;

  function getWordOffset (
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0))
    return natural is
  begin
    return to_integer(unsigned(addr(WORD_OFFSET_WIDTH-1 downto 0)));
  end function getWordOffset;


  function getTag (
    addr : std_logic_vector(WORD_ADDR_WIDTH-1 downto 0))
    return tag_addr_t is
  begin
    return addr(WORD_ADDR_WIDTH-1 downto WORD_ADDR_WIDTH-CACHE_TAG_WIDTH);
  end function getTag;


end package body mem_types;
