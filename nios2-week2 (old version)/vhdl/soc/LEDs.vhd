library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity LEDs is
  port(
    -- bus interface
    clk     : in std_logic;
    reset_n : in std_logic;

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

    -- external output
    LEDs : out std_logic_vector(95 downto 0)
    );
end LEDs;

architecture synth of LEDs is

  constant REG_LED_0_31   : std_logic_vector(1 downto 0) := "00";
  constant REG_LED_32_63  : std_logic_vector(1 downto 0) := "01";
  constant REG_LED_64_95  : std_logic_vector(1 downto 0) := "10";
  constant REG_DUTY_CYCLE : std_logic_vector(1 downto 0) := "11";

  signal reg_read0, reg_read1       : std_logic;
  signal reg_address0, reg_address1 : std_logic_vector(1 downto 0);
  signal counter0, counter1         : std_logic_vector(7 downto 0);
  signal LEDs_reg                   : std_logic_vector(95 downto 0);
  signal duty_cycle0, duty_cycle1   : std_logic_vector(7 downto 0);

begin

  LEDs(47 downto 0)  <= LEDs_reg(47 downto 0)  when counter0 < duty_cycle0 else (others => '0');
  LEDs(95 downto 48) <= LEDs_reg(95 downto 48) when counter1 < duty_cycle1 else (others => '0');

  -- registers
  process (clk, reset_n)
  begin
    if (reset_n = '0') then
      reg_read0    <= '0';
      reg_read1    <= '0';
      
      reg_address0 <= (others => '0');
      reg_address1 <= (others => '0');
      
      counter0     <= (others => '0');
      counter1     <= (others => '0');
    elsif (rising_edge(clk)) then
      reg_read0    <= cs0 and read0;
      reg_address0 <= address0;

      if address0 /= REG_DUTY_CYCLE then
        counter0 <= counter0 + 1;
      else
        counter0 <= (others => '0');
      end if;



      reg_read1    <= cs1 and read1;
      reg_address1 <= address1;

      if address1 /= REG_DUTY_CYCLE then
        counter1 <= counter1 + 1;
      else
        counter1 <= (others => '0');
      end if;
      
    end if;
  end process;

  -- read
  process (LEDs_reg, duty_cycle0, reg_address0, reg_read0)
  begin
    rddata0 <= (others => 'Z');
    if (reg_read0 = '1') then
      rddata0 <= (others => '0');
      case reg_address0 is
        when REG_LED_0_31 =>
          rddata0 <= LEDs_reg(31 downto 0);
        when REG_LED_32_63 =>
          rddata0 <= LEDs_reg(63 downto 32);
        when REG_LED_64_95 =>
          rddata0 <= LEDs_reg(95 downto 64);
        when REG_DUTY_CYCLE =>
          rddata0(7 downto 0) <= duty_cycle0;
        when others =>
      end case;
    end if;
  end process;

  -- read
  process (reg_read1, reg_address1, LEDs_reg, duty_cycle1)
  begin
    rddata1 <= (others => 'Z');
    if (reg_read1 = '1') then
      rddata1 <= (others => '0');
      case reg_address1 is
        when REG_LED_0_31 =>
          rddata1 <= LEDs_reg(31 downto 0);
        when REG_LED_32_63 =>
          rddata1 <= LEDs_reg(63 downto 32);
        when REG_LED_64_95 =>
          rddata1 <= LEDs_reg(95 downto 64);
        when REG_DUTY_CYCLE =>
          rddata1(7 downto 0) <= duty_cycle1;
        when others =>
      end case;
    end if;
  end process;

  -- write
  process (clk, reset_n)
  begin
    if (reset_n = '0') then
      LEDs_reg    <= (others => '0');
      duty_cycle0 <= X"0F";
      duty_cycle1 <= X"0F";
    elsif (rising_edge(clk)) then
      -- processor 0
      if (cs0 = '1' and write0 = '1') then
        case address0 is
          when REG_LED_0_31   => LEDs_reg(31 downto 0)  <= wrdata0;
          when REG_LED_32_63  => LEDs_reg(47 downto 32) <= wrdata0(15 downto 0);
          when REG_DUTY_CYCLE => duty_cycle0            <= wrdata0(7 downto 0);
          when others         => null;
        end case;
      end if;


      -- processor 1
      if (cs1 = '1' and write1 = '1') then
        case address1 is
          when REG_LED_0_31   => LEDs_reg(79 downto 48) <= wrdata1;
          when REG_LED_32_63  => LEDs_reg(95 downto 80) <= wrdata1(15 downto 0);
          when REG_DUTY_CYCLE => duty_cycle1            <= wrdata1(7 downto 0);
          when others         => null;
        end case;
      end if;
      
    end if;
  end process;

end synth;
