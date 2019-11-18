library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lowmc_pkg.all;

package picnic_pkg is
  constant PICNIC_S : integer := 128;
  constant DIGEST_L : integer := 256;
  constant T : integer := 219;
  constant KECCAK_R : integer := 1344;
  constant KECCAK_PAD : std_logic_vector(7 downto 0) := x"1F";
  constant MSG_LEN : integer := 512;
  constant MSG_LENGHT_END : std_logic_vector(15 downto 0) := x"8000";
  constant CHAL_ROUND_BYTE : integer := ((2 * T + 7) / 8);
  constant CHAL_ROUND : integer := CHAL_ROUND_BYTE * 8; -- size of padded challenge
  constant CHAL_PAD : std_logic_vector(CHAL_ROUND - 2 * T - 1 downto 0) := (others => '0');
  constant RS_PAD_BYTE : integer := ((R * S + 7) / 8);
  constant MAX_SIG : integer := 34032;
  constant SALT_LEN : integer := 256;

  -- fifo
  constant INIT_WIDTH : integer := 56;
  constant UNALIGNED_WIDTH : integer := 88;

  constant TAP_01_LENGTH : std_logic_vector(15 downto 0) := x"5B00";
  constant TAP_2_LENGTH : std_logic_vector(15 downto 0) := x"4B00";
  constant TAP_0_J : std_logic_vector(15 downto 0) := x"0000";
  constant TAP_1_J : std_logic_vector(15 downto 0) := x"0100";
  constant TAP_2_J : std_logic_vector(15 downto 0) := x"0200";
  constant OUT_TAP_01 : integer := K + R * S;
  constant OUT_TAP_2 : integer := R * S;

  constant HASH_PREFIX_0 : std_logic_vector(7 downto 0) := x"00";
  constant HASH_PREFIX_1 : std_logic_vector(7 downto 0) := x"01";
  constant HASH_PREFIX_2 : std_logic_vector(7 downto 0) := x"02";
  constant HASH_PREFIX_4 : std_logic_vector(7 downto 0) := x"04";

  constant PDI_WIDTH : integer := 128;
  constant SDI_WIDTH : integer := 64;
  constant PDO_WIDTH : integer := 128;

  -- unnecessary range violation constants (just for simulator, never in use after synthesization)
  -- TAPES
  constant RAND_01_UP : integer := R * S;
  constant RAND_2_UP : integer := R * S;
  constant HASH_01_UP : integer := OUT_TAP_01 - K;
  constant HASH_2_UP : integer := OUT_TAP_2;
  constant HASH_01_DOWN : integer := OUT_TAP_01 - K - R * S;
  constant HASH_2_DOWN : integer := OUT_TAP_2 - R * S;

  -- COMMIT
  constant COMMIT_RS : integer := R * S;
  constant COMMIT_FIRST : integer := 0;

end picnic_pkg;
