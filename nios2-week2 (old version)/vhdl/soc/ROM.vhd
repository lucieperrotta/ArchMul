library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ROM is
  port(
    clk      : in  std_logic;
    cs0      : in  std_logic;
    read0    : in  std_logic;
    address0 : in  std_logic_vector(9 downto 0);
    rddata0  : out std_logic_vector(31 downto 0);

    cs1      : in  std_logic;
    read1    : in  std_logic;
    address1 : in  std_logic_vector(9 downto 0);
    rddata1  : out std_logic_vector(31 downto 0)

    );
end ROM;

architecture synth of ROM is

  component ROM_Block is
    generic (
      INIT_FILE_NAME : string);
    port(
      address : in  std_logic_vector(9 downto 0);
      clock   : in  std_logic;
      q       : out std_logic_vector(31 downto 0)
      );
  end component;

  -- internal signal for the ROM rddata
  signal in_rddata0, in_rddata1 : std_logic_vector(31 downto 0);
  signal reg_read0, reg_read1   : std_logic;

begin

  rom_block_0 : ROM_Block
    generic map (
      INIT_FILE_NAME => "../vhdl/testbenches/binaries/ROM0.hex")
    port map(
      address => address0,
      clock   => clk,
      q       => in_rddata0
      );

  rom_block_1 : ROM_Block
    generic map (
      INIT_FILE_NAME => "../vhdl/testbenches/binaries/ROM1.hex")
    port map(
      address => address1,
      clock   => clk,
      q       => in_rddata1
      );

  -- 1 cycle latency
  process(clk)
  begin
    if (rising_edge(clk)) then
      reg_read0 <= read0 and cs0;
      reg_read1 <= read1 and cs1;
    end if;
  end process;

  -- read in memory
  process(in_rddata0, in_rddata1, reg_read0, reg_read1)
  begin
    rddata0 <= (others => 'Z');
    rddata1 <= (others => 'Z');

    if (reg_read0 = '1') then
      rddata0 <= in_rddata0;
    end if;

    if (reg_read1 = '1') then
      rddata1 <= in_rddata1;
    end if;
    
  end process;

end synth;
