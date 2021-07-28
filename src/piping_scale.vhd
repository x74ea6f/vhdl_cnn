-- Scaling
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
use work.str_lib.all;

entity piping_scale is
    generic (
        P : positive := 1; -- Data Parallel
        N : positive := 1; -- 
        A_DTW : positive := 8; -- Input A Data Width
        B_DTW : positive := 8; -- Input B Data Width
        SCALE_DTW: positive := 8; -- Scale Width
        SCALE : positive := 2; -- Constant Scale(0 to 255)
        SFT_NUM : positive := 1; -- Shift
        OUT_UNSIGNED : boolean := True
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to (N + P - 1)/P - 1);
        i_ready : out sl_array_t(0 to (N + P - 1)/P - 1);
        o_valid : out sl_array_t(0 to (N + P - 1)/P - 1);
        o_ready : in sl_array_t(0 to (N + P - 1)/P - 1);

        a : in slv_array_t(0 to N * P - 1)(A_DTW - 1 downto 0);
        b : out slv_array_t(0 to N * P - 1)(B_DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_scale is
    constant N_P : positive := (N + P - 1)/P;

    signal b_val : slv_array_t(0 to N * P - 1)(B_DTW - 1 downto 0);
    signal o_valid_val : sl_array_t(0 to N_P - 1);

    -- 計算メイン処理
    function cal_main(a : std_logic_vector) return std_logic_vector is
        variable v_a : signed(A_DTW - 1 downto 0);
        variable v_scale : unsigned(SCALE_DTW-1 downto 0);
        variable v_cal : signed(A_DTW + SCALE_DTW - 1 downto 0);
        variable v_sft : signed(A_DTW + SCALE_DTW - SFT_NUM - 1 downto 0);
        variable v_ret : signed(B_DTW - 1 downto 0);
    begin
        v_a := signed(a);
        v_scale := to_unsigned(SCALE, SCALE_DTW);
        v_cal := f_mul(v_a, v_scale);
        v_sft := v_cal when SFT_NUM = 0 else
            f_round(v_cal, v_sft'length);
        if (A_DTW + SCALE_DTW - SFT_NUM > B_DTW) then
            v_ret := f_clip(v_sft, B_DTW);
        else
            v_ret := resize(v_sft, B_DTW);
        end if;
        return std_logic_vector(v_ret);
    end function;

    --[TODO] ここのビット幅計算怪しい
    function cal_main_unsigned(a : std_logic_vector) return std_logic_vector is
        variable v_a : signed(A_DTW - 1 downto 0);
        variable v_aa : unsigned(A_DTW - 2 downto 0);
        variable v_scale : unsigned(SCALE_DTW-1 downto 0);
        variable v_cal : unsigned(A_DTW + SCALE_DTW - 2 downto 0);
        variable v_sft : unsigned(A_DTW + SCALE_DTW - SFT_NUM - 2 downto 0);
        variable v_ret : unsigned(B_DTW - 1 downto 0);
    begin
        v_a := maximum(to_signed(0, A_DTW), signed(a));
        v_aa := unsigned(v_a(A_DTW - 2 downto 0));
        v_scale := to_unsigned(SCALE, SCALE_DTW);
        v_cal := f_mul(v_aa, v_scale);
        v_sft := v_cal when SFT_NUM = 0 else
            f_round(v_cal, v_sft'length);
        if (A_DTW + SCALE_DTW - SFT_NUM > B_DTW) then
            v_ret := f_clip(v_sft, B_DTW);
        else
            v_ret := resize(v_sft, B_DTW);
        end if;
        return std_logic_vector(v_ret);
    end function;
begin

    process (clk, rstn) begin
        if rstn = '0' then
            b_val <= (others => (others => '0'));
            o_valid_val <= (others => '0');
        elsif rising_edge(clk) then
            for nn in 0 to N - 1 loop
                if o_valid_val(nn)='0' or o_ready(nn)='1' then
                    o_valid_val(nn) <= i_valid(nn);
                    for pp in 0 to P - 1 loop
                        b_val(nn * P + pp) <= cal_main_unsigned(a(nn * P + pp)) when OUT_UNSIGNED = True else
                        cal_main(a(nn * P + pp));
                    end loop;
                end if;
            end loop;
        end if;
    end process;

    o_valid <= o_valid_val;
    b <= b_val;
    i_ready <= (not o_valid_val) or o_ready;

end architecture;