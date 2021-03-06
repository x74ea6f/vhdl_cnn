-- Weight RAM Control
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_ram_control is
    generic (
        P : positive := 1; -- Data Parallel
        N : positive := 8; -- N, Data Depth
        M : positive := 8; -- MxN
        AB_DTW : positive := 8; -- Input/Output A,B Data Width
        C_DTW : positive := 8; -- Output C(RAM) Data Width
        ADR_DTW : positive := 3 -- clog2(N/P)
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        clear : in std_logic;
        i_valid : in std_logic;
        i_ready : out std_logic;
        o_valid : out sl_array_t(0 to M - 1);
        o_ready : in sl_array_t(0 to M - 1);

        a : in slv_array_t(0 to P - 1)(AB_DTW - 1 downto 0);
        b : out slv_array_t(0 to P - 1)(AB_DTW - 1 downto 0);
        c : out slv_array_t(0 to M*P - 1)(C_DTW - 1 downto 0);

        ram_re : out std_logic;
        ram_addr : out std_logic_vector(ADR_DTW - 1 downto 0);
        ram_rd : in slv_array_t(0 to M*P - 1)(C_DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_ram_control is
    constant M_P : positive := (M + P - 1)/P;
    constant N_P : positive := (N + P - 1)/P;

    constant ADR_MAX_SLV : std_logic_vector(ADR_DTW - 1 downto 0) := std_logic_vector(to_unsigned((N + P - 1)/P - 1, ADR_DTW));

    signal i_ready_val : std_logic;
    signal o_valid_val : sl_array_t(0 to M - 1);
    signal ram_re_val : std_logic;
    signal ram_addr_val : std_logic_vector(ADR_DTW - 1 downto 0);
    signal b_val : slv_array_t(0 to P - 1)(AB_DTW - 1 downto 0);
    signal c_val : slv_array_t(0 to M*P - 1)(C_DTW - 1 downto 0);

    -- signal ram_re_val_d : std_logic;

    function f_and_reduce(s : sl_array_t) return std_logic is
        variable ret : std_logic := '1';
    begin
        for i in s'range loop
            ret := ret and s(i);
        end loop;
        return ret;
    end function;

    function f_or_reduce(s : sl_array_t) return std_logic is
        variable ret : std_logic := '0';
    begin
        for i in s'range loop
            ret := ret or s(i);
        end loop;
        return ret;
    end function;

begin

    -- 0~M?????????????????????????????????????????????
    i_ready_val <= not f_or_reduce(o_valid);
    -- i_ready_val <= f_and_reduce(o_ready);
    i_ready <= i_ready_val;

    ram_re_val <= i_valid and i_ready_val;
    ram_re <= ram_re_val;

    -- RAM Data Latch
    process (clk, rstn) begin
        if rstn = '0' then
            c_val <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if ram_re_val = '1' then
                c_val <= ram_rd;
            end if;
        end if;
    end process;

    c <= c_val;

    -- o_valid
    process (clk, rstn) begin
        if rstn = '0' then
            o_valid_val <= (others => '0');
        elsif rising_edge(clk) then
            for mm in 0 to M - 1 loop
                if ram_re_val = '1' then
                    o_valid_val(mm) <= '1';
                elsif o_ready(mm) = '1' then
                    o_valid_val(mm) <= '0';
                end if;
            end loop;
        end if;
    end process;

    o_valid <= o_valid_val;

    -- main data
    process (clk, rstn) begin
        if rstn = '0' then
            b_val <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if i_valid = '1' and i_ready_val = '1' then
                b_val <= a;
            end if;
        end if;
    end process;

    b <= b_val;

    -- ram address
    process (clk, rstn) begin
        if rstn = '0' then
            ram_addr_val <= (others => '0');
        elsif rising_edge(clk) then
            if clear = '1' then
                ram_addr_val <= (others => '0');
            elsif i_valid = '1' and i_ready_val = '1' then
                if ram_addr_val = ADR_MAX_SLV then
                    ram_addr_val <= (others => '0');
                else
                    ram_addr_val <= f_increment(ram_addr_val);
                end if;
            end if;
        end if;
    end process;

    ram_addr <= ram_addr_val;
end architecture;