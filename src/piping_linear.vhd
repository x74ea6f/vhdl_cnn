-- Linear Control
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_linear is
    generic (
        P : positive := 4; -- Data Parallel
        N : positive := 8 * 7 * 7; -- N, Data Depth
        M : positive := 32; -- MxN
        A_DTW : positive := 8; -- Input/Output A Data Width
        MUL_NUM : positive := 4; -- Number of Multiplier = MUL_NUM*P
        W_MEM_INIT : mem_t(0 to (N + P - 1)/P - 1)(P * M * A_DTW - 1 downto 0) := (others => (others => '0'));
        B_MEM_INIT : mem_t(0 to (M + P - 1)/P - 1)(P * A_DTW - 1 downto 0) := (others => (others => '0'));
        SCALE : positive := 2; -- 0 to 255
        SCALE_SFT : positive := 1 -- Shift
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        clear : in std_logic;
        i_valid : in std_logic;
        i_ready : out std_logic;
        o_valid : out std_logic;
        o_ready : in std_logic;

        a : in slv_array_t(0 to P - 1)(A_DTW - 1 downto 0);
        b : out slv_array_t(0 to P - 1)(A_DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_linear is
    constant M_P : positive := (M + P - 1)/P;
    constant N_P : positive := (N + P - 1)/P;
    constant MUL_DTW : positive := A_DTW * 2 - 1;
    constant SUM_DTW : positive := A_DTW * 2 - 1;

    constant W_RAM_ADW : positive := clog2(N_P);
    constant B_RAM_ADW : positive := clog2(M_P);

    signal w_ram_control_o_valid : sl_array_t(0 to M - 1);
    signal w_ram_control_o_ready : sl_array_t(0 to M - 1);
    signal w_ram_control_b : slv_array_t(0 to P - 1)(A_DTW - 1 downto 0);
    signal w_ram_control_c : slv_array_t(0 to P*M - 1)(A_DTW - 1 downto 0);

    signal w_ram_re : std_logic;
    signal w_ram_addr : std_logic_vector(W_RAM_ADW - 1 downto 0);
    signal w_ram_q : std_logic_vector(P*M * A_DTW - 1 downto 0);
    signal w_ram_rd : slv_array_t(0 to P*M - 1)(A_DTW - 1 downto 0);

    signal mul_o_valid : sl_array_t(0 to M - 1);
    signal mul_o_ready : sl_array_t(0 to M - 1);
    signal mul_a : slv_array_t(0 to P*M - 1)(A_DTW - 1 downto 0);
    signal mul_c : slv_array_t(0 to P*M - 1)(MUL_DTW - 1 downto 0);

    signal sum_o_valid : std_logic;
    signal sum_o_ready : std_logic;
    signal sum_b : slv_array_t(0 to P - 1)(SUM_DTW - 1 downto 0);

    signal b_ram_control_o_valid : sl_array_t(0 to 0);
    signal b_ram_control_o_ready : sl_array_t(0 to 0);
    signal b_ram_control_b : slv_array_t(0 to P - 1)(SUM_DTW - 1 downto 0);
    signal b_ram_control_c : slv_array_t(0 to P - 1)(A_DTW - 1 downto 0);

    signal b_ram_re : std_logic;
    signal b_ram_addr : std_logic_vector(B_RAM_ADW - 1 downto 0);
    signal b_ram_q : std_logic_vector(P * 1 * A_DTW - 1 downto 0);
    signal b_ram_rd : slv_array_t(0 to P * 1 - 1)(A_DTW - 1 downto 0);

    signal add_o_valid : sl_array_t(0 to 1 - 1);
    signal add_o_ready : sl_array_t(0 to 1 - 1);
    signal add_c : slv_array_t(0 to P - 1)(SUM_DTW - 1 downto 0);

    signal scale_o_valid : sl_array_t(0 to 1 - 1);
    signal scale_o_ready : sl_array_t(0 to 1 - 1);
begin

    -- W RAM Read
    w_ram_control : entity work.piping_ram_control generic map(
        P => P,
        N => N,
        M => M,
        AB_DTW => A_DTW,
        C_DTW => A_DTW,
        ADR_DTW => W_RAM_ADW
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

    -- W RAM
    w_ram : entity work.ram1rw generic map(
        DTW => P * M * A_DTW,
        ADW => W_RAM_ADW,
        DEPTH => N_P,
        MEM_INIT => W_MEM_INIT
        )port map(
        clk => clk,
        ce => w_ram_re,
        we => '0',
        a => w_ram_addr,
        d => (others => '0'),
        q => w_ram_q
        );

    -- Convert RAM to MUL
    process (all) begin
        for mm in 0 to M - 1 loop
            for pp in 0 to P - 1 loop
                w_ram_rd(mm * P + pp) <= w_ram_q((mm * P + pp + 1) * A_DTW - 1 downto (mm * P + pp) * A_DTW);
                mul_a(mm * P + pp) <= w_ram_control_b(pp);
            end loop;
        end loop;
    end process;

    -- Mul of W*X
    piping_mul : entity work.piping_mul generic map(
        P => P,
        N => M*P,
        A_DTW => A_DTW,
        B_DTW => A_DTW,
        C_DTW => MUL_DTW,
        CAL_NUM => MUL_NUM,
        SFT_NUM => 0
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

    -- Sum of W*X
    piping_sum : entity work.piping_sum generic map(
        P => P,
        M => M,
        N => N,
        A_DTW => MUL_DTW,
        B_DTW => SUM_DTW,
        SFT_NUM => 0
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

    -- B RAM Read
    b_ram_control : entity work.piping_ram_control generic map(
        P => P,
        N => M,
        M => 1,
        AB_DTW => SUM_DTW,
        C_DTW => A_DTW,
        ADR_DTW => B_RAM_ADW
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

    -- B RAM
    b_ram : entity work.ram1rw generic map(
        DTW => P * A_DTW,
        ADW => B_RAM_ADW,
        DEPTH => M_P,
        MEM_INIT => B_MEM_INIT
        )port map(
        clk => clk,
        ce => b_ram_re,
        we => '0',
        a => b_ram_addr,
        d => (others => '0'),
        q => b_ram_q
        );

    process (all) begin
        for mm in 0 to 1 - 1 loop
            for pp in 0 to P - 1 loop
                b_ram_rd(mm * P + pp) <= b_ram_q((mm * P + pp + 1) * A_DTW - 1 downto (mm * P + pp) * A_DTW);
            end loop;
        end loop;
    end process;

    -- +B
    piping_add : entity work.piping_add generic map(
        P => P,
        N => P,
        A_DTW => SUM_DTW,
        B_DTW => A_DTW,
        C_DTW => SUM_DTW,
        CAL_NUM => 1,
        SFT_NUM => 0
        )port map(
        clk => clk,
        rstn => rstn,
        i_ready => b_ram_control_o_ready,
        i_valid => b_ram_control_o_valid,
        o_ready => add_o_ready,
        o_valid => add_o_valid,
        a => b_ram_control_b,
        b => b_ram_control_c,
        c => add_c
        );

    -- Scaling
    piping_scale : entity work.piping_scale generic map(
        P => P,
        N => P,
        A_DTW => SUM_DTW,
        B_DTW => A_DTW,
        SCALE => SCALE,
        SFT_NUM => SCALE_SFT
        )port map(
        clk => clk,
        rstn => rstn,
        i_ready => add_o_ready,
        i_valid => add_o_valid,
        o_ready => scale_o_ready,
        o_valid => scale_o_valid,
        a => add_c,
        b => b
        );

    scale_o_ready(0) <= o_ready;
    o_valid <= scale_o_valid(0);
end architecture;