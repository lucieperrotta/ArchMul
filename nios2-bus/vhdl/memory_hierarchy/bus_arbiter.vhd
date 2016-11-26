library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_types.all;

entity busArbiter is

  port (
    clk              :     std_logic;
    arbiterArbitrate : in  std_logic;
    arbiterBusReqIn  : in  std_logic_vector(N_CACHES-1 downto 0);
    arbiterReqValid  : out std_logic;
    arbiterReqId     : out std_logic_vector(CACHE_IDX_WIDTH-1 downto 0));

end entity busArbiter;

architecture rtl of busArbiter is

  signal arbiterLastReq : unsigned(CACHE_IDX_WIDTH-1 downto 0);

  signal foundReq    : std_logic;
  signal foundReqIdx : unsigned(CACHE_IDX_WIDTH-1 downto 0);

begin  -- architecture rtl

  comb_proc : process (arbiterArbitrate, arbiterBusReqIn,
                       arbiterLastReq, foundReq, foundReqIdx) is
    variable priorityReq : integer;
  begin  -- process comb_proc

    foundReq <= '0';
    foundReqIdx <= (others => '0');
    -- priority encoder for arbiter
    for i in 0 to N_CACHES-1 loop
      -- start from the priority
      priorityReq := (i + to_integer(arbiterLastReq)) mod N_CACHES;
      if arbiterBusReqIn(priorityReq) = '1' then
        foundReq    <= '1';
        foundReqIdx <= to_unsigned(priorityReq, foundReqIdx'length);
      end if;
    end loop;  -- i

    arbiterReqValid <= foundReq;
    if arbiterArbitrate = '1' then
      arbiterReqId <= std_logic_vector(foundReqIdx);
    else
      arbiterReqId <= std_logic_vector(arbiterLastReq);
    end if;

  end process comb_proc;

  clk_proc : process (clk) is
  begin  -- process clk_proc
    if clk'event and clk = '1' then     -- rising clock edge
      if arbiterArbitrate = '1' then
        arbiterLastReq <= foundReqIdx;
      end if;
    end if;
  end process clk_proc;

end architecture rtl;
