-- Sum
-- (P*M)*N to (P)*N
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_sum is
    generic(
        P: positive:= 1; -- Parallel
        M: positive:= 8; -- Input/Output Number
        N: positive:= 8; -- Input/Output Depth
        AB_DTW: positive:= 8; -- Input A Data Width
        SFT_NUM: natural := 3 -- Shift Number
    );
    port(
        clk: in std_logic;
        rstn: in std_logic;

        clear: in std_logic;
        i_valid: in sl_array_t(0 to M-1);
        i_ready: out sl_array_t(0 to M-1);
        o_valid: out std_logic;
        o_ready: in std_logic;

        a: in slv_array_t(0 to P*M-1)(AB_DTW-1 downto 0);
        b: out slv_array_t(0 to P-1)(AB_DTW-1 downto 0)
    );
end entity;

architecture RTL of piping_sum is

    constant COUNT_DTW: positive := clog2(N);
    constant COUNT_MAX_SLV: std_logic_vector(COUNT_DTW-1 downto 0) := std_logic_vector(to_unsigned(N-1, COUNT_DTW));
    constant SUM_DTW: positive := AB_DTW + COUNT_DTW;

    signal sum_val: slv_array_t(0 to P*M-1)(SUM_DTW-1 downto 0);
    signal out_ok: std_logic;

    signal i_ready_val: sl_array_t(0 to M-1);
    signal o_valid_val: std_logic;
    signal b_val: slv_array_t(0 to P-1)(AB_DTW-1 downto 0);

    signal i_count: std_logic_vector(COUNT_DTW-1 downto 0);
    signal o_count: std_logic_vector(COUNT_DTW-1 downto 0);

    -- function next_sum_val(s: std_logic_vector; a: std_logic_vector) return std_logic_vector is
    -- begin
    --     return std_logic_vector(signed(s) + signed(a));
    -- end function;

    -- Sum Output, Round + Clip
    function sum_out(sum_val: slv_array_t; o_count: std_logic_vector) return slv_array_t is
        variable offset: natural;
        variable v_sum: signed(SUM_DTW-1 downto 0);
        variable v_sft: signed(SUM_DTW-SFT_NUM-1 downto 0);
        variable v_ret: signed(AB_DTW-1 downto 0);
        variable ret: slv_array_t(0 to P-1)(AB_DTW-1 downto 0);
    begin
        offset := to_integer(unsigned(o_count));
        for pp in 0 to P-1 loop
            v_sum := signed(sum_val(offset + pp));
            v_sft := v_sum when SFT_NUM=0 else f_round(v_sum, v_sft'length);
            v_ret := f_clip(v_sft, AB_DTW);
            ret(pp) := std_logic_vector(v_ret);
        end loop;
        return ret;
    end function;
begin

    -- i_ready, 出力してる時だけ止める。
    process (all) begin
        for mm in 0 to M-1 loop
            i_ready_val(mm) <= not o_valid_val;
        end loop;
    end process;

    i_ready <= i_ready_val;


    -- Input Count
    -- 本来はM個のカウンターを持ち、別々にカウントして、
    -- 全部が終了時に、全体を終了とするべきだが、
    -- 0~M-1で、M-1が最後に終わることは確定のはずなので
    -- M-1のデータ数だけをカウントする。
    process (clk, rstn) begin
        if rstn='0' then
            i_count <= (others=>'0');
        elsif rising_edge(clk) then
            if clear='1' then
                i_count <= (others=>'0');
            elsif i_valid(P*M-1)='1' and i_ready_val(P*M-1)='1' then
                i_count <= i_count + '1';
            end if;
        end if;
    end process;

    out_ok <= '1' when i_count=COUNT_MAX_SLV else '0';

    -- Sum
    process (clk, rstn) begin
        if rstn='0' then
            for mm in 0 to P*M-1 loop
                sum_val(mm) <= (others=>'0');
            end loop;
        elsif rising_edge(clk) then
            for mm in 0 to P*M-1 loop
                if clear='1' then
                    sum_val(mm) <= (others=>'0');
                elsif i_valid(mm)='1' then
                    sum_val(mm) <= sum_val(mm) + a(mm);
                    -- sum_val(mm) <= next_sum_val(sum_val(mm), a(mm));
                end if;
            end loop;
        end if;
    end process;

    -- Output Counter, Valid
    process (clk, rstn) begin
        if rstn='0' then
            o_count <= (others=>'0');
            o_valid_val <= '0';
        elsif rising_edge(clk) then
            if clear='1' then
                o_count <= (others=>'0');
                o_valid_val <= '0';
            elsif out_ok='1' and o_count<COUNT_MAX_SLV then
                if o_valid_val='1' and o_ready='1' then
                    o_count <= o_count + '1';
                end if;
                o_valid_val <= '1';
            else
                o_valid_val <= '0';
            end if;
        end if;
    end process;

    o_valid <= o_valid_val;

    -- Output Data
    process (clk, rstn) begin
        if rstn='0' then
            b_val <= (others=>(others=>'0'));
        elsif rising_edge(clk) then
            b_val <= sum_out(sum_val, o_count);
        end if;
    end process;

    b <= b_val;

end architecture;
