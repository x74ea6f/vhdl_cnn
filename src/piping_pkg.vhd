library ieee;
library work;
use ieee.std_logic_1164.all;

package piping_pkg is
    -- std_logic/_vectorの配列
    type sl_array_t is array(natural range <>) of std_logic;
    type slv_array_t is array(natural range <>) of std_logic_vector;

    -- sl_array_t演算
    function "and"(l,r: sl_array_t) return sl_array_t;
    function "not"(l: sl_array_t) return sl_array_t;

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

    function "not"(l: sl_array_t) return sl_array_t is
        variable ret: sl_array_t(l'range);
    begin
        for i in ret'range loop
            ret(i) := not l(i);
        end loop;
        return ret;
    end function;

end package body;