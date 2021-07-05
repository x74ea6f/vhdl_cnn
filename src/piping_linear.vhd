-- Linear Control
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_linear is
    generic(
        P: positive:= 4; -- Data Parallel
        N: positive:= 8*7*7/P; -- N, Data Depth
        M: positive:= 32; -- MxN
        A_DTW: positive:= 8; -- Input/Output A Data Width
        W_MEM_INIT: mem_t(0 to (N+P-1)/P-1)(P*M*A_DTW-1 downto 0) := (others=>(others=>'0'));
        B_MEM_INIT: mem_t(0 to (M+P-1)/P-1)(P*A_DTW-1 downto 0) := (others=>(others=>'0'))
    );
    port(
        clk: in std_logic;
        rstn: in std_logic;

        clear: in std_logic;
        i_valid: in std_logic;
        i_ready: out std_logic;
        o_valid: out std_logic;
        o_ready: in std_logic;

        a: in slv_array_t(0 to P-1)(A_DTW-1 downto 0);
        b: out slv_array_t(0 to P-1)(A_DTW-1 downto 0)
    );
end entity;

architecture RTL of piping_linear is

    constant NN: positive := clog2((N+P-1)/P);
    constant MM: positive := clog2((M+P-1)/P);
    constant MUL_NUM: positive:= 4;
    constant ADD_NUM: positive:= 1;

    signal w_ram_control_o_valid: sl_array_t(0 to M-1);
    signal w_ram_control_o_ready: sl_array_t(0 to M-1);
    signal w_ram_control_b: slv_array_t(0 to P-1)(A_DTW-1 downto 0);
    signal w_ram_control_c: slv_array_t(0 to P*M-1)(A_DTW-1 downto 0);

    signal w_ram_re: std_logic;
    signal w_ram_addr: std_logic_vector(NN-1 downto 0);
    signal w_ram_q: std_logic_vector(P*M*A_DTW-1 downto 0);
    signal w_ram_rd: slv_array_t(0 to P*M-1)(A_DTW-1 downto 0);

    signal mul_o_valid: sl_array_t(0 to M-1);
    signal mul_o_ready: sl_array_t(0 to M-1);
    signal mul_a: slv_array_t(0 to P*M-1)(A_DTW-1 downto 0);
    signal mul_c: slv_array_t(0 to P*M-1)(A_DTW-1 downto 0);

    signal sum_o_valid: std_logic;
    signal sum_o_ready: std_logic;
    signal sum_b: slv_array_t(0 to P-1)(A_DTW-1 downto 0);

    signal b_ram_control_o_valid: sl_array_t(0 to 0);
    signal b_ram_control_o_ready: sl_array_t(0 to 0);
    signal b_ram_control_b: slv_array_t(0 to P-1)(A_DTW-1 downto 0);
    signal b_ram_control_c: slv_array_t(0 to P-1)(A_DTW-1 downto 0);

    signal b_ram_re: std_logic;
    signal b_ram_addr: std_logic_vector(MM-1 downto 0);
    signal b_ram_q: std_logic_vector(P*1*A_DTW-1 downto 0);
    signal b_ram_rd: slv_array_t(0 to P*1-1)(A_DTW-1 downto 0);

    signal add_o_valid: sl_array_t(0 to 1-1);
    signal add_o_ready: sl_array_t(0 to 1-1);

begin

    w_ram_control: entity work.piping_ram_control generic map(
        P => P,
        N => N,
        M => M,
        A_DTW => A_DTW,
        ADR_DTW => NN
    )port map(
        clk => clk,
        rstn => rstn,

        clear => clear,
        i_valid => i_valid,
        i_ready => i_ready,
        o_valid => w_ram_control_o_valid,
        o_ready => w_ram_control_o_ready,
        a => a,
        b => w_ram_control_b,
        c => w_ram_control_c,

        ram_re => w_ram_re,
        ram_addr => w_ram_addr,
        ram_rd => w_ram_rd
    );

    w_ram: entity work.ram1rw generic map(
        DTW=>P*M*A_DTW,
        ADW=>NN,
        DEPTH=>(N+P-1)/P,
        MEM_INIT=>W_MEM_INIT
    )port map(
        clk=>clk,
        ce=>w_ram_re,
        we=>'0',
        a=>w_ram_addr,
        d=>(others=>'0'),
        q=>w_ram_q
    );

    process (all) begin
        for mm in 0 to m-1 loop
            for pp in 0 to p-1 loop
                w_ram_rd(mm*p+pp) <= w_ram_q((mm*p+pp+1)*a_dtw-1 downto (mm*p+pp)*a_dtw);
                mul_a(mm*p+pp) <= w_ram_control_b(pp);
            end loop;
        end loop;
    end process;

    piping_mul: entity work.piping_mul generic map(
        P=>P,
        N=>M,
        A_DTW=>A_DTW,
        B_DTW=>A_DTW,
        C_DTW=>A_DTW,
        CAL_NUM=>MUL_NUM,
        SFT_NUM=>0
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => w_ram_control_o_ready,
        i_valid => w_ram_control_o_valid,
        o_ready => mul_o_ready,
        o_valid => mul_o_valid,
        a => mul_a,
        b => w_ram_control_c,
        c => mul_c
    );

    piping_sum: entity work.piping_sum generic map(
        P=>P,
        M=>M,
        N=>N,
        AB_DTW=>A_DTW,
        SFT_NUM=>0
    )port map(
        clk => clk,
        rstn => rstn,
        clear => clear,
        i_ready => mul_o_ready,
        i_valid => mul_o_valid,
        o_ready => sum_o_ready,
        o_valid => sum_o_valid,
        a => mul_c,
        b => sum_b
    );

    b_ram_control: entity work.piping_ram_control generic map(
        P => P,
        N => M,
        M => 1,
        A_DTW => A_DTW,
        ADR_DTW => MM
    )port map(
        clk => clk,
        rstn => rstn,

        clear => clear,
        i_valid => sum_o_valid,
        i_ready => sum_o_ready,
        o_valid => b_ram_control_o_valid,
        o_ready => b_ram_control_o_ready,
        a => sum_b,
        b => b_ram_control_b,
        c => b_ram_control_c,

        ram_re => b_ram_re,
        ram_addr => b_ram_addr,
        ram_rd => b_ram_rd
    );

    b_ram: entity work.ram1rw generic map(
        DTW=>P*A_DTW,
        ADW=>MM,
        DEPTH=>(M+P-1)/P,
        MEM_INIT=>B_MEM_INIT
    )port map(
        clk=>clk,
        ce=>b_ram_re,
        we=>'0',
        a=>b_ram_addr,
        d=>(others=>'0'),
        q=>b_ram_q
    );

    process (all) begin
        for mm in 0 to 1-1 loop
            for pp in 0 to p-1 loop
                b_ram_rd(mm*p+pp) <= b_ram_q((mm*p+pp+1)*a_dtw-1 downto (mm*p+pp)*a_dtw);
            end loop;
        end loop;
    end process;

    piping_add: entity work.piping_add generic map(
        P=>P,
        N=>1,
        A_DTW=>A_DTW,
        B_DTW=>A_DTW,
        C_DTW=>A_DTW,
        CAL_NUM=>ADD_NUM,
        SFT_NUM=>0
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => b_ram_control_o_ready,
        i_valid => b_ram_control_o_valid,
        o_ready => add_o_ready,
        o_valid => add_o_valid,
        a => b_ram_control_b,
        b => b_ram_control_c,
        c => b
    );

    add_o_ready(0) <= o_ready;
    o_valid <= add_o_valid(0);


end architecture;
