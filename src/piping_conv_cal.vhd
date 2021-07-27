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
        DTW : positive := 8; -- Data Width
        KERNEL_WEIGHT : slv_array_t(0 to KERNEL_SIZE * KERNEL_SIZE * OUT_CH - 1)(DTW - 1 downto 0) := (others => (others => '0'))
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to (IN_CH + P - 1)/P - 1);
        i_ready : out sl_array_t(0 to (IN_CH + P - 1)/P - 1);
        o_valid : out sl_array_t(0 to (OUT_CH + P - 1)/P - 1);
        o_ready : in sl_array_t(0 to (OUT_CH + P - 1)/P - 1);

        a : in slv_array_t(0 to KERNEL_SIZE * IN_CH * P - 1)(DTW - 1 downto 0);
        b : out slv_array_t(0 to OUT_CH * P - 1)(DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_conv_cal is

    constant M_P : positive := (M + P - 1)/P;
    constant KERNEL_CENTER: positive := (KERNEL_SIZE-1)/2;
    constant KERNEL_SIZE_2: positive := KERNEL_SIZE*KERNEL_SIZE;

    signal a_buf: slv_array_t(0 to KERNEL_SIZE_2-1)(DTW-1 downto 0);
    signal mul_v: slv_array_t(0 to OUT_CH*KERNEL_SIZE_2-1)(DTW-1 downto 0);
    signal b_v : slv_array_t(0 to OUT_CH * P - 1)(DTW - 1 downto 0);

    function f_mul_cal(
        a: slv_array_t(0 to KERNEL_SIZE_2-1)(DTW-1 downto 0);
        w: slv_array_t(0 to OUT_CH*KERNEL_SIZE_2-1)(DTW-1 downto 0)
        ) return slv_array_t is
        variable ret: slv_array_t(0 to OUT_CH*KERNEL_SIZE_2-1)(DTW-1 downto 0);
    begin
            for oc in 0 to OUT_CH-1 loop
                for k in 0 to (KERNEL_SIZE_2 - 1) loop
                    ret(oc * KERNEL_SIZE_2 + k) := f_clip_s(f_mul_s(a(k), w(oc * KERNEL_SIZE_2 + k)), DTW);
                end loop;
            end loop;
        return ret;
    end function;

begin
    process (clk, rstn) begin
        if rstn = '0' then
            a_buf <= (others => (others => '0'));
        elsif rising_edge(clk) then
            for i in 0 to (KERNEL_SIZE - 1) loop
                for j in 0 to (KERNEL_SIZE - 1) loop
                    if i=0 then
                        a_buf(j) <= a(j);
                    else
                        a_buf(i*KERNEL_SIZE+j) <= a_buf((i-1)*KERNEL_SIZE+j);
                    end if;
                end loop;
            end loop;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            mul_v <= (others => (others => '0'));
        elsif rising_edge(clk) then
            mul_v <= f_mul_cal(a_buf, KERNEL_WEIGHT);
        end if;
    end process;

end architecture;