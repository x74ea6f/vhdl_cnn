
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

entity piping_conv_cal_tb1 is
    generic(
        P : positive := 1; -- Data Parallel
        M : positive := 28; -- Width
        N : positive := 28; -- Height
        IN_CH : positive := 1; -- Input Channnel
        OUT_CH : positive := 8; -- Output Channnel
        KERNEL_SIZE : positive := 3; -- Kernel Size
        IN_DTW : positive := 8+4; -- Data Width
        OUT_DTW : positive := 8+4; -- Data Width
        W_DTW : positive := 8 -- Data Width
    );
end entity;

architecture SIM of piping_conv_cal_tb1 is

    constant KERNEL_CENTER : positive := KERNEL_SIZE/2;

    function center_weight return slv_array_t is
        variable ret: slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * OUT_CH - 1)(W_DTW - 1 downto 0);
    begin
        for oc in 0 to OUT_CH-1 loop
        for i in 0 to KERNEL_SIZE-1 loop
        for j in 0 to KERNEL_SIZE-1 loop
            -- if i=2 and j=2 then
            -- if i=0 and j=0 then
            if i=KERNEL_CENTER and j=KERNEL_CENTER then
                ret(oc*KERNEL_SIZE*KERNEL_SIZE + i*KERNEL_SIZE+j) := (0=>'1', others=>'0');
                -- ret(oc*KERNEL_SIZE*KERNEL_SIZE + i*KERNEL_SIZE+j) := (oc=>'1', others=>'0');
            else
                ret(oc*KERNEL_SIZE*KERNEL_SIZE + i*KERNEL_SIZE+j) := (others=>'0');
            end if;
        end loop;
        end loop;
        end loop;
        return ret;
    end function;

    constant KERNEL_WEIGHT : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * OUT_CH - 1)(W_DTW - 1 downto 0) := center_weight;

    signal clk: std_logic := '0';
    signal rstn: std_logic := '0';
    signal i_valid : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal i_ready : sl_array_t(0 to 1 - 1);
    signal o_valid : sl_array_t(0 to 1 - 1);
    signal o_ready : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal a : slv_array_t(0 to IN_CH * P - 1)(IN_DTW - 1 downto 0):=(others=>(others=>'0'));
    -- signal a : slv_array_t(0 to KERNEL_SIZE * IN_CH * P - 1)(IN_DTW - 1 downto 0):=(others=>(others=>'0'));
    signal b : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0);
    signal exp : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0):=(others=>(others=>'0'));

    signal lbuf_o_valid : sl_array_t(0 to 1 - 1);
    signal lbuf_o_ready : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal lbuf_b : slv_array_t(0 to KERNEL_SIZE * IN_CH * P - 1)(OUT_DTW - 1 downto 0);

    signal buf_o_valid : sl_array_t(0 to 1 - 1);
    signal buf_o_ready : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal buf_b : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * IN_CH * P - 1)(OUT_DTW - 1 downto 0);

    signal b_pre : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0):=(others=>(others=>'1'));

begin
    piping_conv_line_buf: entity work.piping_conv_line_buf generic map(
        P => P,
        M => M,
        N => N,
        CH => IN_CH,
        KERNEL_SIZE => KERNEL_SIZE,
        DTW => IN_DTW
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => i_ready,
        i_valid => i_valid,
        o_ready => lbuf_o_ready,
        o_valid => lbuf_o_valid,
        a => a,
        b => lbuf_b
    );

    piping_conv_buf: entity work.piping_conv_buf generic map(
        P => P,
        M => M,
        N => N,
        CH => IN_CH,
        KERNEL_SIZE => KERNEL_SIZE,
        DTW => IN_DTW
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => lbuf_o_ready,
        i_valid => lbuf_o_valid,
        o_ready => buf_o_ready,
        o_valid => buf_o_valid,
        a => lbuf_b,
        b => buf_b
    );

    piping_conv_cal: entity work.piping_conv_cal generic map(
        P => P,
        M => M,
        N => N,
        IN_CH => IN_CH,
        OUT_CH => OUT_CH,
        KERNEL_SIZE => KERNEL_SIZE,
        IN_DTW => IN_DTW,
        OUT_DTW => OUT_DTW,
        W_DTW => W_DTW,
        KERNEL_WEIGHT => KERNEL_WEIGHT 
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => buf_o_ready,
        i_valid => buf_o_valid,
        o_ready => o_ready,
        o_valid => o_valid,
        a => buf_b,
        b => b
    );
    process begin
        make_clock(clk, 5 ns); -- 10ns clock
    end process;

    -- make expected data

    process
        variable dd: integer := 0;
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        dd := 0;
        while dd < M*N*IN_CH loop
        -- for k in 0 to M*N loop
            i_valid(0) <= '1' when unsigned(rand_slv(2)) >= "11" else '0';
            o_ready(0) <= '1' when unsigned(rand_slv(2)) >= "11" else '0';
            -- i_valid(0) <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
            -- o_ready(0) <= '1' when unsigned(rand_slv(2)) >= "01" else '0';
            -- i_valid(0) <= '1';
            -- o_ready(0) <= '1';

            for i in 0 to IN_CH-1 loop

                wait for 1 ns;
                if i_valid(0)='1' and i_ready(0)='1' then
                    for j in 0 to P-1 loop
                        a(i*P+j) <= std_logic_vector(to_signed(j*M+dd, IN_DTW));
                    end loop;
                    -- for j in 0 to KERNEL_SIZE*P-1 loop
                    --     a(i*(KERNEL_SIZE*P)+j) <= std_logic_vector(to_signed(j*M+dd-M, IN_DTW));
                    --     -- a(i*(KERNEL_SIZE*IN_CH*P)+j) <= std_logic_vector(to_unsigned((j*M+dd-M) mod (128), IN_DTW));
                    --     -- a(i*(KERNEL_SIZE*IN_CH*P)+j) <= (0=>rand_slv(1)(0), others=>'0');
                    -- end loop;
                    dd := dd+1;
                end if;
            end loop;

            wait_clock(clk, 1);
            wait for 1 ns;
        end loop;

        i_valid <= (others=>'0');
        -- o_ready <= (others=>'1');

        for i in 0 to M*8 loop
            o_ready(0) <= '1' when unsigned(rand_slv(2)) >= "11" else '0';
            wait_clock(clk, 1);
            wait for 1 ns;
        end loop;
        o_ready <= (others=>'1');

        wait_clock(clk, 50); -- wait clock rising, 5times
        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if o_valid(0)='1' and o_ready(0)='1' then
                print(to_str(b(0), DEC_S));
                check(signed(b(0))-signed(b_pre(0)), to_signed(1, OUT_DTW));
                b_pre <= b;
            end if;
        end if;
    end process;

    process(all) begin
        if(falling_edge(o_valid(0))=True) then
            assert o_ready(0)='1'
            report "Valid Error"
            severity Error;
        end if;
    end process;

end architecture;
