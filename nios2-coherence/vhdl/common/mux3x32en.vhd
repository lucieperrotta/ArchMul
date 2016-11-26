library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity mux3x32en is
  port(
    i0  : in  std_logic_vector(31 downto 0);
    i1  : in  std_logic_vector(31 downto 0);
    i2  : in  std_logic_vector(31 downto 0);
    sel : in  std_logic_vector(2 downto 0);
    en  : in  std_logic;
    o   : out std_logic_vector(31 downto 0)
    );
end mux3x32en;

architecture synth of mux3x32en is
begin

  process(i0, i1, i2, en, sel)
  begin
    if(en = '1') then
      case sel is
        when "001"  => o <= i0;
        when "010"  => o <= i1;
        when "100"  => o <= i2;
        when others => o <= i0;
      end case;
    else
      o <= (others => 'Z');
    end if;
  end process;

end synth;
