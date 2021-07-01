
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

entity piping_sum_tb1 is
    generic(
        P: positive:= 1; -- Parallel
        M: positive:= 8; -- Input/Output Number
        N: positive:= 8; -- Input/Output Depth
        AB_DTW: positive:= 8; -- Input A Data Width
        SFT_NUM: natural := 3 -- Shift Number
    );
end entity;

architecture SIM of piping_sum_tb1 is
    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal clear: std_logic := '0';
    signal i_valid: sl_array_t(0 to M-1):=(others=>'0');
    signal i_ready: sl_array_t(0 to M-1):=(others=>'0');
    signal o_valid: std_logic:='0';
    signal o_ready: std_logic:='0';
    signal a: slv_array_t(0 to P*M-1)(AB_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to P-1)(AB_DTW-1 downto 0);

    signal exp: slv_array_t(0 to P*N-1)(AB_DTW-1 downto 0);
begin
    piping_sum: entity work.piping_sum generic map(
        P=>P,
        M=>M,
        N=>N,
        AB_DTW=>AB_DTW,
        SFT_NUM=>SFT_NUM
    )port map(
        clk => clk,
        rstn => rstn,
        clear => clear,
        i_ready => i_ready,
        i_valid => i_valid,
        o_ready => o_ready,
        o_valid => o_valid,
        a => a,
        b => b
    );
    process begin
        make_clock(clk, 5 ns); -- 10ns clock
    end process;

    --[TODO]
    -- make expected data
    -- process (all)
    --     function cal_exp(a,b: std_logic_vector) return std_logic_vector is
    --         variable aa: integer;
    --         variable bb: integer;
    --         variable cc_real: real;
    --         variable cc: integer;
    --         variable ret: std_logic_vector(C_DTW-1 downto 0);
    --     begin
    --         aa := to_integer(signed(a));
    --         bb := to_integer(signed(b));
    --         cc := aa + bb;
    --         if SFT_NUM/=0 then
    --             cc_real := real(cc) / (2.0**SFT_NUM);
    --             cc_real := floor(real(cc) / (2.0**SFT_NUM) + 0.5);
    --             -- cc_real := round(real(cc) / (2.0**SFT_NUM));
    --             cc := integer(cc_real);
    --         end if;
    --         cc := minimum(cc, 2**(C_DTW-1)-1); -- clip
    --         cc := maximum(cc, -2**(C_DTW-1)); -- clip
    --         ret := std_logic_vector(to_signed(cc, C_DTW));
    --         return ret;
    --     end function;
    -- begin
    --     for i in 0 to N-1 loop
    --         if i_valid(i)='1' and i_ready(i)='1' then
    --             exp(i) <= cal_exp(a(i), b(i));
    --         end if;
    --     end loop;
    -- end process;

    process
        variable input_count: integer_vector(0 to M-1):=(others=>0);
        variable i_valid_val: std_logic;
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for k in 0 to 100 loop
            -- for i in 0 to N-1 loop
            --     if o_valid(i)='1' then
            --         check(c(i), exp(i), "DATA" + i, True);
            --     end if;
            -- end loop;

            o_ready <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
            for mm in 0 to M-1 loop
                for pp in 0 to P-1 loop
                    if input_count(mm*P+pp)<N then
                        i_valid_val := '1' when unsigned(rand_slv(2)) >= "01" else '0';
                        i_valid(mm*P+pp) <= i_valid_val;
                        if i_valid_val='1' then
                            a(mm*P+pp) <= rand_slv(AB_DTW);
                            input_count(mm*P+pp) := input_count(mm*P+pp) + 1;
                        end if;
                    else
                        i_valid(mm*P+pp) <= '0';
                    end if;
                end loop;
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
        if(falling_edge(o_valid)=True) then
            assert o_ready='1'
            report "Valid Error"
            severity Error;
        end if;
    end process;

end architecture;
