-- 
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_conv_cal is
    generic (
        P : positive := 1; -- Data Parallel
        M : positive := 28; -- Width
        N : positive := 28; -- Height
        IN_CH : positive := 1; -- Input Channnel
        OUT_CH : positive := 4; -- Output Channnel
        KERNEL_SIZE : positive := 3; -- Kernel Size
        DTW : positive := 8; -- Data Width
        MUL_NUM : positive := 4; -- Calc Number
        KERNEL_WEIGHT : mem_t(0 to KERNEL_SIZE*KERNEL_SIZE*OUT_CH- 1)(DTW - 1 downto 0) := (others => (others => '0'));
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to (IN_CH + P - 1)/P - 1);
        i_ready : out sl_array_t(0 to (IN_CH + P - 1)/P - 1);
        o_valid : out sl_array_t(0 to (OUT_CH + P - 1)/P - 1);
        o_ready : in sl_array_t(0 to (OUT_CH + P - 1)/P - 1);

        a : in slv_array_t(0 to IN_CH*P - 1)(DTW - 1 downto 0);
        b : out slv_array_t(0 to OUT_CH*P - 1)(DTW - 1 downto 0);
    );
end entity;

architecture RTL of piping_conv_cal is

    constant M_P : positive := (M + P - 1)/P;
    constant M_P_LEN: positive := clog2(M_P);
    constant N_LEN : positive := clog2(N);

    signal w_pix_count: std_logic_vector(M_P_LEN-1 downto 0);
    signal w_line_count: std_logic_vector(N_P_LEN-1 downto 0);

    signal a_dly : slv_array_t(0 to KERNEL_SIZE*IN_CH*P*-1)(DTW - 1 downto 0);

begin
    -- Line Counter
    -- Pix Counter

    -- Line Buffer
    G_LBUF : for i in 0 to KERNEL_SIZE generate
        -- Line Buffer
        lbuf : entity work.ram1rw generic map(
            DTW => IN_CH*P*DTW,
            ADW => M_P_LEN,
            DEPTH => M_P,
            MEM_INIT => (others=>(others=>'0'))
        )port map(
            clk => clk,
            ce => w_ram_ce[i],
            we => w_ram_we[i],
            a => w_ram_addr,
            d => w_ram_d,
            q => w_ram_q[i]
        );
    end generate

    -- Kernel Multiplier

end architecture;
