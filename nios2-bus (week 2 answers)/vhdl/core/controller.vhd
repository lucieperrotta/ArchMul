library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity controller is
  port(
    clk        : in  std_logic;
    reset_n    : in  std_logic;
    -- instruction opcode
    op         : in  std_logic_vector(5 downto 0);
    opx        : in  std_logic_vector(5 downto 0);
    -- activates branch condition
    branch_op  : out std_logic;
    -- immediate value sign extention
    imm_signed : out std_logic;
    -- instruction register enable
    ir_en      : out std_logic;
    -- PC control signals
    pc_add_imm : out std_logic;
    pc_en      : out std_logic;
    pc_sel_a   : out std_logic;
    pc_sel_imm : out std_logic;
    -- register file enable
    rf_wren    : out std_logic;
    -- multiplexers selections
    sel_addr   : out std_logic;
    sel_b      : out std_logic;
    sel_mem    : out std_logic;
    sel_pc     : out std_logic;
    sel_ra     : out std_logic;
    sel_rC     : out std_logic;
    -- write memory output
    read       : out std_logic;
    write      : out std_logic;
    -- alu op
    op_alu     : out std_logic_vector(5 downto 0);
    -- New cache signals
    hit        : in  std_logic;
    data       : in  std_logic
    );
end controller;

architecture synth of controller is
  type state_type is (FETCH1, FETCH2, DECODE, R_OP, RI_OP, I_OP, UI_OP, LOAD1, LOAD2, STORE, BRANCH, CALL, CALLR, RET, BREAK, JMPI, DATALOAD2, DATASTORE);
  signal state, nextstate : state_type;
