library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity mux2x5 is
    port(
        i0  : in  std_logic_vector(4 downto 0);
        i1  : in  std_logic_vector(4 downto 0);
        sel : in  std_logic;
        o   : out std_logic_vector(4 downto 0)
    );
end mux2x5;

architecture synth of mux2x5 is
begin

    process(i0, i1, sel)
    begin
        if (sel = '0') then
            o <= i0;
        else
            o <= i1;
        end if;
    end process;

end synth;
