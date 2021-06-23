library ieee;
library work;
use ieee.std_logic_1164.all;

package piping_pkg is
    type sl_array_t is array(natural range <>) of std_logic;
    type slv_array_t is array(natural range <>) of std_logic_vector;
end package;
