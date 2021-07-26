
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.piping_pkg.all;

package input_data is
    function intv_to_mem(intv: integer_vector; constant DTW: positive; constant P: positive) return mem_t;

    constant X_FC1_PRE_INT: integer_vector(0 to 8*7*7-1) := (
0,0,0,1,3,1,0,0,0,0,4,5,1,0,0,0,1,5,6,1,0,0,0,2,6,4,0,0,0,0,5,7,2,0,0,0,0,5,7,1,0,0,0,0,1,2,0,0,0,0,0,0,2,2,0,0,0,0,0,3,0,0,0,0,0,1,4,0,0,0,0,0,5,4,1,0,0,0,0,5,1,0,0,0,0,0,4,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,2,1,0,0,0,0,5,6,1,0,0,0,1,7,7,0,0,0,0,3,8,5,0,0,0,0,5,8,3,0,0,0,0,7,9,1,0,0,0,0,3,3,0,0,0,0,0,0,3,2,0,0,0,0,0,7,1,0,0,0,0,2,7,0,0,0,0,0,7,8,0,0,0,0,0,10,4,0,0,0,0,0,10,0,0,0,0,0,0,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,1,0,1,0,0,0,1,1,2,0,0,0,0,2,0,0,0,0,0,0,7,7,2,0,0,0,0,6,6,0,0,0,0,0,0,2,2,0,0,0,0,0,4,2,0,0,0,0,1,5,2,1,0,0,0,4,6,1,0,0,0,0,6,4,0,0,0,0,0,6,2,1,0,0,0,0,3,4,0,0,0,0,0,0,0,2,1,0,0,0,0,4,6,1,0,0,0,0,7,6,0,0,0,0,1,7,3,0,0,0,0,4,8,0,0,0,0,0,6,8,0,0,0,0,0,3,0,0,0,0,0,0,0,1,2,0,0,0,0,0,6,2,0,0,0,0,0,6,0,0,0,0,0,4,7,0,0,0,0,0,8,5,0,0,0,0,0,8,0,0,0,0,0,0,3,0,0,0,0
    );
    constant X_FC1_PRE: mem_t(0 to 8*7*7-1)(8-1 downto 0);

    constant X_FC1_POST_INT: integer_vector(0 to 32-1):=(
0,3,4,5,2,8,9,5,5,2,0,9,14,0,0,7,2,7,8,0,0,7,5,0,4,5,5,0,9,6,9,8
    );
    constant X_FC1_POST: mem_t(0 to 32-1)(8-1 downto 0);

    constant X_FC2_PRE_INT: integer_vector(0 to 32-1) := (
0,3,4,5,2,8,9,5,5,2,0,9,14,0,0,7,2,7,8,0,0,7,5,0,4,5,5,0,9,6,9,8
    );
    constant X_FC2_PRE: mem_t(0 to 32-1)(8-1 downto 0);

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
    constant X_FC1_POST: mem_t(0 to 32-1)(8-1 downto 0) := intv_to_mem(X_FC1_POST_INT, 8, 1);

    constant X_FC2_PRE: mem_t(0 to 32-1)(8-1 downto 0) := intv_to_mem(X_FC2_PRE_INT, 8, 1);

end package body;
