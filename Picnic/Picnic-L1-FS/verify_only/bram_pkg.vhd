library ieee;
use ieee.std_logic_1164.all;

library work;
package bram_pkg is
  -- seed RAM
  constant SEED_ADDR_WIDTH : integer := 32;
  constant SEED_DATA_WIDTH : integer := 128;
  constant SEED_ENTRIES : integer := 256;

  -- view_ishare RAM
  constant VIEW_I_ADDR_WIDTH : integer := 32;
  constant VIEW_I_DATA_WIDTH : integer := 64;
  constant VIEW_I_ENTRIES : integer := 512;

  -- view_oshare RAM
  constant VIEW_O_ADDR_WIDTH : integer := 32;
  constant VIEW_O_DATA_WIDTH : integer := 64;
  constant VIEW_O_ENTRIES : integer := 512;

  -- view_ts RAM
  constant VIEW_TS_ADDR_WIDTH : integer := 32;
  constant VIEW_TS_DATA_WIDTH : integer := 64;
  constant VIEW_TS_ENTRIES : integer := 4096;
  -- entries for one TS:
  constant VIEW_ENTRIE_PER_TS : integer := 10;
  constant RS_LAST_SEG : integer := 24;
  constant RS_PAD : std_logic_vector(VIEW_TS_DATA_WIDTH - RS_LAST_SEG - 1 downto 0) := x"0000000000";

  -- commit RAM
  constant COMMIT_ADDR_WIDTH : integer := 32;
  constant COMMIT_DATA_WIDTH : integer := 64;
  constant COMMIT_ENTRIES : integer := 1024;


end bram_pkg;
