-- conv
-- - KERNEL_SIZE=3しかできない。
--   - PixCounterでマスクしているところの検討不足(現状は最初と最後のピクセルしか考慮してない)
-- IN_CH=1のみ。[TODO]
-- P=1のみ。
--   - しんどいかも。
-- 
-- KERNEL_WEIGHT(KERNEL_SIZE=3, IN_CH=1)の並び方(+90°)
-- | 6 | 3 | 0 |
-- | 7 | 4 | 1 |
-- | 8 | 5 | 2 |
-- 
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
        IN_DTW : positive := 8; -- Data Width
        OUT_DTW : positive := 8 + 4; -- Data Width
        W_DTW : positive := 8; -- Kernel Width
        KERNEL_WEIGHT : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * OUT_CH - 1)(W_DTW - 1 downto 0) := (others => (others => '0'))
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to 1 - 1); --[TBD] bit size
        i_ready : out sl_array_t(0 to 1 - 1); --[TBD] bit size
        o_valid : out sl_array_t(0 to 1 - 1); --[TBD] bit size
        o_ready : in sl_array_t(0 to 1 - 1); --[TBD] bit size

        a : in slv_array_t(0 to KERNEL_SIZE * IN_CH * P - 1)(IN_DTW - 1 downto 0);
        b : out slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_conv_cal is

    constant M_P : positive := (M + P - 1)/P;
    constant KERNEL_CENTER : positive := KERNEL_SIZE/2;
    constant KERNEL_SIZE_2 : positive := KERNEL_SIZE * KERNEL_SIZE;

    signal a_buf : slv_array_t(0 to IN_CH*KERNEL_SIZE_2 - 1)(IN_DTW - 1 downto 0);
    signal mul_val : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(OUT_DTW - 1 downto 0);
    signal b_val : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0);

    -- A*W =  3x3 * 4x(3x3) = 4x(3x3)
    function f_mul_cal(
        a : slv_array_t(0 to IN_CH * KERNEL_SIZE_2 - 1)(IN_DTW - 1 downto 0);
        w : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(W_DTW - 1 downto 0)
    ) return slv_array_t is
        variable ret : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(OUT_DTW - 1 downto 0);
    begin
        for oc in 0 to OUT_CH/IN_CH - 1 loop
            for ic in 0 to IN_CH - 1 loop
                for k in 0 to (KERNEL_SIZE_2 - 1) loop
                    ret(oc*IN_CH*KERNEL_SIZE_2 + ic * KERNEL_SIZE_2 + k) := f_clip_s(f_mul_s(a(ic*KERNEL_SIZE_2+k), w(ic * KERNEL_SIZE_2 + k)), OUT_DTW);
                    -- ret(oc*IN_CH*KERNEL_SIZE_2 + ic * KERNEL_SIZE_2 + k) := f_clip_s(f_mul_s(a(ic*IN_CH+k), w(ic * KERNEL_SIZE_2 + k)), OUT_DTW);
                end loop;
            end loop;
        end loop;
        return ret;
    end function;

    -- sum(A*W) =  4x(3x3) = 4
    function f_sum_cal(
        m : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(OUT_DTW - 1 downto 0)
    ) return slv_array_t is
        variable ret : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0) := (others => (others => '0'));
    begin
        for oc in 0 to OUT_CH - 1 loop
            for k in 0 to (KERNEL_SIZE_2 - 1) loop
                ret(oc) := f_clip_s(f_add_s(ret(oc), m(oc * KERNEL_SIZE_2 + k)), OUT_DTW);
            end loop;
        end loop;
        return ret;
    end function;

    constant PIX_COUNT_LEN : positive := clog2(M);
    constant PIX_COUNT_MAX : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 1, PIX_COUNT_LEN));
    constant PIX_COUNT_MAX_1 : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 2, PIX_COUNT_LEN));
    constant PIX_COUNT_MAX_2 : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 3, PIX_COUNT_LEN));
    constant PIX_COUNT_ZERO : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := (others=>'0');
    signal i_pix_count : std_logic_vector(PIX_COUNT_LEN - 1 downto 0);

    constant LINE_COUNT_LEN : positive := clog2(M);
    constant LINE_COUNT_MAX : std_logic_vector(LINE_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 1, LINE_COUNT_LEN));
    constant LINE_COUNT_ZERO : std_logic_vector(LINE_COUNT_LEN - 1 downto 0) := (others=>'0');
    signal i_line_count : std_logic_vector(LINE_COUNT_LEN - 1 downto 0);

    signal line_first_v0: std_logic;
    signal line_first_v1: std_logic;
    signal line_first_v2: std_logic;
    signal line_first_v3: std_logic;
    signal line_last_v0: std_logic;
    signal line_last_v1: std_logic;
    signal line_last_v2: std_logic;
    signal line_last_v3: std_logic;
    signal pix_first_v0: std_logic;
    signal pix_first_v1: std_logic;
    signal pix_first_v2: std_logic;
    signal pix_first_v3: std_logic;
    signal pix_last_v0: std_logic;
    signal pix_last_v1: std_logic;
    signal pix_last_v2: std_logic;
    signal pix_last_v3: std_logic;

    signal pix_last_v0_d: std_logic;
    signal pix_last_v0_pls: std_logic;

    signal i_valid_v0: std_logic;
    signal i_valid_v1: std_logic;
    signal i_valid_v2: std_logic;
    signal i_valid_v3: std_logic;
    signal cke0: std_logic;
    signal cke1: std_logic;
    signal cke2: std_logic;
    signal cke3: std_logic;
