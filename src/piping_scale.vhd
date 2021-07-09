-- Scaling
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_scale is
    generic(
        P: positive:= 1; -- Data Parallel
        N: positive:= 1; -- 
        A_DTW: positive:= 8; -- Input A Data Width
        B_DTW: positive:= 8; -- Input B Data Width
        SCALE: positive:= 2; -- 0 to 255
        SFT_NUM: positive:= 1 -- Shift
    );
    port(
        clk: in std_logic;
        rstn: in std_logic;

        i_valid: in sl_array_t(0 to (N+P-1)/P-1);
        i_ready: out sl_array_t(0 to (N+P-1)/P-1);
        o_valid: out sl_array_t(0 to (N+P-1)/P-1);
        o_ready: in sl_array_t(0 to (N+P-1)/P-1);

        a: in slv_array_t(0 to N-1)(A_DTW-1 downto 0);
        b: out slv_array_t(0 to N-1)(B_DTW-1 downto 0)
    );
end entity;

architecture RTL of piping_scale is
    constant N_P: positive := (N+P-1)/P;

    signal b_val: slv_array_t(0 to N-1)(B_DTW-1 downto 0);
    signal i_ready_val: sl_array_t(0 to N_P-1);
    signal o_valid_val: sl_array_t(0 to N_P-1);

    -- 計算メイン処理
    function cal_main(a: std_logic_vector) return std_logic_vector is
        constant O_DTW: positive := maximum(a'length, b'length) + 1;
        variable v_a: signed(A_DTW-1 downto 0);
        variable v_scale: unsigned(7 downto 0);
        variable v_cal: signed(A_DTW+8-1 downto 0);
        variable v_sft: signed(A_DTW+8-SFT_NUM-1 downto 0);
        variable v_ret: signed(B_DTW-1 downto 0);
    begin
        v_a := signed(a);
        v_scale := to_unsigned(SCALE, 8);
        v_cal := f_mul(v_a, v_scale);
        v_sft := v_cal when SFT_NUM=0 else f_round(v_cal, v_sft'length);
        v_ret := f_clip(v_sft, B_DTW);
        return std_logic_vector(v_ret);
    end function;

begin

    process (clk, rstn) begin
        if rstn='0' then
            b_val <= (others=>(others => '0'));
            o_valid_val <= (others=>'0');
        elsif rising_edge(clk) then
            o_valid_val <= i_valid;
            for pp in 0 to P-1 loop
                b_val(pp) <= cal_main(a(pp));
            end loop;
        end if;
    end process;

    i_ready_val <= o_ready;

    o_valid <= o_valid_val;
    b <= b_val;
    i_ready <= i_ready_val;

end architecture;
