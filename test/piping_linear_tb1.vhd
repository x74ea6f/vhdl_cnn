
library ieee;
library std;
library work;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;
use std.env.finish;
use work.str_lib.all;
use work.sim_lib.all;
use work.numeric_lib.all;
use work.piping_pkg.all;
use work.fc1_rom.all;

entity piping_linear_tb1 is
    generic(
        P: positive:= 4; -- Data Parallel
        N: positive:= 8*7*7; -- N, Data Depth
        M: positive:= 32; -- MxN
        A_DTW: positive:= 8 -- Input/Output A Data Width
    );
end entity;

architecture SIM of piping_linear_tb1 is
    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal clear: std_logic := '0';
    signal i_ready: std_logic;
    signal i_valid: std_logic:= '0';
    signal o_ready: std_logic:= '0';
    signal o_valid: std_logic;
    signal a: slv_array_t(0 to P-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to P-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));

begin
    piping_linear: entity work.piping_linear generic map(
        P => P,
        N => N,
        M => M,
        A_DTW => A_DTW,
        -- W_MEM_INIT => (others=>(others=>'0')),
        W_MEM_INIT => FC1_W,
        B_MEM_INIT => (others=>(others=>'0'))
    )port map(
        clk => clk,
        rstn => rstn,

        clear => clear,
        i_valid => i_valid,
        i_ready => i_ready,
        o_valid => o_valid,
        o_ready => o_ready,

        a => a,
        b => b
    );

    process begin
        make_clock(clk, 5 ns); -- 10ns clock
    end process;

    process
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for i in 0 to N/P loop
            i_valid <= '1';
            o_ready <= '1';
            for pp in 0 to P-1 loop
                a(pp) <= std_logic_vector(to_unsigned(i*P+pp, A_DTW));
            end loop;
            wait_clock(clk, 1);
            if i_ready='0' then
                wait until i_ready='1';
            end if;
        end loop;
        i_valid <= '0';
        o_ready <= '0';

        wait_clock(clk, 100); -- wait clock rising, 5times
        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;

    process(all) begin
        if(falling_edge(o_valid)=True) then
            assert o_ready='1'
            report "Valid Error"
            severity Error;
        end if;
    end process;

end architecture;
