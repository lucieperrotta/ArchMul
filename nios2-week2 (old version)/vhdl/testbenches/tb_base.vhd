library ieee;
use ieee.std_logic_1164.all;

library work;

entity tb_base is

end entity tb_base;

architecture test of tb_base is
  constant CLK_PERIOD : time := 40 ns;
  signal clk, rst                       : std_logic;

begin  -- architecture test

  -- clk generator process
  process
  begin
    clk <= not clk;
    wait for CLK_PERIOD/2;
  end process;


  -- signal drive process
  process
  begin
    rst                    <= '0';
    wait for CLK_PERIOD;
    wait for CLK_PERIOD;
    wait for CLK_PERIOD;
    rst                    <= '1';
    wait for CLK_PERIOD;
    wait for CLK_PERIOD;
    
  end process;

end architecture test;
