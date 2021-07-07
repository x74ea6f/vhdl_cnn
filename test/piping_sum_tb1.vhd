
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
        A_DTW: positive:= 8*2-1; -- Input A Data Width
        B_DTW: positive:= 8; -- Input A Data Width
        SFT_NUM: natural := 3 -- Shift Number
    );
end entity;

architecture SIM of piping_sum_tb1 is
    constant M_P: positive := (M+P-1)/P;
    constant N_P: positive := (N+P-1)/P;

    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal clear: std_logic := '0';
    signal i_valid: sl_array_t(0 to M_P-1):=(others=>'0');
    signal i_ready: sl_array_t(0 to M_P-1):=(others=>'0');
    signal o_valid: std_logic:='0';
    signal o_ready: std_logic:='0';
    signal a: slv_array_t(0 to M-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to P-1)(B_DTW-1 downto 0);

    signal sum: integer_vector(0 to M-1):= (others=>0);
    signal exp: slv_array_t(0 to M-1)(B_DTW-1 downto 0);
    signal o_count: integer:=0;
begin
    piping_sum: entity work.piping_sum generic map(
        P=>P,
        M=>M,
        N=>N,
        A_DTW=>A_DTW,
        B_DTW=>B_DTW,
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
    process (clk)
    begin
        if rising_edge(clk) then
            for mm in 0 to M_P-1 loop
                for pp in 0 to P-1 loop
                    if clear='1' then
                        sum(mm*P+pp) <= 0;
                    elsif i_valid(mm)='1' and i_ready(mm)='1' then
                        sum(mm*P+pp) <= sum(mm*P+pp) + to_integer(signed(a(mm*P+pp)));
                    end if;
                end loop;
            end loop;
        end if;
    end process;

    process (all)
        function make_exp(s: integer) return std_logic_vector is
            variable ret: std_logic_vector(B_DTW-1 downto 0);
            variable s_rl: real;
        begin
            s_rl := real(s);
            s_rl := s_rl/(2.0**SFT_NUM); -- shift
            s_rl := floor(s_rl + 0.5); -- round
            s_rl := maximum(-2.0**(B_DTW-1), s_rl); -- clip
            s_rl := minimum(2.0**(B_DTW-1)-1.0, s_rl); -- clip
            ret := std_logic_vector(to_signed(integer(s_rl), B_DTW));
            return ret;
        end function;
    begin
        for mm in 0 to M_P-1 loop
            for pp in 0 to P-1 loop
                exp(mm*P+pp) <= make_exp(sum(mm*P+pp));
            end loop;
        end loop;
    end process;

    process
        variable i_count: integer_vector(0 to M_P-1):=(others=>0);
        variable i_valid_val: std_logic;
        -- variable o_count: integer:= 0;
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for k in 0 to 100 loop

            o_ready <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
            for mm in 0 to M_P-1 loop
                if i_count(mm)<N_P then
                    i_valid_val := '1' when unsigned(rand_slv(2)) >= "01" else '0';
                    i_valid(mm) <= i_valid_val;
                    if i_valid_val='1' then
                        for pp in 0 to P-1 loop
                            a(mm*P+pp) <= rand_slv(A_DTW);
                        end loop;
                        i_count(mm) := i_count(mm) + 1;
                    end if;
                else
                    i_valid(mm) <= '0';
                end if;
            end loop;

            if o_count=M then
                clear <= '1';
                i_count := (others=>0);
            end if;
            wait_clock(clk, 1);
            wait for 1 ns;
            clear <= '0';
        end loop;

        wait_clock(clk, 5); -- wait clock rising, 5times
        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;

    process (clk)begin
        if rising_edge(clk) then
            if clear='1' then
                o_count <= 0;
            elsif o_ready='1' and o_valid='1' then
                o_count <= o_count + 1;
                for pp in 0 to P-1 loop
                    check(b(pp), exp(o_count*P+pp), "DATA" + (o_count*P+pp), True);
                end loop;
            end if;
        end if;
    end process;

    process(all) begin
        if(falling_edge(o_valid)=True) then
            assert o_ready='1'
            report "Valid Error"
            severity Error;
        end if;
    end process;

end architecture;
