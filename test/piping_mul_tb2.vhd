
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

entity piping_mul_tb2 is
    generic(
        N: positive:= 8;
        A_DTW: positive:= 8;
        B_DTW: positive:= 8;
        C_DTW: positive:= 14;
        CAL_NUM: positive:= 4;
        SFT_NUM: natural:= 2
    );
end entity;

architecture SIM of piping_mul_tb2 is
    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal i_ready: sl_array_t(0 to N-1):=(others=>'0');
    signal i_valid: sl_array_t(0 to N-1):=(others=>'0');
    signal o_ready: sl_array_t(0 to N-1):=(others=>'0');
    signal o_valid: sl_array_t(0 to N-1):=(others=>'0');
    signal a: slv_array_t(0 to N-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to N-1)(B_DTW-1 downto 0):=(others=>(others=>'0'));
    signal c: slv_array_t(0 to N-1)(C_DTW-1 downto 0);

    signal exp: slv_array_t(0 to N-1)(C_DTW-1 downto 0);
begin
    piping_mul: entity work.piping_mul generic map(
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
            variable cc_real: real;
            variable cc: integer;
            variable ret: std_logic_vector(C_DTW-1 downto 0);
        begin
            aa := to_integer(signed(a));
            bb := to_integer(signed(b));
            cc := aa * bb;
            if SFT_NUM/=0 then
                cc_real := real(cc) / (2.0**SFT_NUM);
                cc_real := floor(real(cc) / (2.0**SFT_NUM) + 0.5);
                -- cc_real := round(real(cc) / (2.0**SFT_NUM));
                cc := integer(cc_real);
            end if;
            cc := minimum(cc, 2**(C_DTW-1)-1); -- clip
            cc := maximum(cc, -2**(C_DTW-1)); -- clip
            ret := std_logic_vector(to_signed(cc, C_DTW));
            return ret;
        end function;
    begin
        for i in 0 to N-1 loop
            if i_valid(i)='1' and i_ready(i)='1' then
                exp(i) <= cal_exp(a(i), b(i));
            end if;
        end loop;
    end process;

    process
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for k in 0 to 100 loop
            for i in 0 to N-1 loop
                if o_valid(i)='1' then
                    check(c(i), exp(i), "DATA" + i, True);
                end if;
            end loop;

            for i in 0 to N-1 loop
                i_valid(i) <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
                o_ready(i) <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
                a(i) <= rand_slv(A_DTW);
                b(i) <= rand_slv(B_DTW);
            end loop;

            wait_clock(clk, 1);
            wait for 1 ns;
        end loop;

        wait_clock(clk, 5); -- wait clock rising, 5times
        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;


    process(all) begin
        if(falling_edge(o_valid(0))=True) then
            assert o_ready(0)='1'
            report "Valid Error"
            severity Error;
        end if;
    end process;

end architecture;
