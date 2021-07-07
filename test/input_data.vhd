
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.piping_pkg.all;

package input_data is
    function intv_to_mem(intv: integer_vector; constant DTW: positive; constant P: positive) return mem_t;

    constant X_FC1_PRE_INT: integer_vector(0 to 8*7*7-1) := (
31,31,31,31,-51,98,31,0,0,0,-78,13,-58,0,0,0,0,-57,-105,102,0,0,0,26,-99,111,0,0,0,0,-80,-66,-89,0,0,0,0,-119,-11,-17,0,0,0,0,-33,95,47,0,0,-120,-120,-120,102,64,-120,-120,-120,-120,-120,46,-100,-40,-120,-120,-120,-120,0,-68,-1,-120,-120,-120,-121,57,23,-116,-120,-120,-120,50,92,-37,-120,-120,-120,-119,-85,-39,7,-120,-120,-120,-115,53,78,-38,-120,-120,0,0,0,-88,15,102,6,0,0,1,-38,102,-51,0,0,0,78,-13,113,37,0,0,0,-106,33,80,0,0,0,0,-72,125,-11,0,0,0,2,15,-88,-106,0,0,0,0,0,60,0,0,0,1,0,0,2,0,0,0,0,0,0,-7,75,0,0,0,0,0,24,0,32,0,0,0,-107,53,42,0,0,0,0,77,60,7,0,0,0,0,1,46,32,0,0,0,0,-49,39,13,0,0,31,31,31,-27,102,-100,32,31,31,33,-92,13,-90,32,31,31,114,88,0,31,32,31,31,-122,0,0,31,32,31,32,106,0,8,31,32,31,34,76,0,31,31,32,61,61,0,0,61,61,61,0,0,0,0,-126,39,0,0,0,0,8,6,59,0,0,0,0,-7,55,0,0,0,0,85,-116,84,0,0,0,0,31,101,114,0,0,0,0,-102,-111,0,0,0,24,6,108,-87,5,5,5,76,55,55,43,-37,-91,55,76,55,55,4,44,-28,55,76,55,55,0,108,127,55,76,55,54,124,106,56,55,76,55,3,109,117,55,55,76,55,0,-100,-6,55,55,76,55,0,-69,83,55,55,42,42,42,52,35,42,42,0,0,0,-92,-65,59,0,0,0,47,-9,-94,19,0,0,0,-102,-46,-71,0,0,0,0,-39,-51,91,0,0,0,0,117,-87,57,0,0,0,0,16,-78,0,0,0
    );
    constant X_FC1_PRE: mem_t(0 to 8*7*7-1)(8-1 downto 0);


end package;

package body input_data is
    function intv_to_mem(intv: integer_vector; constant DTW: positive; constant P: positive) return mem_t is
	variable slv: std_logic_vector(P*DTW-1 downto 0);
	variable ret: mem_t(0 to intv'length/P-1)(P*DTW-1 downto 0);
    begin
        for i in ret'range loop
            for pp in 0 to P-1 loop
            	slv(DTW*(pp+1)-1 downto pp*DTW) := std_logic_vector(to_signed(intv(i*P+pp), DTW));
	    end loop;
	    ret(i) := slv;
        end loop;
	return ret;
    end function;

    constant X_FC1_PRE: mem_t(0 to 8*7*7-1)(8-1 downto 0) := intv_to_mem(X_FC1_PRE_INT, 8, 1);

end package body;
