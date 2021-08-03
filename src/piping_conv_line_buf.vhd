-- conv line buf
-- - KERNEL_SIZE=3しかできない。
-- - P=1しかできない。
-- 
-- 
library ieee;
library work;
use work.piping_pkg.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.numeric_lib.all;
-- use work.str_lib.all;

entity piping_conv_line_buf is
    generic (
        P : positive := 1; -- Data Parallel
        M : positive := 28; -- Width
        N : positive := 28; -- Height
        CH : positive := 1; -- Input Channnel
        DTW : positive := 8; -- Data Width
        KERNEL_SIZE: positive := 3
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to 1 - 1); --[TBD] bit size
        i_ready : out sl_array_t(0 to 1 - 1); --[TBD] bit size
        o_valid : out sl_array_t(0 to 1 - 1); --[TBD] bit size
        o_ready : in sl_array_t(0 to 1 - 1); --[TBD] bit size

        a : in slv_array_t(0 to CH * P - 1)(DTW - 1 downto 0);
        b : out slv_array_t(0 to KERNEL_SIZE*CH * P - 1)(DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_conv_line_buf is

    constant PIX_COUNT_LEN : positive := clog2(M);
    constant PIX_COUNT_MAX : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 1, PIX_COUNT_LEN));
    constant PIX_COUNT_MAX_1 : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 2, PIX_COUNT_LEN));
    constant PIX_COUNT_MAX_2 : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 3, PIX_COUNT_LEN));
    constant PIX_COUNT_ZERO : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := (others=>'0');
    signal i_pix_count : std_logic_vector(PIX_COUNT_LEN - 1 downto 0);

    constant LINE_COUNT_LEN : positive := clog2(M);
    constant LINE_COUNT_MAX : std_logic_vector(LINE_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(N - 1, LINE_COUNT_LEN));
    constant LINE_COUNT_ZERO : std_logic_vector(LINE_COUNT_LEN - 1 downto 0) := (others=>'0');
    signal i_line_count : std_logic_vector(LINE_COUNT_LEN - 1 downto 0);

    signal pix_first_v0: std_logic;
    signal pix_first_v1: std_logic;
    signal pix_first_v2: std_logic;
    signal pix_last_v0: std_logic;
    signal pix_last_v1: std_logic;
    signal pix_last_v2: std_logic;

    signal line_first_v0: std_logic;
    signal line_first_v1: std_logic;
    signal line_first_v2: std_logic;
    signal line_last_v0: std_logic;
    signal line_last_v1: std_logic;
    signal line_last_v2: std_logic;

    signal i_valid_v0: std_logic;
    signal i_valid_v1: std_logic;
    signal i_valid_v2: std_logic;
    signal cke0: std_logic;
    signal cke1: std_logic;
    signal cke2: std_logic;

    signal ram_re : sl_array_t(0 to KERNEL_SIZE-2);
    signal ram_ce : sl_array_t(0 to KERNEL_SIZE-2);
    signal ram_we : sl_array_t(0 to KERNEL_SIZE-2);
    signal ram_d : std_logic_vector(DTW*CH*P-1 downto 0);
    signal ram_q : slv_array_t(0 to KERNEL_SIZE-2)(DTW*CH*P - 1 downto 0);

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
                i_valid_v2 <= i_valid_v1;
            end if;
        end if;
    end process;

    cke0 <= (not i_valid_v0) or o_ready(0);
    cke1 <= (not i_valid_v1) or o_ready(0);
    cke2 <= (not i_valid_v2) or o_ready(0);

    -- 最初のラインは出力出さない。
    -- 最終ライン後に自走で出力出す。

    -- to slv
    process (all)begin
        for i in 0 to CH*P-1 loop
            ram_d(DTW*(i+1) downto DTW*i) <= a(i);
        end loop;
    end process;

    process (all)begin
        for k in 0 to KERNEL_SIZE-2 loop
            if (unsigned(i_line_count)  mod (KERNEL_SIZE-1)) = k then
                ram_we(k) <= i_valid(0) and i_ready(0);
            else
                ram_we(k) <= '0';
            end if;
            ram_re(k) <= i_valid(0) and i_ready(0);
        end loop;
    end process;

    ram_ce <= ram_re or ram_we;

    GEN_RAM: for k in 0 to KERNEL_SIZE-2 generate
        piping_conv_buf: entity work.ram1rw generic map(
            DTW => DTW*CH*P,
            ADW => PIX_COUNT_LEN,
            DEPTH => N,
            MEM_INIT => (others=>(others=>'0'))
        )
        port map (
            clk => clk,
            ce => ram_ce(k),
            we => ram_we(k),
            a => i_pix_count,
            d => ram_d,
            q => ram_q(k)
        );
    end generate;

end architecture;
