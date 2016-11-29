library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;

entity RAM64 is
  port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    cs         : in  std_logic;
    read       : in  std_logic;
    write      : in  std_logic;
    write_word : in  std_logic;
    address    : in  std_logic_vector(WORD_ADDR_WIDTH-1 downto 0);
    wrdata     : in  data_block_t;
    rddata     : out data_block_t;
    done       : out std_logic);
end RAM64;

architecture synth of RAM64 is

  constant DELAY_DRAM : natural := 10;
  type mem_array_t is array (0 to NUM_MEM_BLOCKS-1) of data_block_t;
  signal memArray     : mem_array_t;

  type mem_state_t is (ST_IDLE, ST_WAITING);
  signal memSt, memStNext : mem_state_t := ST_IDLE;

  signal delayCounter                         : unsigned(7 downto 0);
  signal delayCounterCount, delayCounterReset : std_logic;

  signal temp_address : std_logic_vector(8 downto 0);
  signal temp_read    : std_logic;
begin


  comb_proc : process (cs, delayCounter, memSt)
  begin  -- process comb_proc
    memStNext         <= memSt;
    delayCounterReset <= '0';
    delayCounterCount <= '0';
    done              <= '0';

    case memSt is
      when ST_IDLE =>
        delayCounterReset <= '1';
        if cs = '1' then
          memStNext <= ST_WAITING;
        end if;

      when ST_WAITING =>
        delayCounterCount <= '1';
        if delayCounter = to_unsigned(DELAY_DRAM, delayCounter'length) then
          memStNext         <= ST_IDLE;
          delayCounterReset <= '1';
          done              <= '1';
        end if;

      when others => null;
    end case;


  end process comb_proc;

  clk_proc : process (clk, rst) is
  begin  -- process clk_proc
    if rst = '0' then                   -- asynchronous reset (active low)
      memSt <= ST_IDLE;
    elsif clk'event and clk = '1' then  -- rising clock edge
      memSt <= memStNext;

      if delayCounterReset = '1' then
        delayCounter <= (others => '0');
      elsif delayCounterCount = '1' then
        delayCounter <= delayCounter + 1;
      end if;


    end if;
  end process clk_proc;


  process (clk)
  begin
    if (rising_edge(clk)) then
      if cs = '1' then
        if write_word = '1' then
          memArray(getBlockIdx(address))(getWordOffset(address)) <= wrdata(0);
        elsif write = '1' then
          memArray(getBlockIdx(address)) <= wrdata;
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if (rising_edge(clk)) then
      if (cs = '1' and read = '1') then
        rddata <= memArray(getBlockIdx(address));
      end if;
    end if;
  end process;

end synth;
