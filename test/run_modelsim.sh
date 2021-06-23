set -eu

## for WSL with ModelSim Windows Version
shopt -s expand_aliases
alias vlib=vlib.exe
alias vsim=vsim.exe
alias vcom=vcom.exe

libpath="../../vhdl_lib/src"
libfiles="${libpath}/str_lib.vhd ${libpath}/sim_lib.vhd ${libpath}/numeric_lib.vhd ${libpath}/file_lib.vhd"

## Usage
help="Usage: $0 test.sv tb_top.sv"
if [ $# == 0 ]; then
    echo ${help}
    exit
fi

files=($@)
top_file=${files[-1]}

## Get top module name from 1st File
top=${top_file}
top=$(basename -s .vhd ${top})

## mkdir work
if [ ! -d work ]; then
    vlib work
fi

## Compile
vcom -allowProtectedBeforeBody -2008 ${libfiles} ${files[@]}

## Sim
vsim -c ${top} -do "run -all; exit;"

