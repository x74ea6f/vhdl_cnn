-- 
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_conv is
    generic (
        P : positive := 1; -- Data Parallel
        M : positive := 28; -- Width
        N : positive := 28; -- Height
        IN_CH : positive := 1; -- Input Channnel
        OUT_CH : positive := 4; -- Output Channnel
        KERNEL_SIZE : positive := 3; -- Kernel Size
        DTW : positive := 8; -- Data Width
        CAL_DTW: positive := 8+4; -- Calc sum Data Width
        W_DTW: positive := 8; -- Weight Data Width
        KERNEL_WEIGHT : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * OUT_CH - 1)(W_DTW - 1 downto 0) := (others=>(others=>'0'))
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to 1 - 1);
        i_ready : out sl_array_t(0 to 1 - 1);
        o_valid : out sl_array_t(0 to 1 - 1);
        o_ready : in sl_array_t(0 to 1 - 1);

        a : in slv_array_t(0 to IN_CH*P - 1)(DTW - 1 downto 0);
        b : out slv_array_t(0 to OUT_CH*P - 1)(DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_conv is
    signal lbuf_o_valid : sl_array_t(0 to 1 - 1);
    signal lbuf_o_ready : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal lbuf_b : slv_array_t(0 to KERNEL_SIZE * IN_CH * P - 1)(DTW - 1 downto 0);

    signal buf_o_valid : sl_array_t(0 to 1 - 1);
    signal buf_o_ready : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal buf_b : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * IN_CH * P - 1)(DTW - 1 downto 0);

    signal cal_o_valid : sl_array_t(0 to 1 - 1);
    signal cal_o_ready : sl_array_t(0 to 1 - 1) := (others=>'0');
    signal cal_b : slv_array_t(0 to OUT_CH * P - 1)(CAL_DTW - 1 downto 0);

begin
    piping_conv_line_buf: entity work.piping_conv_line_buf generic map(
        P => P,
        M => M,
        N => N,
        CH => IN_CH,
        KERNEL_SIZE => KERNEL_SIZE,
        DTW => DTW
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
        DTW => DTW
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
        IN_DTW => DTW,
        OUT_DTW => CAL_DTW,
        W_DTW => W_DTW,
        KERNEL_WEIGHT => KERNEL_WEIGHT 
    )port map(
        clk => clk,
        rstn => rstn,
        i_ready => buf_o_ready,
        i_valid => buf_o_valid,
        o_ready => cal_o_ready,
        o_valid => cal_o_valid,
        a => buf_b,
        b => cal_b
    );


    piping_scale: entity work.piping_scale generic map(
        P => OUT_CH,
        N => 1,
        A_DTW => CAL_DTW,
        B_DTW => DTW,
        SCALE_DTW => 10,
        SCALE => 531,
        SFT_NUM => 16,
        OUT_UNSIGNED => True
    ) port map(
        clk => clk,
        rstn => rstn,

        i_valid => cal_o_valid,
        i_ready => cal_o_ready,
        o_valid => o_valid,
        o_ready => o_ready,

        a => cal_b,
        b => b
    );

end architecture;
