
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.piping_pkg.all;

package input_data is
    function intv_to_mem(intv: integer_vector; constant DTW: positive; constant P: positive) return mem_t;

    constant X_FC1_PRE_INT: integer_vector(0 to 8*7*7-1) := (
31,31,31,31,127,98,31,0,0,0,127,127,127,0,0,0,0,127,127,102,0,0,0,26,127,127,0,0,0,0,127,127,127,0,0,0,0,127,127,127,0,0,0,0,127,127,47,0,0,127,127,127,102,64,127,127,127,127,127,46,127,127,127,127,127,127,0,127,127,127,127,127,127,57,127,127,127,127,127,50,92,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,0,0,0,127,127,102,6,0,0,1,127,127,127,0,0,0,78,127,127,37,0,0,0,127,127,127,0,0,0,0,127,127,127,0,0,0,2,127,127,127,0,0,0,0,0,60,0,0,0,1,0,0,2,0,0,0,0,0,0,127,75,0,0,0,0,0,127,0,32,0,0,0,127,127,42,0,0,0,0,127,127,7,0,0,0,0,127,127,32,0,0,0,0,127,127,13,0,0,31,31,31,127,127,127,32,31,31,33,127,127,127,32,31,31,114,88,0,31,32,31,31,127,0,0,31,32,31,32,106,0,8,31,32,31,34,76,0,31,31,32,61,61,0,0,61,61,61,0,0,0,0,127,39,0,0,0,0,127,127,59,0,0,0,0,127,127,0,0,0,0,85,127,127,0,0,0,0,127,127,114,0,0,0,0,127,127,0,0,0,24,6,127,127,5,5,5,76,55,55,43,127,127,55,76,55,55,4,127,127,55,76,55,55,0,127,127,55,76,55,54,124,127,56,55,76,55,3,127,127,55,55,76,55,0,127,127,55,55,76,55,0,127,83,55,55,42,42,42,52,35,42,42,0,0,0,127,127,59,0,0,0,47,127,127,19,0,0,0,127,127,127,0,0,0,0,127,127,91,0,0,0,0,127,127,57,0,0,0,0,16,127,0,0,0
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
