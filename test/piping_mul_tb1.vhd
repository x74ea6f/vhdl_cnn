
library ieee;
library std;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;
use work.str_lib.all;
use work.sim_lib.all;
use work.numeric_lib.all;
use work.piping_pkg.all;

entity piping_mul_tb1 is
    generic(
        P: positive:= 2;
        N: positive:= 16;
        A_DTW: positive:= 8;
        B_DTW: positive:= 8;
        C_DTW: positive:= 8;
        CAL_NUM: positive:= 4;
        SFT_NUM: natural:= 0
    );
end entity;

architecture SIM of piping_mul_tb1 is
    constant N_P: positive:= (N+P-1)/P;

    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal i_ready: sl_array_t(0 to N_P-1):=(others=>'0');
    signal i_valid: sl_array_t(0 to N_P-1):=(others=>'0');
    signal o_ready: sl_array_t(0 to N_P-1):=(others=>'0');
    signal o_valid: sl_array_t(0 to N_P-1):=(others=>'0');
    signal a: slv_array_t(0 to N-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to N-1)(B_DTW-1 downto 0):=(others=>(others=>'0'));
    signal c: slv_array_t(0 to N-1)(C_DTW-1 downto 0);

    signal exp: slv_array_t(0 to N-1)(C_DTW-1 downto 0);
begin
    piping_mul: entity work.piping_mul generic map(
        P=>P,
        N=>N,
        A_DTW=>A_DTW,
        B_DTW=>B_DTW,
        C_DTW=>C_DTW,
        CAL_NUM=>CAL_NUM,
        SFT_NUM=>SFT_NUM
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

    -- make expected data
    process (all)
        function cal_exp(a,b: std_logic_vector) return std_logic_vector is
            variable aa: integer;
            variable bb: integer;
            variable cc: integer;
            variable ret: std_logic_vector(C_DTW-1 downto 0);
        begin
            aa := to_integer(signed(a));
            bb := to_integer(signed(b));
            cc := aa * bb;
            --[TODO] shift
            cc := maximum(-2**(C_DTW-1), cc); -- clip
            cc := minimum(2**(C_DTW-1)-1, cc); -- clip
            ret := std_logic_vector(to_signed(cc, C_DTW));
            return ret;
        end function;
    begin
        for i in 0 to N_P-1 loop
            if i_valid(i)='1' and o_ready(i)='1' then
                for pp in 0 to P-1 loop
                    exp(i*P+pp) <= cal_exp(a(i*P+pp), b(i*P+pp));
                end loop;
            end if;
        end loop;
    end process;

    process
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for i in 0 to N_P-1 loop
            i_valid(i) <= '1';
            o_ready(i) <= '1';
            for pp in 0 to P-1 loop
                a(i*P+pp) <= std_logic_vector(to_signed(i*P+pp,  A_DTW));
                b(i*P+pp) <= std_logic_vector(to_signed(i*P+pp,  A_DTW));
            end loop;
        end loop;

        wait_clock(clk, 5); -- wait clock rising, 5times

        for i in 0 to N_P-1 loop
            i_valid(i) <= '0';
            o_ready(i) <= '0';
            for pp in 0 to P-1 loop
                check(c(i*P+pp), exp(i*P+pp), "DATA" + (i*P+pp), True);
            end loop;
        end loop;
        wait_clock(clk, 5); -- wait clock rising, 5times

        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;

end architecture;