begin
  -- op_alu:
  process(clk)
  begin
    if (rising_edge(clk)) then
      -- the 3 lsb of op_alu are defined by opx if RTYPE
      op_alu(2 downto 0) <= op(5 downto 3);
      case op(2 downto 0) is
        -- RTYPE
        when "010" =>
          op_alu(2 downto 0) <= opx(5 downto 3);
          case opx(2 downto 0) is
            -- comparator unit when opx[2..0] = "000"
            when "000"         => op_alu(5 downto 3) <= "011";
            -- add/sub unit when opx[2..0] = "001"
            -- the sub_mode = opx(3)
            when "001"         => op_alu(5 downto 3) <= "00" & opx(3);
            -- shift unit when opx[2..1] = "01"
            when "010" | "011" => op_alu(5 downto 3) <= "110";
            -- logic unit when opx[2..0] = "110"
            when "110"         => op_alu(5 downto 3) <= "100";
            -- default operation is sum
            when others        => op_alu(5 downto 3) <= "000";
          end case;
        -- comparator unit when op[2..0] = "000" or "110" (branch)
        when "000" | "110" => op_alu(5 downto 3) <= "011";
        -- logic or add unit when opx[2..0] = "100"
        when "100" =>
          -- add : 0x04
          if (op(5 downto 3) = "000") then
            op_alu(5 downto 3) <= "000";
          else                          -- logic unit
            op_alu(5 downto 3) <= "100";
          end if;
        -- default operation is sum
        when others => op_alu(5 downto 3) <= "000";
      end case;
    end if;
  end process;

  process (data, hit, op, opx, state)
  begin
    nextstate  <= state;
    branch_op  <= '0';
    imm_signed <= '1';
    ir_en      <= '0';
    pc_add_imm <= '0';
    pc_en      <= '0';
    pc_sel_a   <= '0';
    pc_sel_imm <= '0';
    rf_wren    <= '0';
    sel_addr   <= '0';
    sel_b      <= '0';
    sel_mem    <= '0';
    sel_pc     <= '0';
    sel_rC     <= '0';
    sel_ra     <= '0';
    write      <= '0';
    read       <= '0';

    case state is
      when FETCH1 =>
        read      <= '1';
        nextstate <= FETCH2;

      when FETCH2 =>
        pc_en     <= '1';
        ir_en     <= '1';
        nextstate <= DECODE;

      when DECODE =>
        case op is
          -- R-Type
          when "111010" =>
            case opx is
              -- RET (jmp is optional)
              when "000101" | "001101" => nextstate <= RET;
              -- CALLR
              when "011101"            => nextstate <= CALLR;
              -- BREAK
              when "110100"            => nextstate <= BREAK;
              -- RI_OP
              when "000010" | "011010" | "010010" | "111010" =>
                nextstate <= RI_OP;
              -- R_OP
              when others => nextstate <= R_OP;
            end case;
          -- CALL
          when "000000" => nextstate <= CALL;
          -- JMPI (optional)
          when "000001" => nextstate <= JMPI;
          -- BRANCH
          when "000110" | "001110" | "010110" | "011110" | "100110" | "101110" | "110110" =>
            nextstate <= BRANCH;
          -- LOAD
          when "010111" => nextstate <= LOAD1;
          -- STORE
          when "010101" => nextstate <= STORE;
          -- UI_OP
          when "001100" | "011100" | "010100" | "101000" | "110000" =>
            nextstate <= UI_OP;
          -- I_OP
          when others => nextstate <= I_OP;
        end case;

      when BRANCH =>
        nextstate  <= FETCH1;
        sel_b      <= '1';
        branch_op  <= '1';
        pc_add_imm <= '1';

      when CALL =>
        nextstate  <= FETCH1;
        pc_en      <= '1';
        pc_sel_imm <= '1';
        rf_wren    <= '1';
        sel_pc     <= '1';
        sel_ra     <= '1';

      when JMPI =>
        nextstate  <= FETCH1;
        pc_en      <= '1';
        pc_sel_imm <= '1';

      when CALLR =>                     -- optional
        nextstate <= FETCH1;
        pc_en     <= '1';
        pc_sel_a  <= '1';
        rf_wren   <= '1';
        sel_pc    <= '1';
        sel_rC    <= '1';

      when LOAD1 =>
        if (data = '1') then
          nextstate <= DATALOAD2;
        else
          nextstate <= LOAD2;
        end if;
        sel_addr <= '1';
        read     <= '1';

      when LOAD2 =>
        nextstate <= FETCH2;
        sel_mem   <= '1';
        rf_wren   <= '1';
        -- read next instruction
        read      <= '1';

      when RET =>
        nextstate <= FETCH1;
        pc_en     <= '1';
        pc_sel_a  <= '1';

      when STORE =>
        if (data = '0') then
          nextstate <= FETCH1;
        else
          nextstate <= DATASTORE;
        end if;

        sel_addr <= '1';
        write    <= '1';

      when DATASTORE =>
        if (hit = '1') then
          nextstate <= FETCH2;
          -- read next instruction
          read      <= '1';
        else
          nextstate <= DATASTORE;
        end if;

      when R_OP =>
        nextstate <= FETCH2;
        sel_b     <= '1';
        rf_wren   <= '1';
        sel_rC    <= '1';
        -- read next instruction
        read      <= '1';

      when RI_OP =>
        nextstate <= FETCH2;
        rf_wren   <= '1';
        sel_rC    <= '1';
        -- read next instruction
        read      <= '1';

      when I_OP =>
        nextstate <= FETCH2;
        rf_wren   <= '1';
        -- read next instruction
        read      <= '1';

      when UI_OP =>
        nextstate  <= FETCH2;
        rf_wren    <= '1';
        imm_signed <= '0';
        -- read next instruction
        read       <= '1';

      when DATALOAD2 =>
        if (hit = '1') then
          rf_wren   <= '1';
          sel_mem   <= '1';
          read      <= '1';
          nextstate <= FETCH2;
        else
          nextstate <= DATALOAD2;
        end if;

      when BREAK =>
        nextstate <= BREAK;
      when others =>
        nextstate <= FETCH1;
    end case;
  end process;

  process (clk, reset_n)
  begin
    if (reset_n = '0') then
      state <= FETCH1;
    elsif (rising_edge(clk)) then
      state <= nextstate;
    end if;
  end process;
end synth;
