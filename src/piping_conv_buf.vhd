-- conv buf
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

entity piping_conv_buf is
    generic (
        P : positive := 1; -- Data Parallel
        M : positive := 28; -- Width
        N : positive := 28; -- Height
        CH : positive := 1; -- Input Channnel
        DTW : positive := 8; -- Data Width
        KERNEL_SIZE: positive := 3 -- Kernel Size
    );
    port (
        clk : in std_logic;
        rstn : in std_logic;

        i_valid : in sl_array_t(0 to 1 - 1); --[TBD] bit size
        i_ready : out sl_array_t(0 to 1 - 1); --[TBD] bit size
        o_valid : out sl_array_t(0 to 1 - 1); --[TBD] bit size
        o_ready : in sl_array_t(0 to 1 - 1); --[TBD] bit size

        a : in slv_array_t(0 to KERNEL_SIZE * CH * P - 1)(DTW - 1 downto 0);
        b : out slv_array_t(0 to KERNEL_SIZE*KERNEL_SIZE*CH * P - 1)(DTW - 1 downto 0)
    );
end entity;

architecture RTL of piping_conv_buf is

    constant KERNEL_CENTER : positive := KERNEL_SIZE/2; -- Center
    constant KERNEL_SIZE_SQ : positive := KERNEL_SIZE * KERNEL_SIZE; -- Square

    signal a_buf : slv_array_t(0 to CH*KERNEL_SIZE_SQ - 1)(DTW - 1 downto 0);

    constant PIX_COUNT_LEN : positive := clog2(M);
    constant PIX_COUNT_MAX : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(M - 1, PIX_COUNT_LEN));
    constant PIX_COUNT_ZERO : std_logic_vector(PIX_COUNT_LEN - 1 downto 0) := (others=>'0');
    signal i_pix_count : std_logic_vector(PIX_COUNT_LEN - 1 downto 0);

    constant LINE_COUNT_LEN : positive := clog2(N);
    constant LINE_COUNT_MAX : std_logic_vector(LINE_COUNT_LEN - 1 downto 0) := std_logic_vector(to_unsigned(N - 1, LINE_COUNT_LEN));
    constant LINE_COUNT_ZERO : std_logic_vector(LINE_COUNT_LEN - 1 downto 0) := (others=>'0');
    signal i_line_count : std_logic_vector(LINE_COUNT_LEN - 1 downto 0);

    signal line_first_v0: std_logic;
    signal line_first_v1: std_logic;
    signal line_first_v2: std_logic;
    signal line_last_v0: std_logic;
    signal line_last_v1: std_logic;
    signal line_last_v2: std_logic;
    signal pix_first_v0: std_logic;
    signal pix_first_v1: std_logic;
    signal pix_first_v2: std_logic;
    signal pix_last_v0: std_logic;
    signal pix_last_v1: std_logic;
    signal pix_last_v2: std_logic;

    signal pix_last_v0_d: std_logic;
    signal pix_last_v0_pls: std_logic;
    signal line_last_v0_d: std_logic;

    signal i_valid_v0: std_logic;
    signal i_valid_v1: std_logic;
    signal i_valid_v2: std_logic;
    signal cke0: std_logic;
    signal cke1: std_logic;
    signal cke2: std_logic;

    signal buf_run: std_logic;
    signal buf_run_d: std_logic;
    signal o_valid_mask: std_logic;
    signal o_valid_mask_d: std_logic;
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
            line_first_v1 <= '0';
            line_last_v1 <= '0';
            pix_first_v1 <= '0';
            pix_last_v1 <= '0';
            line_first_v2 <= '0';
            line_last_v2 <= '0';
            pix_first_v2 <= '0';
            pix_last_v2 <= '0';
        elsif rising_edge(clk) then
            if (i_valid(0) = '1' and i_ready(0) = '1') or buf_run='1' then
            -- if (i_valid(0) = '1' and i_ready(0) = '1') then
                pix_first_v1 <= pix_first_v0;
                pix_last_v1 <= pix_last_v0;
                line_first_v1 <= line_first_v0;
                line_last_v1 <= line_last_v0;
                pix_first_v2 <= pix_first_v1;
                pix_last_v2 <= pix_last_v1;
                line_first_v2 <= line_first_v1;
                line_last_v2 <= line_last_v1;
            end if;
        end if;
    end process;

    process (clk, rstn) begin
        if rstn = '0' then
            pix_last_v0_d <= '0';
        elsif rising_edge(clk) then
            pix_last_v0_d <= pix_last_v0;
        end if;
    end process;

    pix_last_v0_pls <= (not pix_last_v0) and pix_last_v0_d; -- fall


    -- 最後のピクセルは進める。
    buf_run <= pix_last_v0_pls and line_last_v0_d;

    -- 最初のピクセルはValidマスク
    o_valid_mask <= pix_first_v0 and line_first_v0;

    process (clk, rstn) begin
        if rstn = '0' then
            buf_run_d <= '0';
            o_valid_mask_d <= '0';
            line_last_v0_d <= '0';
        elsif rising_edge(clk) then
            line_last_v0_d <= line_last_v0;
            buf_run_d <= buf_run;
            o_valid_mask_d <= o_valid_mask;
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
                i_valid_v2 <= i_valid_v1;
            end if;
        end if;
    end process;

    cke0 <= (not i_valid_v0) or o_ready(0);
    cke1 <= (not i_valid_v1) or o_ready(0);
    cke2 <= (not i_valid_v2) or o_ready(0);

    -- ライン最終Pixは、入力を止めて内部処理だけ進める。
    i_ready(0) <= cke0 and not buf_run;
    -- 最初に出さない、最後に余計に出す。
    o_valid(0) <= (i_valid_v0 and not o_valid_mask_d) or (buf_run_d);
    -- o_valid(0) <= (i_valid_v0 and not (pix_first_v0_d and line_first_v0_d)) or (buf_run_d);

    process (clk, rstn) begin
        if rstn = '0' then
            a_buf <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if cke0='1' and ((i_valid(0)='1' and i_ready(0)='1') or buf_run='1') then
                for ch in 0 to (CH -1) loop
                    for j in 0 to (KERNEL_SIZE - 1) loop
                        for i in 0 to (KERNEL_SIZE - 1) loop
                            if i=KERNEL_SIZE-1 then
                                a_buf(ch * KERNEL_SIZE_SQ + j*KERNEL_SIZE + i) <= a(ch * KERNEL_SIZE + j);
                            else
                                a_buf(ch * KERNEL_SIZE_SQ + j*KERNEL_SIZE + i) <= a_buf(ch*KERNEL_SIZE_SQ + j * KERNEL_SIZE + i + 1);
                            end if;
                        end loop;
                    end loop;
                end loop;
            end if;
        end if;
    end process;

    -- process (clk, rstn) begin
    --     if rstn = '0' then
    --         a_buf <= (others => (others => '0'));
    --     elsif rising_edge(clk) then
    --         if cke0='1' and ((i_valid(0)='1' and i_ready(0)='1') or buf_run='1') then
    --             for ch in 0 to (CH -1) loop
    --                 for i in 0 to (KERNEL_SIZE - 1) loop
    --                     for j in 0 to (KERNEL_SIZE - 1) loop
    --                         if i=0 then
    --                             a_buf(ch * KERNEL_SIZE_SQ +j) <= a(ch * KERNEL_SIZE +j);
    --                         else
    --                             a_buf(ch * KERNEL_SIZE_SQ + i * KERNEL_SIZE + j) <= a_buf(ch*KERNEL_SIZE_SQ + (i - 1) * KERNEL_SIZE + j);
    --                         end if;
    --                     end loop;
    --                 end loop;
    --             end loop;
    --         end if;
    --     end if;
    -- end process;

    process (all) begin
        for ch in 0 to CH-1 loop
            for j in 0 to KERNEL_SIZE-1 loop
                for i in 0 to KERNEL_SIZE-1 loop
                    if ((j mod KERNEL_SIZE)=0 and line_first_v2='1') or 
                    ((j mod KERNEL_SIZE)=KERNEL_SIZE-1 and line_last_v2='1') or 
                    ((i mod KERNEL_SIZE)=KERNEL_SIZE-1 and pix_first_v2='1') or 
                    ((i mod KERNEL_SIZE)=0 and pix_last_v2='1') then
                        b(ch*KERNEL_SIZE_SQ + j*KERNEL_SIZE+i) <= (others=>'0');
                    else
                        b(ch*KERNEL_SIZE_SQ + j*KERNEL_SIZE+i) <= a_buf(ch*KERNEL_SIZE_SQ + j*KERNEL_SIZE+i);
                    end if;
                end loop;
            end loop;
        end loop;
    end process;

end architecture;