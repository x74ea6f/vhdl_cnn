-- Sum
-- M/P*N to N/P
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_sum is
    generic (
        P : positive := 1; -- Parallel
        M : positive := 8; -- Input/Output Number
        N : positive := 8; -- Input/Output Depth
        A_DTW : positive := 8 * 2 - 1; -- Input A Data Width
        B_DTW : positive := 8; -- Input B Data Width
        SFT_NUM : natural := 3 -- Shift Number
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        clear : in std_logic;
        i_valid : in sl_array_t(0 to M - 1);
        i_ready : out sl_array_t(0 to M - 1);
        o_valid : out std_logic;
        o_ready : in std_logic;

        a : in slv_array_t(0 to P*M - 1)(A_DTW - 1 downto 0);
        b : out slv_array_t(0 to P - 1)(B_DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_sum is
    constant M_P : positive := (M + P - 1)/P;
    constant N_P : positive := (N + P - 1)/P;

    constant I_COUNT_DTW : positive := clog2(N_P+1);
    constant O_COUNT_DTW : positive := clog2(M_P);
    constant I_COUNT_MAX_SLV : std_logic_vector(I_COUNT_DTW - 1 downto 0)
    := std_logic_vector(to_unsigned(N_P, I_COUNT_DTW));
    constant O_COUNT_MAX_SLV : std_logic_vector(O_COUNT_DTW - 1 downto 0)
    := std_logic_vector(to_unsigned(M_P - 1, O_COUNT_DTW));

    constant SUM_DTW : positive := A_DTW + I_COUNT_DTW;

    signal sum_val : slv_array_t(0 to M - 1)(SUM_DTW - 1 downto 0);
    signal out_ok : std_logic;

    signal i_ready_val : sl_array_t(0 to M - 1);
    signal o_valid_val : std_logic;
    signal b_val : slv_array_t(0 to P - 1)(B_DTW - 1 downto 0);

    signal i_count : slv_array_t(0 to M - 1)(I_COUNT_DTW - 1 downto 0);
    signal o_count : std_logic_vector(O_COUNT_DTW - 1 downto 0);

    signal o_done : std_logic;
    signal self_clear : std_logic;

    -- function next_sum_val(s: std_logic_vector; a: std_logic_vector) return std_logic_vector is
    -- begin
    --     return std_logic_vector(signed(s) + signed(a));
    -- end function;

    -- Sum Output, Round + Clip
    function sum_out(sum_val : slv_array_t; o_count : std_logic_vector) return slv_array_t is
        variable offset : natural;
        variable v_sum : signed(SUM_DTW - 1 downto 0);
        variable v_sft : signed(SUM_DTW - SFT_NUM - 1 downto 0);
        variable v_ret : signed(B_DTW - 1 downto 0);
        variable ret : slv_array_t(0 to P - 1)(B_DTW - 1 downto 0);
    begin
        offset := to_integer(unsigned(o_count)) * P;
        for pp in 0 to P - 1 loop
            if (offset+pp<sum_val'length)then
                v_sum := signed(sum_val(offset + pp));
                v_sft := v_sum when SFT_NUM = 0 else
                    f_round(v_sum, v_sft'length);
                v_ret := f_clip(v_sft, B_DTW);
                ret(pp) := std_logic_vector(v_ret);
            else
                ret(pp) := (others=>'0');
            end if;
        end loop;
        return ret;
    end function;


    function para_sum(a: slv_array_t; offset, P: natural) return std_logic_vector is
        variable ret: std_logic_vector(SUM_DTW-1 downto 0) := (others=>'0');
    begin
        for pp in 0 to P-1 loop
            ret := f_add_s(ret, a(offset + pp))(SUM_DTW-1 downto 0); -- Not Overflow
        end loop;
        return ret;
    end function;

begin

    -- Input Count
    process (clk, rstn) begin
        if rstn = '0' then
            for mm in 0 to M - 1 loop
                i_count(mm) <= (others => '0');
                i_ready_val(mm) <= '1';
            end loop;
        elsif rising_edge(clk) then
            for mm in 0 to M - 1 loop
                if self_clear = '1' then
                    i_count(mm) <= (others => '0');
                    i_ready_val(mm) <= '1';
                elsif i_valid(mm) = '1' then
                    if i_count(mm) < I_COUNT_MAX_SLV then
                        i_count(mm) <= f_increment(i_count(mm));
                        i_ready_val(mm) <= '1';
                    else
                        i_ready_val(mm) <= '0';
                    end if;
                end if;
            end loop;
        end if;
    end process;

    i_ready <= i_ready_val;

    -- All Channel OK
    process (all)
        variable out_ok_val : std_logic;
    begin
        out_ok_val := '1';
        for mm in 0 to M - 1 loop
            out_ok_val := out_ok_val when i_count(mm) = I_COUNT_MAX_SLV else
                '0';
        end loop;
        out_ok <= out_ok_val;
    end process;

    -- Sum
    process (clk, rstn) begin
        if rstn = '0' then
            for mm in 0 to M - 1 loop
                sum_val(mm) <= (others => '0');
            end loop;
        elsif rising_edge(clk) then
            for mm in 0 to M - 1 loop
                if self_clear = '1' then
                    sum_val(mm) <= (others => '0');
                elsif i_valid(mm) = '1' and i_ready_val(mm) = '1' then
                    sum_val(mm) <= f_add_s(sum_val(mm), para_sum(a, mm*P, P))(SUM_DTW - 1 downto 0); -- Not Overflow
                end if;
            end loop;
        end if;
    end process;

    -- Output Counter, Valid
    process (clk, rstn) begin
        if rstn = '0' then
            o_count <= (others => '0');
            o_valid_val <= '0';
        elsif rising_edge(clk) then
            if self_clear = '1' then
                o_count <= (others => '0');
                o_valid_val <= '0';
            elsif out_ok = '1' and o_count < O_COUNT_MAX_SLV then
                if o_valid_val = '1' and o_ready = '1' then
                    o_count <= f_increment(o_count);
                end if;
                o_valid_val <= '1';
            elsif o_ready = '1' then
                o_valid_val <= '0';
            end if;
        end if;
    end process;

    o_done <= '1' when o_count = O_COUNT_MAX_SLV and o_ready = '1' else
        '0';
    self_clear <= clear or o_done;

    o_valid <= o_valid_val;

    -- Output Data
    b_val <= sum_out(sum_val, o_count);
    b <= b_val;

end architecture;