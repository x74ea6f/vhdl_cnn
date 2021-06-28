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

    constant NN: positive := clog2(N);

    signal c_val: slv_array_t(0 to N-1)(C_DTW-1 downto 0);
    signal i_ready_val: sl_array_t(0 to N-1);
    signal o_valid_val: sl_array_t(0 to N-1);

    signal mul_in_a: slv_array_t(0 to MUL_NUM-1)(A_DTW-1 downto 0);
    signal mul_in_b: slv_array_t(0 to MUL_NUM-1)(B_DTW-1 downto 0);
    signal mul_out: slv_array_t(0 to MUL_NUM-1)(C_DTW-1 downto 0);

    -- 計算メイン処理
    -- 乗算・丸め・クリップ
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

    -- 関数から両方returnしたいけど１つしか返せないので結合しalias。
    -- signal selected_flag: std_logic_vector(N-1 downto 0):="10100101";
    -- signal last_sel: std_logic_vector(NN-1 to 0);
    signal select_combination: std_logic_vector(N+NN-1 downto 0);
    alias selected_flag: std_logic_vector(N-1 downto 0) is select_combination(N-1 downto 0);
    alias last_sel: std_logic_vector(NN-1 downto 0) is select_combination(N+NN-1 downto N);

    signal select_combination_pre: std_logic_vector(N+NN-1 downto 0);
    alias selected_flag_pre: std_logic_vector(N-1 downto 0) is select_combination_pre(N-1 downto 0);
    alias last_sel_pre: std_logic_vector(NN-1 downto 0) is select_combination_pre(N+NN-1 downto N);

    signal tran_ok: sl_array_t(0 to N-1);

    -- いわゆるアービター
    -- 現在の最終番号から走査して、trans_okなところをMUL_NUM個選択。
    function next_select(now_select_combination: std_logic_vector; tran_ok: sl_array_t) return std_logic_vector is
        alias now_selected_flag: std_logic_vector(N-1 downto 0) is now_select_combination(N-1 downto 0);
        alias now_last_sel: std_logic_vector(NN-1 downto 0) is now_select_combination(N+NN-1 downto N);
        variable next_select_combination: std_logic_vector(N+NN-1 downto 0);
        alias next_selected_flag: std_logic_vector(N-1 downto 0) is next_select_combination(N-1 downto 0);
        alias next_last_sel: std_logic_vector(NN-1 downto 0) is next_select_combination(N+NN-1 downto N);

        variable idx: integer;
        variable choice_num: integer:= 0;
    begin
        next_last_sel := now_last_sel;
        for i in 0 to N-1 loop
            idx := (i + to_integer(unsigned(now_last_sel)) + 1) mod N;
            if choice_num < MUL_NUM then
                if  tran_ok(idx)='1' then
                    next_selected_flag(idx) := '1';
                    next_last_sel := std_logic_vector(to_unsigned(idx, NN));
                    choice_num := choice_num + 1;
                else
                    next_selected_flag(idx) := '0';
                end if;
            else
                next_selected_flag(idx) := '0';
            end if;
        end loop;
        return next_select_combination;
    end function;
    -- MUL(num)に入力の何番目を接続するか?
    -- selのnum番目の1は、何ビット目か?(ret=0~N-1)
    -- eg: sel=00110011: num,ret=0,0; 1,1; 2,4; 3,5;
    function sel_num_in(constant num: integer; sel: std_logic_vector) return integer is
        variable inc: integer:=0;
        variable ret: integer;
    begin
        ret := num; -- default
        for i in 0 to N-1 loop
            if sel(i)='1' then
                if inc = num then
                    ret := i;
                end if;
                inc := inc + 1;
            end if;
        end loop;
        return ret;
    end function;

    -- MUL(num)に出力の何番目を接続するか?
    -- selのnumビット目は、何番目の1か?(ret=0~N-1)
    -- eg: sel=00110011: num,ret=0,0; 1,1; 4,2; 5,3;
    function sel_num(constant num: integer; sel: std_logic_vector) return integer is
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

    tran_ok <= i_valid and o_ready;
    select_combination <= next_select(select_combination_pre, tran_ok);

    process (clk, rstn) begin
        if rstn='0' then
            selected_flag_pre <= (others=>'0');
            last_sel_pre <= std_logic_vector(to_unsigned(N-1, NN)); -- for first 0
        elsif rising_edge(clk) then
            selected_flag_pre <= selected_flag;
            last_sel_pre <= last_sel;
        end if;
    end process;

    --[TODO] mul_in_a is latch
    -- process (all)begin
    --     for i in 0 to N-1 loop
    --         if selected_flag(i)='1' then
    --             print("SEL" / i / sel_num(i, selected_flag));
    --             mul_in_a(sel_num(i, selected_flag)) <= a(i);
    --             mul_in_b(sel_num(i, selected_flag)) <= b(i);
    --         end if;
    --     end loop;
    -- end process;

    process (all)begin
        for i in 0 to MUL_NUM-1 loop
            -- print("SEL" / i / selected_flag / sel_num_in(i, selected_flag));
            mul_in_a(i) <= a(sel_num_in(i, selected_flag));
            mul_in_b(i) <= b(sel_num_in(i, selected_flag));
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

    process (all) begin
        for i in 0 to N-1 loop
            i_ready_val(i) <= selected_flag(i);
        end loop;
    end process;

    i_ready <= i_ready_val;

    process (clk, rstn) begin
        if rstn='0' then
            o_valid_val <= (others=>'0');
        elsif rising_edge(clk) then
            for i in 0 to N-1 loop
                o_valid_val(i) <= selected_flag(i);
            end loop;
        end if;
    end process;

    o_valid <= o_valid_val;

end architecture;
