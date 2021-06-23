-- 乗算
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
use work.str_lib.all;
use work.piping_pkg.all;

entity piping_mul is
    generic(
        N: positive:= 8;
        A_DTW: positive:= 8;
        B_DTW: positive:= 8;
        C_DTW: positive:= 8;
        SFT_NUM: natural := 4;
        MUL_NUM: positive:= 4
    );
    port(
        clk: in std_logic;
        rstn: in std_logic;

        i_valid: in sl_array_t(0 to N-1);
        i_ready: out sl_array_t(0 to N-1);
        o_valid: out sl_array_t(0 to N-1);
        o_ready: in sl_array_t(0 to N-1);

        a: in slv_array_t(0 to N-1)(A_DTW-1 downto 0);
        b: in slv_array_t(0 to N-1)(B_DTW-1 downto 0);
        c: out slv_array_t(0 to N-1)(C_DTW-1 downto 0)
    );
end entity;

architecture RTL of piping_mul is
    signal c_val: slv_array_t(0 to N-1)(C_DTW-1 downto 0);


    function mul_main(a, b: std_logic_vector) return std_logic_vector is
        variable v_a: signed(A_DTW-1 downto 0);
        variable v_b: signed(A_DTW-1 downto 0);
        variable v_mul: signed(A_DTW+B_DTW-1 downto 0);
        variable v_sft: signed(A_DTW+B_DTW-SFT_NUM-1 downto 0);
        variable v_ret: signed(C_DTW-1 downto 0);
    begin
        v_a := signed(a);
        v_b := signed(b);
        v_mul := f_mul(v_a,v_b);
        v_sft := v_mul when SFT_NUM=0 else f_round(v_mul, v_sft'length);
        v_ret := f_clip(v_sft, C_DTW);
        return std_logic_vector(v_ret);
    end function;


    signal selected_flag: std_logic_vector(N-1 downto 0):="10100101";

    signal mul_in_a: slv_array_t(0 to MUL_NUM-1)(A_DTW-1 downto 0);
    signal mul_in_b: slv_array_t(0 to MUL_NUM-1)(B_DTW-1 downto 0);
    signal mul_out: slv_array_t(0 to MUL_NUM-1)(C_DTW-1 downto 0);

    function sel_num(num: integer; sel: std_logic_vector) return integer is
        variable ret: integer:= -1;
    begin
        for i in 0 to num loop
            if sel(i)='1' then
                ret := ret + 1;
            end if;
        end loop;
        assert ret < MUL_NUM report "Error selcted_flag:" & to_str(sel, BIN) severity ERROR;
        return ret;
    end function;

begin

    process (all)begin
        for i in 0 to N-1 loop
            if selected_flag(i)='1' then
                print("SEL" / i / sel_num(i, selected_flag));
                mul_in_a(sel_num(i, selected_flag)) <= a(i);
                mul_in_b(sel_num(i, selected_flag)) <= b(i);
            end if;
        end loop;
    end process;

    process (all) begin
            for i in 0 to MUL_NUM-1 loop
                mul_out(i) <= mul_main(mul_in_a(i), mul_in_b(i));
            end loop;
    end process;

    process (clk, rstn) begin
        if rstn='0' then
            c_val <= (others=>(others => '0'));
        elsif rising_edge(clk) then
            for i in 0 to N-1 loop
                if selected_flag(i)='1' then
                    c_val(i) <= mul_out(sel_num(i, selected_flag));
                end if;
            end loop;
        end if;
    end process;

    c <= c_val;

end architecture;
