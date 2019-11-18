library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lowmc_pkg.all;

package picnic_pkg is
  constant PICNIC_S : integer := 256;
  constant DIGEST_L : integer := 512;
  constant T : integer := 438;
  constant KECCAK_R : integer := 1088;
  constant KECCAK_PAD : std_logic_vector(7 downto 0) := x"1F";
  constant MSG_LEN : integer := 512;
  constant MSG_LENGHT_END : std_logic_vector(15 downto 0) := x"0001";
  constant CHAL_ROUND_BYTE : integer := ((2 * T + 7) / 8);
  constant CHAL_ROUND : integer := CHAL_ROUND_BYTE * 8; -- size of padded challenge
  constant CHAL_PAD : std_logic_vector(CHAL_ROUND - 2 * T - 1 downto 0) := (others => '0');
  constant RS_PAD_BYTE : integer := ((R * S + 7) / 8);
  constant MAX_SIG : integer := 132856;
  constant SALT_LEN : integer := 256;

  -- fifo
  constant INIT_WIDTH : integer := 112;
  constant UNALIGNED_WIDTH : integer := 120;

  constant TAP_01_LENGTH : std_logic_vector(15 downto 0) := x"AF00";
  constant TAP_2_LENGTH : std_logic_vector(15 downto 0) := x"8F00";
  constant TAP_0_J : std_logic_vector(15 downto 0) := x"0000";
  constant TAP_1_J : std_logic_vector(15 downto 0) := x"0100";
  constant TAP_2_J : std_logic_vector(15 downto 0) := x"0200";
  constant OUT_TAP_01 : integer := KECCAK_R;
  constant OUT_TAP_2 : integer := KECCAK_R;

  constant HASH_PREFIX_0 : std_logic_vector(7 downto 0) := x"00";
  constant HASH_PREFIX_1 : std_logic_vector(7 downto 0) := x"01";
  constant HASH_PREFIX_2 : std_logic_vector(7 downto 0) := x"02";
  constant HASH_PREFIX_4 : std_logic_vector(7 downto 0) := x"04";

  constant PDI_WIDTH : integer := 128;
  constant SDI_WIDTH : integer := 64;
  constant PDO_WIDTH : integer := 128;

  -- unnecessary range violation constants (just for simulator, never in use after synthesization)
  -- TAPES
  constant RAND_01_UP : integer := OUT_TAP_01;
  constant RAND_2_UP : integer := OUT_TAP_2;
  constant HASH_01_UP : integer := OUT_TAP_01;
  constant HASH_2_UP : integer := OUT_TAP_2;
  constant HASH_01_DOWN : integer := 0;
  constant HASH_2_DOWN : integer := 0;

  -- COMMIT
  constant COMMIT_RS : integer := 0;
  constant COMMIT_FIRST : integer := KECCAK_R - DIGEST_L - K - 8;

end picnic_pkg;
