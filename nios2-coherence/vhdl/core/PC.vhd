library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity PC is
    port(
        clk     : in  std_logic;
        reset_n : in  std_logic;
        en      : in  std_logic;
        sel_a   : in  std_logic;
        sel_imm : in  std_logic;
        add_imm : in  std_logic;
        imm     : in  std_logic_vector(15 downto 0);
        a       : in  std_logic_vector(15 downto 0);
        addr    : out std_logic_vector(31 downto 0)
    );
end PC;

-- version that guarantees the PC is byte aligned, because it pads the output
-- address with "00". It guarantees that, for example, when sel_a is enabled,
-- that a is a correct byte aligned address (even if the register file provides
-- some non-aligned value)
--
-- architecture synth of PC is
--
--     signal counter : std_logic_vector(13 downto 0);
--     signal add_op  : std_logic_vector(13 downto 0);
--
-- begin
--
--     addr <= (15 downto 0 => '0') & counter & "00";
--
--     add_op <= imm(15 downto 2) when add_imm = '1' else (0 => '1', others => '0');
--
--     process(reset_n, clk)
--     begin
--         if (reset_n = '0') then
--             counter <= (others => '0');
--         elsif (rising_edge(clk)) then
--             if (en = '1') then
--                 if ((sel_a or sel_imm) = '1') then
--                     if (sel_a = '1') then
--                         counter <= a(15 downto 2);
--                     else
--                         counter <= imm(13 downto 0);
--                     end if;
--                 else
--                     counter <= counter + add_op;
--                 end if;
--             end if;
--         end if;
--     end process;
--
-- end synth;

architecture synth of PC is

    signal counter : std_logic_vector(15 downto 0);
    signal add_val : std_logic_vector(15 downto 0);

begin

    addr <= (15 downto 0 => '0') & counter;

    add_val <= imm when add_imm = '1' else X"0004";

    process(reset_n, clk)
    begin
        if (reset_n = '0') then
            counter <= (others => '0');
        elsif (rising_edge(clk)) then
            if (en = '1') then
                if ((sel_a or sel_imm) = '1') then
                    if (sel_a = '1') then
                        counter <= a;
                    else
                        counter <= imm(13 downto 0) & "00";
                    end if;
                else
                    counter <= counter + add_val;
                end if;
            end if;
        end if;
    end process;

end synth;