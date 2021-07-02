-- RAM
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram1rw is
    generic(
        DTW: positive:= 8; -- Data Width
        ADW: positive:= 8; -- Address Width
        DEPTH: positive:= 256 -- Input B Data Width
    );
    port(
        clk: in std_logic;
        ce: in std_logic;
        we: in std_logic;
        a: in std_logic_vector(ADW-1 downto 0);
        d: in std_logic_vector(DTW-1 downto 0);
        q: out std_logic_vector(DTW-1 downto 0)
    );
end entity;

architecture RTL of ram1rw is
    type mem_t is array(natural range <>) of std_logic_vector;
    signal mem: mem_t(0 to DEPTH-1)(DTW-1 downto 0);

    signal q_val: std_logic_vector(DTW-1 downto 0);
begin

    process (clk) begin
        if rising_edge(clk) then
            if ce='1' then
                if we='1' then
                    mem(to_integer(unsigned(a))) <= d;
                end if;
            end if;
        end if;
    end process;

    q_val <= mem(to_integer(unsigned(a)));
    q <= q_val;

end architecture;
