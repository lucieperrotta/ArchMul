library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;

entity TagArray is
  port (
    clk, rst                            : in  std_logic;
    tagLookupEn, tagWrEn, tagWrSetDirty : in  std_logic;
    tagWrSet                            : in  std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
    tagAddr                             : in  std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    tagHitEn, tagVictimDirty            : out std_logic;
    tagHitSet, tagVictimSet             : out std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
    tagVictimAddr                       : out std_logic_vector(WORD_ADDR_WIDTH-1 downto 0));

end entity TagArray;

architecture rtl of TagArray is

  type tag_t is record
    valid : std_logic;
    dirty : std_logic;
    tag   : std_logic_vector(CACHE_TAG_WIDTH-1 downto 0);
  end record tag_t;

  type tag_group_t is array (0 to NUM_SETS-1) of tag_t;
  type tag_array_t is array (0 to NUM_BLOCKS-1) of tag_group_t;
  constant DEFAULT_TAG : tag_t := (valid => '0',
                                   dirty => '0',
                                   tag   => (others => '0'));
  constant DEFAULT_TAG_GROUP : tag_group_t := (others => DEFAULT_TAG);
  signal tagArray            : tag_array_t := (others => DEFAULT_TAG_GROUP);

  signal blockAddr : natural;
  signal tagIn     : std_logic_vector(CACHE_TAG_WIDTH-1 downto 0);

  -- LRU logic: if lru == '0' for a set, it means we did not touch that st
  -- else we touched that set
  -- lru logic is cleared at misses (we mark all blocks as not touched)
  subtype lru_group_t is std_logic_vector(NUM_SETS-1 downto 0);
  type lru_array_t is array (0 to NUM_BLOCKS-1) of lru_group_t;

  signal lruArray    : lru_array_t;
  signal lruGroupUp  : lru_group_t;
  signal foundVictim : std_logic;

  signal foundTag         : std_logic;
  signal foundSet         : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal foundVictimDirty : std_logic;
  signal foundVictimSet   : std_logic_vector(SET_ADDR_WIDTH-1 downto 0);
  signal foundVictimTag   : std_logic_vector(CACHE_TAG_WIDTH-1 downto 0);

begin  -- architecture rtl


  clk_proc : process (clk, rst) is
  begin  -- process clk_proc
    if rst = '0' then                   -- asynchronous reset (active low)
      tagHitEn <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- we are performing a lookup. only update lru state
      if tagLookupEn = '1' then
        -- output hit
        tagHitEn  <= foundTag;
        tagHitSet <= foundSet;

        -- output victim
        tagVictimSet   <= foundVictimSet;
        tagVictimDirty <= foundVictimDirty;
        tagVictimAddr <= (foundVictimTag &
                          std_logic_vector(to_unsigned(blockAddr, BLOCK_ADDR_WIDTH)) &
                          std_logic_vector(to_unsigned(0, WORD_OFFSET_WIDTH)));

        -- update lru - only on lookups
        if tagLookupEn = '1' then
          lruArray(blockAddr) <= lruGroupUp;
        end if;

      -- we are performing a write, update tag, state
      -- dont output anything
      elsif tagWrEn = '1' then
        tagArray(blockAddr)(to_integer(unsigned(tagWrSet))) <= (valid => '1',
                                                                dirty => tagWrSetDirty,
                                                                tag   => tagIn);
      end if;
    end if;
  end process clk_proc;


  comb_proc : process (blockAddr, lruArray, tagAddr, tagArray, tagIn) is
    variable tagGroup : tag_group_t;
    variable lruGroup : lru_group_t;

    variable foundTagVar       : std_logic;
    variable foundSetVar       : integer;
    variable foundVictimVar    : std_logic;
    variable foundVictimSetVar : integer;

  begin  -- process comb_proc
    if tagLookupEn = '1' or tagWrEn = '1' then
      tagIn     <= getTag(tagAddr);
      blockAddr <= getBlockIdx(tagAddr);
      -- tag lookup
      tagGroup  := tagArray(blockAddr);
      lruGroup  := lruArray(blockAddr);

      foundTagVar         := '0';
      foundSetVar         := 0;
      foundVictimVar      := '0';
      foundVictimSetVar   := NUM_SETS-1;
      lruGroupUp          <= (others => '0');

      for i in 0 to NUM_SETS-1 loop
        -- this is a hit
        if tagGroup(i).tag = tagIn and tagGroup(i).valid = '1' then
          foundTagVar := '1';
          foundSetVar := i;
        end if;

        -- find the victim: first lru we did not touch
        if foundVictimVar = '0' and lruGroup(i) /= '1' then
          foundVictimVar    := '1';
          foundVictimSetVar := i;
        end if;
      end loop;  -- i

      -- this is a cache hit
      if foundTagVar = '1' then
        lruGroupUp <= lruGroup;
        lruGroupUp(foundSetVar) <= foundTagVar;
      else
        lruGroupUp <= (others => '0');
        lruGroupUp(foundVictimSetVar) <= '1';
      end if;



      foundTag <= foundTagVar;
      foundSet <= std_logic_vector(to_unsigned(foundSetVar, SET_ADDR_WIDTH));

      foundVictimSet <= std_logic_vector(to_unsigned(foundVictimSetVar, SET_ADDR_WIDTH));
      if tagGroup(foundVictimSetVar).valid = '1' then
        foundVictimDirty <= tagGroup(foundVictimSetVar).dirty;
      else
        foundVictimDirty <= '0';
      end if;
      foundVictimTag <= tagGroup(foundVictimSetVar).tag;

    end if;
  end process comb_proc;

end architecture rtl;
