
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.piping_pkg.all;

package fc2_rom is
    constant FC2_M: positive := 32;
    constant FC2_N: positive := 10;
    constant FC2_DTW: positive := 8;
    constant FC2_P: positive := 1;

    -- function intv_to_mem(intv: integer_vector; constant DTW: positive; constant P: positive) return mem_t;

    constant FC2_W_INT: integer_vector(0 to FC2_M*FC2_N-1) := (
12,24,33,32,-16,-43,-41,-59,13,-14,-4,-23,-58,11,34,18,24,-58,-24,-21,7,-39,53,-10,18,-5,15,-30,62,-27,55,24,
-22,22,58,-62,-37,40,-54,31,23,-44,36,56,-12,21,-65,7,-48,52,52,-33,2,45,-58,-42,-46,29,-14,37,-30,-41,44,8,
65,-45,54,32,-48,-9,-23,13,-15,32,-36,40,-30,-33,31,-29,-47,-15,-36,26,-60,-32,-25,51,18,24,45,4,3,-36,23,-1,
-17,-27,-10,10,-42,32,-13,-29,-50,61,-26,0,4,-25,-42,-30,-32,-18,2,-34,37,-51,-28,-36,-8,-54,50,21,-44,33,-27,24,
-23,46,-31,-52,38,-49,-23,41,61,-77,-27,-27,-2,14,22,-104,-5,0,47,12,-55,-3,-7,7,-13,-29,29,8,14,27,-31,-16,
-104,-55,-54,36,8,-38,-19,-17,-32,-19,-30,-1,5,-15,-3,-12,-3,45,11,19,-8,4,-40,5,26,-59,-73,21,-77,-10,-32,39,
-64,1,-7,25,-8,-99,44,13,-39,-14,-13,2,-48,-11,-6,8,8,-25,33,-21,23,5,15,-44,-36,33,-63,16,42,-23,52,-2,
-22,-62,32,-36,18,5,-62,-31,-3,-16,21,41,-40,-1,-71,-9,-19,15,-9,-19,-20,52,40,58,0,-31,53,-7,-24,42,-13,-60,
13,14,-32,-18,38,25,31,29,-128,-42,-17,-23,29,-8,-47,-24,-43,-45,6,38,-75,20,34,-22,22,-1,-11,33,45,-5,-34,-28,
0,36,9,0,40,31,5,-85,46,30,5,-102,-7,27,-6,-51,-47,2,35,24,23,-14,29,47,-19,23,-16,-30,13,-22,-68,-36
    );

    constant FC2_B_INT: integer_vector(0 to FC2_N-1) := (
-32,-20,-28,14,-4,30,-5,9,-13,-36
    );
    constant FC2_SCALE: positive := 148;
    constant FC2_SCALE_SFT: positive := 15;

    constant FC2_W: mem_t(0 to FC2_M-1)(FC2_N*FC2_DTW-1 downto 0);
    constant FC2_B: mem_t(0 to FC2_N/FC2_P-1)(FC2_P*FC2_DTW-1 downto 0);

end package;

package body fc2_rom is
    -- with change ColRow
    function intv_to_mem(intv: integer_vector; constant DTW,P,M: positive) return mem_t is
        variable slv: std_logic_vector(P*DTW-1 downto 0);
        variable ret: mem_t(0 to intv'length/P-1)(P*DTW-1 downto 0);
    begin
        for i in ret'range loop
            for pp in 0 to P-1 loop
                slv((pp+1)*DTW-1 downto pp*DTW) := std_logic_vector(to_signed(intv(M*pp+i), DTW));
            end loop;
            ret(i) := slv;
        end loop;
        return ret;
    end function;

    constant FC2_W: mem_t(0 to FC2_M-1)(FC2_N*FC2_DTW-1 downto 0) := intv_to_mem(FC2_W_INT, FC2_DTW, FC2_N, FC2_M);
    constant FC2_B: mem_t(0 to FC2_N/FC2_P-1)(FC2_P*FC2_DTW-1 downto 0) := intv_to_mem(FC2_B_INT, FC2_DTW, FC2_P, 1);

end package body;
