library ieee;
use ieee.std_logic_1164.all;

library work;

entity MultiprocessorTestbench is

end entity MultiprocessorTestbench;

architecture test of MultiprocessorTestbench is
  constant CLK_PERIOD  : time      := 40 ns;
  constant BUTTON_TIME : time      := 1 us;  --  200 cycles
  signal clk           : std_logic := '0';
  signal reset_n       : std_logic := '0';
  signal in_buttons    : std_logic_vector(3 downto 0);
  signal out_LEDs      : std_logic_vector(95 downto 0);
  
begin  -- architecture test

  FPGA4U_1 : entity work.FPGA4U
    port map (
      clk        => clk,
      reset_n    => reset_n,
      in_buttons => in_buttons,
      out_LEDs   => out_LEDs);



  process
  begin
    clk <= not clk;
    wait for CLK_PERIOD/2;
  end process;

  process
  begin
    in_buttons <= (others => '1');
    reset_n <= '0';
    wait for CLK_PERIOD/2;
    reset_n <= '1';
    wait for BUTTON_TIME;
    in_buttons <= "1110";
    wait for BUTTON_TIME;
    in_buttons <= "1100";
    wait for BUTTON_TIME;
    in_buttons <= "1000";
    wait;
  end process;

end architecture test;
