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
    constant KERNEL_CENTER : positive := (KERNEL_SIZE - 1)/2;
    constant KERNEL_SIZE_2 : positive := KERNEL_SIZE * KERNEL_SIZE;

    signal a_buf : slv_array_t(0 to KERNEL_SIZE_2 - 1)(IN_DTW - 1 downto 0);
    signal mul_v : slv_array_t(0 to OUT_CH * KERNEL_SIZE_2 - 1)(OUT_DTW - 1 downto 0);
    signal b_v : slv_array_t(0 to OUT_CH * P - 1)(OUT_DTW - 1 downto 0);
    signal i_ready_v : sl_array_t(0 to 1 - 1); --[TBD] bit size

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
    constant COUNT_LEN: positive:=clog2(M);
    constant COUNT_MAX: std_logic_vector(COUNT_LEN-1 downto 0) := std_logic_vector(to_unsigned(M-1, COUNT_LEN));
    signal o_valid_v0 : sl_array_t(0 to 1 - 1); --[TBD] bit size
    signal o_valid_v1 : sl_array_t(0 to 1 - 1); --[TBD] bit size
    signal i_count: std_logic_vector(COUNT_LEN-1 downto 0);
begin
    --[TODO] Valid/Ready
    process (clk, rstn) begin
        if rstn = '0' then
            i_count <= (others=>'0');
        elsif rising_edge(clk) then
            if i_valid(0) and i_ready_v(0) then
                if unsigned(i_count) < 28 then
                    i_count <= f_add_u(i_count, "1")(COUNT_LEN-1 downto 0);
                else
                    i_count <= (others=>'0');
                end if;
            end if;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            o_valid_v0 <= (others=>'0');
            o_valid_v1 <= (others=>'0');
        elsif rising_edge(clk) then
            if i_valid(0) and i_ready_v(0) then
                o_valid_v0(0) <= '1';
                o_valid_v1(0) <= o_valid_v0(0);
            end if;
        end if;
    end process;

    i_ready_v <= o_ready;
    i_ready <= i_ready_v;
    o_valid <= o_valid_v1;

    process (clk, rstn) begin
        if rstn = '0' then
            a_buf <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if i_valid(0)='1' and i_ready_v(0)='1' then
                for i in 0 to (KERNEL_SIZE - 1) loop
                    for j in 0 to (KERNEL_SIZE - 1) loop
                        if i = 0 then
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
            mul_v <= (others => (others => '0'));
            b_v <= (others => (others => '0'));
        elsif rising_edge(clk) then
            mul_v <= f_mul_cal(a_buf, KERNEL_WEIGHT);
            b_v <= f_sum_cal(mul_v);
        end if;
    end process;

    b <= b_v;

end architecture;