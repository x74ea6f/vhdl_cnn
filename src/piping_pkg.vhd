library ieee;
library work;
use ieee.std_logic_1164.all;

package piping_pkg is
    type sl_array_t is array(natural range <>) of std_logic;
    type slv_array_t is array(natural range <>) of std_logic_vector;

    function "and"(l,r: sl_array_t) return sl_array_t;

end package;


package body piping_pkg is

    function "and"(l,r: sl_array_t) return sl_array_t is
        variable ret: sl_array_t(l'range);
    begin
        for i in ret'range loop
            ret(i) := l(i) and r(i);
        end loop;
        return ret;
    end function;

end package body;