
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.piping_pkg.all;

package input_data is
    function intv_to_mem(intv: integer_vector; constant DTW: positive; constant P: positive) return mem_t;

    constant X_FC1_PRE_INT: integer_vector(0 to 8*7*7-1) := (
31,31,31,-60,-75,-96,69,0,32,57,74,104,-19,53,0,69,123,-119,44,-123,43,0,34,24,26,-118,-34,19,67,-71,-70,-126,-60,-87,108,22,39,98,-101,-34,-107,-97,0,10,-118,-62,-123,40,0,-120,-120,91,47,0,0,103,-120,-120,34,0,-87,86,-63,-120,97,0,-33,-29,94,-120,103,0,-97,-54,0,0,15,8,121,0,0,1,-125,2,25,26,20,11,122,-39,-126,-120,12,-27,29,13,-45,-120,0,9,121,29,33,-60,74,0,68,5,-23,126,88,33,1,119,28,-17,42,-41,38,103,126,-75,66,-90,-66,0,71,-31,-89,-119,-7,121,-114,0,0,-93,-1,80,-110,23,0,0,0,0,0,0,0,1,0,0,28,30,0,0,0,0,54,11,-73,-6,0,0,-121,-25,-14,-102,-124,0,20,-118,80,-111,56,0,0,83,-124,25,118,-65,59,-36,11,-62,123,32,-97,39,-98,0,0,71,-100,-20,7,0,31,43,-67,-127,-76,39,82,31,91,68,-117,36,0,32,33,113,79,0,-105,89,100,120,-41,0,-11,36,-125,-124,13,0,6,0,0,0,0,13,0,0,0,0,0,32,61,61,61,61,61,61,61,0,0,0,-48,-21,-64,0,0,0,75,-31,-124,-110,0,0,126,106,-87,17,-124,10,0,-38,7,-115,-42,-21,35,79,48,-48,0,-96,87,-58,78,17,-63,-86,-60,-39,0,24,72,-47,-112,33,5,5,76,55,48,25,87,122,114,76,55,0,0,-36,21,96,76,43,0,-29,54,-57,-126,76,0,-52,-9,106,-97,5,76,0,-57,111,65,78,-41,76,0,0,7,33,-59,-109,76,52,14,37,65,77,55,42,42,46,107,72,-26,21,0,29,48,55,-74,-36,4,0,-49,34,124,33,0,0,73,76,123,109,102,-125,39,100,-78,21,14,-45,-116,-9,0,-15,-79,-81,36,-118,34,0,0,0,0,0,0,0
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
