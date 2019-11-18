-- Copyright (c) 2019 Graz University of Technology, IAIK <mario.werner@iaik.tugraz.at>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Dual port RAM for Xilinx FPGAs.
entity xilinx_TDP_RAM is
  generic(
    ADDR_WIDTH : integer := 32;
    DATA_WIDTH : integer := 64;
    ENTRIES    : integer := 32  -- number of entries  (should be a power of 2)
    );
  port(
    clk : in std_logic;  -- clock

    addra : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Port A Address bus, width determined from RAM_DEPTH
    addrb : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Port B Address bus, width determined from RAM_DEPTH
    dina  : in std_logic_vector(DATA_WIDTH-1 downto 0);  -- Port A RAM input data
    dinb  : in std_logic_vector(DATA_WIDTH-1 downto 0);  -- Port B RAM input data

    wea : in std_logic;  -- Port A Write enable
    web : in std_logic;  -- Port B Write enable
    ena : in std_logic;  -- Port A RAM Enable, for additional power savings, disable port when not in use
    enb : in std_logic;  -- Port B RAM Enable, for additional power savings, disable port when not in use

    douta : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- Port A RAM output data
    doutb : out std_logic_vector(DATA_WIDTH-1 downto 0)   -- Port B RAM output data
    );
end xilinx_TDP_RAM;

architecture arch_imp of xilinx_TDP_RAM is
  type ram_type is array (ENTRIES-1 downto 0) of std_logic_vector (DATA_WIDTH-1 downto 0);  -- 2D Array Declaration for RAM signal
  signal ram_data_a : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram_data_b : std_logic_vector(DATA_WIDTH-1 downto 0);

  shared variable ram : ram_type := (others => (others => '0'));
begin

  process(clk)
  begin
    if(clk'event and clk = '1') then
      if(ena = '1') then
        ram_data_a <= ram(to_integer(unsigned(addra)));
        if(wea = '1') then
          ram(to_integer(unsigned(addra))) := dina;
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if(clk'event and clk = '1') then
      if(enb = '1') then
        ram_data_b <= ram(to_integer(unsigned(addrb)));
        if(web = '1') then
          ram(to_integer(unsigned(addrb))) := dinb;
        end if;
      end if;
    end if;
  end process;

  douta <= ram_data_a;
  doutb <= ram_data_b;

end arch_imp;
