library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity buttons is
  port(
    -- bus interface
    clk      : in  std_logic;
    reset_n  : in  std_logic;
    --irq     : out std_logic;
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

    buttons : in std_logic_vector(3 downto 0)
    );
end buttons;

architecture synth of buttons is

  constant REG_DATA : std_logic := '0';
  constant REG_EDGE : std_logic := '1';

  signal address_reg0, address_reg1 : std_logic;
  signal read_reg0, read_reg1       : std_logic;
  signal edges0, edges1             : std_logic_vector(3 downto 0);

  signal buttons_reg                : std_logic_vector(3 downto 0);  
begin

  --irq <= '0' when edges = 0 else '1';

  -- address_reg & button_reg
  process(clk, reset_n)
  begin
    if (reset_n = '0') then
      buttons_reg <= (others => '1');

      address_reg0 <= '0';
      read_reg0    <= '0';

      address_reg1 <= '0';
      read_reg1    <= '0';
    elsif (rising_edge(clk)) then
      buttons_reg <= buttons;

      address_reg0 <= address1;
      read_reg0    <= read1 and cs1;

      address_reg1 <= address1;
      read_reg1    <= read1 and cs1;

    end if;
  end process;

  -- read
  process(address_reg0, address_reg1, buttons, edges0, edges1, read_reg0,
          read_reg1)
  begin
    rddata0 <= (others => 'Z');
    rddata1 <= (others => 'Z');

    if (read_reg0 = '1') then
      rddata0 <= (others => '0');
      case address_reg0 is
        when REG_DATA =>
          rddata0(3 downto 0) <= buttons;
        when REG_EDGE =>
          rddata0(3 downto 0) <= edges0;
        when others =>
      end case;
    end if;

    if (read_reg1 = '1') then
      rddata1 <= (others => '0');
      case address_reg1 is
        when REG_DATA =>
          rddata1(3 downto 0) <= buttons;
        when REG_EDGE =>
          rddata1(3 downto 0) <= edges1;
        when others =>
      end case;
    end if;
    
  end process;

  -- edges
  process(clk, reset_n)
  begin
    if (reset_n = '0') then
      edges0 <= (others => '0');
      edges1 <= (others => '0');
    elsif (rising_edge(clk)) then
      -- edge detection
      edges0 <= edges0 or (not buttons and buttons_reg);
      edges1 <= edges1 or (not buttons and buttons_reg);
      
      -- clear edges
      if (cs0 = '1' and write0 = '1') then
        if (address0 = REG_EDGE) then
          edges0 <= (others => '0');
        end if;
      end if;

      if (cs1 = '1' and write1 = '1') then
        if (address1 = REG_EDGE) then
          edges1 <= (others => '0');
        end if;
      end if;
      
    end if;
  end process;

end synth;
