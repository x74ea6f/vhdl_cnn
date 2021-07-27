
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

entity piping_conv_cal_tb is
    generic(
        P : positive := 1; -- Data Parallel
        M : positive := 28; -- Width
        N : positive := 28; -- Height
        IN_CH : positive := 1; -- Input Channnel
        OUT_CH : positive := 4; -- Output Channnel
        KERNEL_SIZE : positive := 3; -- Kernel Size
        DTW : positive := 8 -- Data Width
    );
end entity;

architecture SIM of piping_conv_cal_tb is
    function int2mem(iv: integer_vector; DTW: positive) return slv_array_t is
        variable ret: slv_array_t(0 to iv'length-1)(DTW-1 downto 0);
    begin
        for i in 0 to iv'length-1 loop
            ret(i) := std_logic_vector(to_signed(iv(i), DTW));
        end loop;
        return ret;
    end function;

    constant KERNEL_WEIGHT_INT: integer_vector(0 to KERNEL_SIZE*KERNEL_SIZE*OUT_CH -1) := (
20,54,16,
-37,28,71,
-64,-75,-14,
13,2,57,
-9,33,103,
65,41,9,
-34,-3,45,
61,56,74,
124,127,96,
19,86,90,
82,65,84,
13,41,78
    );

    constant X_PRE_INT: integer_vector(0 to M*N*IN_CH -1) := (
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    );

    constant KERNEL_WEIGHT : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * OUT_CH - 1)(DTW - 1 downto 0) := int2mem(KERNEL_WEIGHT_INT, DTW);
    constant X_PRE : slv_array_t(0 to M*N*IN_CH - 1)(DTW - 1 downto 0) := int2mem(X_PRE_INT, DTW);


    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal i_valid : sl_array_t(0 to (IN_CH + P - 1)/P - 1);
    signal i_ready : sl_array_t(0 to (IN_CH + P - 1)/P - 1);
    signal o_valid : sl_array_t(0 to (OUT_CH + P - 1)/P - 1);
    signal o_ready : sl_array_t(0 to (OUT_CH + P - 1)/P - 1);
    signal a : slv_array_t(0 to KERNEL_SIZE * IN_CH * P - 1)(DTW - 1 downto 0):=(others=>(others=>'0'));
    signal b : slv_array_t(0 to OUT_CH * P - 1)(DTW - 1 downto 0);
    signal exp : slv_array_t(0 to OUT_CH * P - 1)(DTW - 1 downto 0):=(others=>(others=>'0'));



begin
    piping_conv_cal: entity work.piping_conv_cal generic map(
        P => P,
        M => M,
        N => N,
        IN_CH => IN_CH,
        OUT_CH => OUT_CH,
        KERNEL_SIZE => KERNEL_SIZE,
        DTW => DTW,
        KERNEL_WEIGHT => KERNEL_WEIGHT 
    )port map(
        clk => clk,
        rstn => rstn,
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

    -- make expected data

    process
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        for k in 0 to 100 loop

            for i in 0 to IN_CH-1 loop
                i_valid(i) <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
                o_ready(i) <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
                for j in 0 to KERNEL_SIZE*IN_CH*P-1 loop
                    a(i*(KERNEL_SIZE*IN_CH*P)+j) <= (0=>rand_slv(1)(0), others=>'0');
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
        if(falling_edge(o_valid(0))=True) then
            assert o_ready(0)='1'
            report "Valid Error"
            severity Error;
        end if;
    end process;

end architecture;