-- 加算
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_add is
    generic(
        P: positive:= 1; -- Data Parallel
        N: positive:= 8; -- Input/Output Number
        A_DTW: positive:= 8; -- Input A Data Width
        B_DTW: positive:= 8; -- Input B Data Width
        C_DTW: positive:= 8; -- Output C Data Width
        CAL_NUM: positive:= 4; -- Calc Number
        SFT_NUM: natural := 1 -- Shift Number
    );
    port(
        clk: in std_logic;
        rstn: in std_logic;

        i_valid: in sl_array_t(0 to (N+P-1)/P-1);
        i_ready: out sl_array_t(0 to (N+P-1)/P-1);
        o_valid: out sl_array_t(0 to (N+P-1)/P-1);
        o_ready: in sl_array_t(0 to (N+P-1)/P-1);

        a: in slv_array_t(0 to N-1)(A_DTW-1 downto 0);
        b: in slv_array_t(0 to N-1)(B_DTW-1 downto 0);
        c: out slv_array_t(0 to N-1)(C_DTW-1 downto 0)
    );
end entity;

architecture RTL of piping_add is

    constant NN: positive := clog2(N);
    constant N_P: positive := (N+P-1)/P;

    signal c_val: slv_array_t(0 to N-1)(C_DTW-1 downto 0);
    signal i_ready_val: sl_array_t(0 to N_P-1);
    signal o_valid_val: sl_array_t(0 to N_P-1);

    signal cal_in_a: slv_array_t(0 to P*CAL_NUM-1)(A_DTW-1 downto 0);
    signal cal_in_b: slv_array_t(0 to P*CAL_NUM-1)(B_DTW-1 downto 0);
    signal cal_out: slv_array_t(0 to P*CAL_NUM-1)(C_DTW-1 downto 0);

    -- 計算メイン処理
    function cal_main(a, b: std_logic_vector) return std_logic_vector is
        constant O_DTW: positive := maximum(a'length, b'length) + 1;
        variable v_a: signed(A_DTW-1 downto 0);
        variable v_b: signed(B_DTW-1 downto 0);
        variable v_cal: signed(O_DTW-1 downto 0);
        variable v_sft: signed(O_DTW-SFT_NUM-1 downto 0);
        variable v_ret: signed(C_DTW-1 downto 0);
    begin
        v_a := signed(a);
        v_b := signed(b);
        v_cal := f_add(v_a,v_b);
        v_sft := v_cal when SFT_NUM=0 else f_round(v_cal, v_sft'length);
        v_ret := f_clip(v_sft, C_DTW);
        return std_logic_vector(v_ret);
    end function;

    -- 関数から両方returnしたいけど１つしか返せないので結合しalias。
    -- signal selected_flag: std_logic_vector(N_P-1 downto 0):="10100101";
    -- signal last_sel: std_logic_vector(NN-1 to 0);
    signal select_combination: std_logic_vector(N_P+NN-1 downto 0);
    alias selected_flag: std_logic_vector(N_P-1 downto 0) is select_combination(N_P-1 downto 0);
    alias last_sel: std_logic_vector(NN-1 downto 0) is select_combination(N_P+NN-1 downto N_P);

    signal select_combination_pre: std_logic_vector(N_P+NN-1 downto 0);
    alias selected_flag_pre: std_logic_vector(N_P-1 downto 0) is select_combination_pre(N_P-1 downto 0);
    alias last_sel_pre: std_logic_vector(NN-1 downto 0) is select_combination_pre(N_P+NN-1 downto N_P);

    signal tran_ok: sl_array_t(0 to N_P-1);

    -- いわゆるアービター
    -- 現在の最終番号から走査して、trans_okなところをCAL_NUM個選択。
    function next_select(now_select_combination: std_logic_vector; tran_ok: sl_array_t) return std_logic_vector is
        alias now_selected_flag: std_logic_vector(N_P-1 downto 0) is now_select_combination(N_P-1 downto 0);
        alias now_last_sel: std_logic_vector(NN-1 downto 0) is now_select_combination(N_P+NN-1 downto N_P);
        variable next_select_combination: std_logic_vector(N_P+NN-1 downto 0);
        alias next_selected_flag: std_logic_vector(N_P-1 downto 0) is next_select_combination(N_P-1 downto 0);
        alias next_last_sel: std_logic_vector(NN-1 downto 0) is next_select_combination(N_P+NN-1 downto N_P);

        variable idx: integer;
        variable choice_num: integer:= 0;
    begin
        next_last_sel := now_last_sel;
        for i in 0 to N_P-1 loop
            idx := (i + to_integer(unsigned(now_last_sel)) + 1) mod N_P;
            if choice_num < CAL_NUM then
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

    -- CAL(num)に入力の何番目を接続するか?
    -- selのnum番目の1は、何ビット目か?(ret=0~N_P-1)
    -- eg: sel=00110011: num,ret=0,0; 1,1; 2,4; 3,5;
    function sel_num_in(constant num: integer; sel: std_logic_vector) return integer is
        variable inc: integer:=0;
        variable ret: integer;
    begin
        ret := num; -- default
        for i in 0 to N_P-1 loop
            if sel(i)='1' then
                if inc = num then
                    ret := i;
                end if;
                inc := inc + 1;
            end if;
        end loop;
        return ret;
    end function;

    -- CAL(num)に出力の何番目を接続するか?
    -- selのnumビット目は、何番目の1か?(ret=0~N_P-1)
    -- eg: sel=00110011: num,ret=0,0; 1,1; 4,2; 5,3;
    function sel_num(constant num: integer; sel: std_logic_vector) return integer is
        variable ret: integer:= -1;
    begin
        for i in 0 to num loop
            if sel(i)='1' then
                ret := ret + 1;
            end if;
        end loop;

        assert ret < CAL_NUM report "Error selcted_flag:" & integer'image(to_integer(unsigned(sel))) severity ERROR;
        return ret;
    end function;

begin

G_N: if N>1 generate
    tran_ok <= i_valid and (not o_valid);
    -- tran_ok <= i_valid and o_ready;
    select_combination <= next_select(select_combination_pre, tran_ok);

    process (clk, rstn) begin
        if rstn='0' then
            selected_flag_pre <= (others=>'0');
            last_sel_pre <= std_logic_vector(to_unsigned(N_P-1, NN)); -- for first 0
        elsif rising_edge(clk) then
            selected_flag_pre <= selected_flag;
            last_sel_pre <= last_sel;
        end if;
    end process;

    process (all)begin
        for i in 0 to CAL_NUM-1 loop
            -- print("SEL" / i / selected_flag / sel_num_in(i, selected_flag));
            for pp in 0 to P-1 loop
                cal_in_a(i*P+pp) <= a(sel_num_in(i, selected_flag)*P+pp);
                cal_in_b(i*P+pp) <= b(sel_num_in(i, selected_flag)*P+pp);
            end loop;
        end loop;
    end process;

    process (all) begin
            for i in 0 to CAL_NUM-1 loop
                for pp in 0 to P-1 loop
                    cal_out(i*P+pp) <= cal_main(cal_in_a(i*P+pp), cal_in_b(i*P+pp));
                end loop;
            end loop;
    end process;

    process (clk, rstn) begin
        if rstn='0' then
            c_val <= (others=>(others => '0'));
            o_valid_val <= (others=>'0');
        elsif rising_edge(clk) then
            for i in 0 to N_P-1 loop
                if selected_flag(i)='1' then
                    for pp in 0 to P-1 loop
                        c_val(i*P+pp) <= cal_out(sel_num(i, selected_flag)*P+pp);
                    end loop;
                    o_valid_val(i) <= '1';
                elsif o_ready(i)='1' then
                    o_valid_val(i) <= '0';
                end if;

                -- Assertion
                assert not(selected_flag(i)='1' and o_valid_val(i)='1')
                report "Selected Error, Buffer Overwrite."
                severity Error;
            end loop;
        end if;
    end process;

    o_valid <= o_valid_val;
    c <= c_val;

    process (all) begin
        for i in 0 to N_P-1 loop
            i_ready_val(i) <= selected_flag(i);
        end loop;
    end process;

    i_ready <= i_ready_val;
else generate -- N=1 Normal
    process (clk, rstn) begin
        if rstn='0' then
            c_val <= (others=>(others => '0'));
            o_valid_val <= (others=>'0');
        elsif rising_edge(clk) then
            o_valid_val <= i_valid;
            for pp in 0 to P-1 loop
                c_val(pp) <= cal_main(a(pp), b(pp));
            end loop;
        end if;
    end process;

    i_ready_val <= o_ready;

    o_valid <= o_valid_val;
    c <= c_val;
    i_ready <= i_ready_val;
end generate;

end architecture;
