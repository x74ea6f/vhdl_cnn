
library ieee;
library std;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;
use work.str_lib.all;
use work.sim_lib.all;
use work.piping_pkg.all;

entity piping_tb is
    generic(
        N: positive:= 8;
        A_DTW: positive:= 8;
        B_DTW: positive:= 8;
        C_DTW: positive:= 8;
        SFT_NUM: natural:= 0;
        MUL_NUM: positive:= 4
    );
end entity;

architecture SIM of piping_tb is
    signal clk, rstn: std_logic;
    signal i_ready: sl_array_t(0 to N-1):=(others=>'0');
    signal i_valid: sl_array_t(0 to N-1):=(others=>'0');
    signal o_ready: sl_array_t(0 to N-1):=(others=>'0');
    signal o_valid: sl_array_t(0 to N-1):=(others=>'0');
    signal a: slv_array_t(0 to N-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to N-1)(B_DTW-1 downto 0):=(others=>(others=>'0'));
    signal c: slv_array_t(0 to N-1)(C_DTW-1 downto 0);
begin
    piping_mul: entity work.piping_mul generic map(
        A_DTW=>A_DTW,
        B_DTW=>B_DTW,
        C_DTW=>C_DTW,
        SFT_NUM=>SFT_NUM,
        MUL_NUM=>MUL_NUM
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => i_ready,
        i_valid => i_valid,
        o_ready => o_ready,
        o_valid => o_valid,
        a => a,
        b => b,
        c => c
    );
    process begin
        make_clock(clk, 5 ns); -- 10ns clock
    end process;

    process
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for i in 0 to N-1 loop
            i_valid(i) <= '1';
            o_ready(i) <= '1';
            a(i) <= std_logic_vector(to_signed(i,  A_DTW));
            b(i) <= std_logic_vector(to_signed(i,  A_DTW));
        end loop;

        wait_clock(clk, 5); -- wait clock rising, 5times

        for i in 0 to N-1 loop
            assert c(i)=std_logic_vector(to_signed(i**2, C_DTW)) report "Compare Error" severity Error;
            print(to_str(c(i)));
        end loop;

        for i in 0 to N-1 loop
            i_valid(i) <= '0';
            o_ready(i) <= '0';
        end loop;
        wait_clock(clk, 5); -- wait clock rising, 5times





        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;

end architecture;