begin
    -- Pix/Line Counter
    process (clk, rstn) begin
        if rstn = '0' then
            i_pix_count <= (others => '0');
            i_line_count <= (others => '0');
        elsif rising_edge(clk) then
            if (i_valid(0) = '1' and i_ready(0) = '1') then
                if i_pix_count < PIX_COUNT_MAX then
                    i_pix_count <= f_increment(i_pix_count);
                else
                    i_pix_count <= PIX_COUNT_ZERO;
                    if i_line_count < LINE_COUNT_MAX then
                        i_line_count <= f_increment(i_line_count);
                    else
                        i_line_count <= LINE_COUNT_ZERO;
                    end if;
                end if;
            end if;
        end if;
    end process;

    pix_first_v0 <= '1' when i_pix_count=PIX_COUNT_ZERO else '0';
    pix_last_v0 <= '1' when i_pix_count=PIX_COUNT_MAX else '0';
    line_first_v0 <= '1' when i_line_count=LINE_COUNT_ZERO else '0';
    line_last_v0 <= '1' when i_line_count=LINE_COUNT_MAX else '0';

    process (clk, rstn) begin
        if rstn = '0' then
            pix_last_v0_d <= '0';
        elsif rising_edge(clk) then
            pix_last_v0_d <= pix_last_v0;
        end if;
    end process;

    pix_last_v0_pls <= pix_last_v0 and (not pix_last_v0_d);

    process (clk, rstn) begin
        if rstn = '0' then
            line_first_v1 <= '0';
            line_last_v1 <= '0';
            pix_first_v1 <= '0';
            pix_last_v1 <= '0';
            line_first_v2 <= '0';
            line_last_v2 <= '0';
            pix_first_v2 <= '0';
            pix_last_v2 <= '0';
            line_first_v3 <= '0';
            line_last_v3 <= '0';
            pix_first_v3 <= '0';
            pix_last_v3 <= '0';
        elsif rising_edge(clk) then
            if cke1='1'then
                pix_first_v1 <= pix_first_v0;
                pix_last_v1 <= pix_last_v0_pls;
                line_first_v1 <= line_first_v0;
                line_last_v1 <= line_last_v0;
            end if;
            if cke2='1'then
                pix_first_v2 <= pix_first_v1;
                pix_last_v2 <= pix_last_v1;
                line_first_v2 <= line_first_v1;
                line_last_v2 <= line_last_v1;
            end if;
            if cke3='1'then
                pix_first_v3 <= pix_first_v2;
                pix_last_v3 <= pix_last_v2;
                line_first_v3 <= line_first_v2;
                line_last_v3 <= line_last_v2;
            end if;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            i_valid_v0 <= '0';
            i_valid_v1 <= '0';
            i_valid_v2 <= '0';
            i_valid_v3 <= '0';
        elsif rising_edge(clk) then
            if cke0='1' then
                i_valid_v0 <= i_valid(0) or pix_last_v0_pls;
            end if;
            if cke1='1' then
                i_valid_v1 <= i_valid_v0;
            end if;
            if cke2='1' then
                i_valid_v2 <= i_valid_v1;
            end if;
            if cke3='1' then
                i_valid_v3 <= i_valid_v2 and (not pix_last_v3) ;
            end if;
        end if;
    end process;

    cke0 <= (not i_valid_v0) or cke1;
    cke1 <= (not i_valid_v1) or cke2;
    cke2 <= (not i_valid_v2) or cke3;
    cke3 <= (not i_valid_v3) or o_ready(0);

    -- ライン最終Pixは、入力を止めて内部処理だけ進める。
    i_ready(0) <= cke0 and (not pix_last_v0_pls);
    o_valid(0) <= i_valid_v3;

    process (clk, rstn) begin
        if rstn = '0' then
            a_buf <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if cke0= '1' or cke1='1' then
                for ch in 0 to (IN_CH -1) loop
                    for i in 0 to (KERNEL_SIZE - 1) loop
                        for j in 0 to (KERNEL_SIZE - 1) loop
                            if i=0 then
                                a_buf(ch * KERNEL_SIZE_2 +j) <= a(ch * KERNEL_SIZE +j);
                            else
                                a_buf(ch * KERNEL_SIZE_2 + i * KERNEL_SIZE + j) <= a_buf(ch*KERNEL_SIZE_2 + (i - 1) * KERNEL_SIZE + j);
                                -- a_buf(i * KERNEL_SIZE + j) <= a_buf((i - 1) * KERNEL_SIZE + j);
                            end if;
                        end loop;
                    end loop;
                end loop;
            end if;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            mul_val <= (others => (others => '0'));
            b_val <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if cke2 = '1' then
                mul_val <= f_mul_cal(a_buf, KERNEL_WEIGHT);
            end if;
            if cke3 = '1' then
                b_val <= f_sum_cal(mul_val);
            end if;
        end if;
    end process;

    b <= b_val;

end architecture;