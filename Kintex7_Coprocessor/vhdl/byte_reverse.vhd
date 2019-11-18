library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_reverse is
  generic(
    DATA_WIDTH : integer := 128 -- multiple of 8
  );
  port(
    -- clk and reset (only for axi interface)
    clk : in std_logic;
    rst : in std_logic;
    -- Input
    di_data  : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    di_valid : in std_logic;
    di_ready : out std_logic;
    -- Output
    do_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    do_valid : out std_logic;
    do_ready : in std_logic
  );
end byte_reverse;

architecture behavorial of byte_reverse is
begin

  REV_GEN : for i in 0 to DATA_WIDTH / 8 - 1 generate
    do_data((i + 1) * 8 - 1 downto i * 8) <=
          di_data((DATA_WIDTH / 8 - i) * 8 - 1
                downto (DATA_WIDTH / 8 - 1 - i) * 8);
    end generate REV_GEN;

  do_valid <= di_valid;
  di_ready <= do_ready;

end behavorial;