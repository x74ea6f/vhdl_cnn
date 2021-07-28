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

    signal a_buf : slv_array_t(0 to KERNEL_SIZE_2 - 1)(IN_DTW - 1 downto 0);
    signal mul_val : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(OUT_DTW - 1 downto 0);
    signal b_val : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0);
    signal i_ready_val : sl_array_t(0 to 1 - 1); --[TBD] bit size

    -- A*W =  3x3 * 4x(3x3) = 4x(3x3)
    function f_mul_cal(
        a : slv_array_t(0 to KERNEL_SIZE_2 - 1)(IN_DTW - 1 downto 0);
        w : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(W_DTW - 1 downto 0)
    ) return slv_array_t is
        variable ret : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(OUT_DTW - 1 downto 0);
    begin
        for oc in 0 to OUT_CH - 1 loop
            for k in 0 to (KERNEL_SIZE_2 - 1) loop
                ret(oc * KERNEL_SIZE_2 + k) := f_clip_s(f_mul_s(a(k), w(oc * KERNEL_SIZE_2 + k)), OUT_DTW);
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

    --[TODO] Valid/Ready
    constant COUNT_LEN : positive := clog2(M);
    constant COUNT_MAX : std_logic_vector(COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 1, COUNT_LEN));
    constant COUNT_ZERO : std_logic_vector(COUNT_LEN - 1 downto 0) := (others=>'0');
    signal o_valid_val : sl_array_t(0 to 1 - 1); --[TBD] bit size
    signal i_count : std_logic_vector(COUNT_LEN - 1 downto 0);
    signal o_count : std_logic_vector(COUNT_LEN - 1 downto 0);
    signal line_start_v0: std_logic;
    signal line_start_v1: std_logic;
    signal line_start_v2: std_logic;
    signal line_end_v0: std_logic;
    signal line_end_v1: std_logic;
    signal line_end_v2: std_logic;

    signal i_valid_v0: std_logic;
    signal i_valid_v1: std_logic;
    signal i_valid_v2: std_logic;
    signal cke0: std_logic;
    signal cke1: std_logic;
    signal cke2: std_logic;
begin
    --[TODO] Valid/Ready
    process (clk, rstn) begin
        if rstn = '0' then
            i_count <= (others => '0');
        elsif rising_edge(clk) then
            if i_valid(0) = '1' and i_ready(0) = '1' then
                if i_count < COUNT_MAX then
                    i_count <= f_increment(i_count);
                else
                    i_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    line_start_v0 <= '1' when i_count=COUNT_ZERO else '0';
    line_end_v0 <= '1' when i_count=COUNT_MAX else '0';
    process (clk, rstn) begin
        if rstn = '0' then
            line_start_v1 <= '0';
            line_end_v1 <= '0';
            line_start_v2 <= '0';
            line_end_v2 <= '0';
        elsif rising_edge(clk) then
            if cke1='1'then
                line_start_v1 <= line_start_v0;
                line_end_v1 <= line_end_v0;
            end if;
            if cke2='1'then
                line_start_v2 <= line_start_v1;
                line_end_v2 <= line_end_v1;
            end if;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            o_count <= (others => '0');
        elsif rising_edge(clk) then
            if o_valid(0) = '1' and o_ready(0) = '1' then
                if o_count < COUNT_MAX then
                    o_count <= f_increment(o_count);
                else
                    o_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            i_valid_v0 <= '0';
            i_valid_v1 <= '0';
            i_valid_v2 <= '0';
        elsif rising_edge(clk) then
            if cke0='1' then
                i_valid_v0 <= i_valid(0);
            end if;
            if cke1='1' then
                i_valid_v1 <= i_valid_v0;
            end if;
            if cke2='1' then
                i_valid_v2 <= (i_valid_v1 and (not line_start_v2)) or line_end_v2 ;
            end if;
        end if;
    end process;

    cke0 <= (not i_valid_v0) or cke1;
    cke1 <= (not i_valid_v1) or cke2;
    cke2 <= (not i_valid_v2) or o_ready(0);

    i_ready(0) <= cke0;
    o_valid(0) <= i_valid_v2;

    process (clk, rstn) begin
        if rstn = '0' then
            a_buf <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if cke0= '1' then
                for i in 0 to (KERNEL_SIZE - 1) loop
                    for j in 0 to (KERNEL_SIZE - 1) loop
                        if i=0 then
                            a_buf(j) <= a(j);
                        else
                            a_buf(i * KERNEL_SIZE + j) <= a_buf((i - 1) * KERNEL_SIZE + j);
                        end if;
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
            if cke1 = '1' then
                mul_val <= f_mul_cal(a_buf, KERNEL_WEIGHT);
            end if;
            if cke1 = '1' then
                b_val <= f_sum_cal(mul_val);
            end if;
        end if;
    end process;

    b <= b_val;

end architecture;