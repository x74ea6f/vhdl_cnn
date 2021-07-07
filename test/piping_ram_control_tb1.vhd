
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

entity piping_ram_control_tb1 is
    generic(
        P: positive:= 2; -- Data Parallel
        N: positive:= 8; -- N, Data Depth
        M: positive:= 8; -- MxN
        A_DTW: positive:= 8; -- Input/Output A Data Width
        ADR_DTW: positive:= 3 -- clog2(N/P)
    );
end entity;

architecture SIM of piping_ram_control_tb1 is
    constant M_P: positive := (M+P-1)/P;
    constant N_P: positive := (N+P-1)/P;

    signal clk: std_logic;
    signal rstn: std_logic;

    signal clear: std_logic:= '0';
    signal i_valid: std_logic:= '0';
    signal i_ready: std_logic;
    signal o_valid: sl_array_t(0 to M_P-1);
    signal o_ready: sl_array_t(0 to M_P-1):=(others=>'0');
    signal a: slv_array_t(0 to P-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal b: slv_array_t(0 to P-1)(A_DTW-1 downto 0):=(others=>(others=>'0'));
    signal c: slv_array_t(0 to M-1)(A_DTW-1 downto 0);

    signal ram_re: std_logic;
    signal ram_addr: std_logic_vector(ADR_DTW-1 downto 0);
    signal ram_rd: slv_array_t(0 to M-1)(A_DTW-1 downto 0);

    signal ram_ce: std_logic;
    signal ram_d: std_logic_vector(M*A_DTW-1 downto 0):=(others=>'0');
    signal ram_q: std_logic_vector(M*A_DTW-1 downto 0);
    signal ram_a: std_logic_vector(ADR_DTW-1 downto 0);

    signal ram_we: std_logic:= '0';
    signal ram_waddr: std_logic_vector(ADR_DTW-1 downto 0):=(others=>'0');

    function make_mem_init(constant DTW, DEPTH: positive) return mem_t is
        variable ret: mem_t(0 to DEPTH-1)(DTW-1 downto 0);
    begin
        for adr in 0 to DEPTH-1 loop
            for mm in 0 to M_P-1 loop
                for pp in 0 to P-1 loop
                    ret(adr)((mm*P+pp+1)*A_DTW-1 downto (mm*P+pp)*A_DTW) :=
                        std_logic_vector(to_unsigned(adr*M_P*P+mm*P+pp, A_DTW));
                end loop;
            end loop;
        end loop;
        return ret;
    end function;

begin
    piping_ram_control: entity work.piping_ram_control generic map(
        P => P,
        N => N,
        M => M,
        A_DTW => A_DTW,
        ADR_DTW => ADR_DTW
    )port map(
        clk => clk,
        rstn => rstn,

        clear => clear,
        i_valid => i_valid,
        i_ready => i_ready,
        o_valid => o_valid,
        o_ready => o_ready,
        a => a,
        b => b,
        c => c,

        ram_re => ram_re,
        ram_addr => ram_addr,
        ram_rd => ram_rd
    );

    w_raml: entity work.ram1rw generic map(
        DTW=>M*A_DTW,
        ADW=>ADR_DTW,
        DEPTH=>(N+P-1)/P,
        MEM_INIT=>make_mem_init(M*A_DTW, (N+P-1)/P)
    )port map(
        clk=>clk,
        ce=>ram_ce,
        we=>ram_we,
        a=>ram_a,
        d=>ram_d,
        q=>ram_q
    );

    process begin
        make_clock(clk, 5 ns); -- 10ns clock
    end process;


    process
    begin
        print("Hello world!");

        make_reset(rstn, clk, 5); -- reset
        wait_clock(clk, 5); -- wait clock rising, 5times

        -- -- Write RAM
        -- ram_we <= '1';
        -- for adr in 0 to 2**ADR_DTW-1 loop
        --     ram_waddr <= std_logic_vector(to_unsigned(adr, ADR_DTW));
        --     for mm in 0 to M-1 loop
        --         for pp in 0 to P-1 loop
        --             ram_d((mm*P+pp+1)*A_DTW-1 downto (mm*P+pp)*A_DTW) <=
        --                 std_logic_vector(to_unsigned(adr*M*P+mm*P+pp, A_DTW));
        --         end loop;
        --     end loop;
        --     wait_clock(clk, 1);
        -- end loop;
        -- ram_we <= '0';

        --
        for nn in 0 to N*10 loop
            i_valid <= rand_slv(1)(0);
            o_ready <= (others=>(rand_slv(1)(0)));
            for pp in 0 to P-1 loop
                a(pp) <= std_logic_vector(to_unsigned(nn, A_DTW));
            end loop;
            -- for mm in 0 to M-1 loop
            --     o_ready(mm) <= rand_slv(1)(0);
            -- end loop;
            wait_clock(clk, 1);
            wait for 1 ns;
        end loop;

        wait_clock(clk, 5); -- wait clock rising, 5times
        print("Finish @" + now); -- show Simulation time
        finish(0);
        wait;
    end process;

    process (clk)begin
        if rising_edge(clk) then
        end if;
    end process;

    -- RAM Q Data
    ram_ce <= ram_re or ram_we;
    ram_a <= ram_waddr when ram_we='1' else ram_addr;

    process (all) begin
        for mm in 0 to M_P-1 loop
            for pp in 0 to P-1 loop
                ram_rd(mm*P+pp) <= ram_q((mm*P+pp+1)*A_DTW-1 downto (mm*P+pp)*A_DTW);
            end loop;
        end loop;
    end process;

    process (clk) begin
        if rising_edge(clk) then
            for mm in 0 to M_P-1 loop
                if o_valid(mm)='1' and o_ready(mm)='1' then
                    print(to_str(mm) & ": ", False);
                    for pp in 0 to P-1 loop
                        print(to_str(c(mm*P+pp)) & ",", False);
                    end loop;
                    print("");
                end if;
            end loop;
        end if;
    end process;
    

    ASSERT_VALID: for mm in 0 to M_P-1 generate
        process(all) begin
            if falling_edge(o_valid(mm))=True then
                assert o_ready(mm)='1'
                report "Valid Error"
                severity Error;
            end if;
        end process;
    end generate;

end architecture;
