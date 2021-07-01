-- Weithg RAM Control
--[TODO] 難しいのであとで。
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity weigth_ram_control is
    generic(
        P: positive:= 1; -- Data Parallel
        N: positive:= 8; -- N, Data Depth
        M: positive:= 8; -- MxN
        A_DTW: positive:= 8; // Input/Output A Data Width
        ADR_DTW: positive:= 3 -- clog2(N/P)
    );
    port(
        clk: in std_logic;
        rstn: in std_logic;

        clear: in std_logic;
        i_valid: in std_logic;
        i_ready: out std_logic;
        o_valid: out sl_array_t(0 to M-1);
        o_ready: in sl_array_t(0 to M-1);

        a: in slv_array_t(0 to P-1)(A_DTW-1 downto 0);
        b: out slv_array_t(0 to P-1)(A_DTW-1 downto 0);
        c: out slv_array_t(0 to P*M-1)(A_DTW-1 downto 0);

        ram_re: out std_logic;
        ram_addr: out std_logic_vector(ADR_DTW-1 downto 0);
        ram_rd: in slv_array_t(0 to P*M-1)(A_DTW-1 downto 0)
    );
end entity;

architecture RTL of weigth_ram_control is

    constant NN: positive := clog2(N);

begin


end architecture;
