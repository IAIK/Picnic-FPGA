library ieee;
use ieee.std_logic_1164.all;

library work;
package protocol_pkg is
  constant pad_32 : std_logic_vector(31 downto 0) := (others => '0');
  constant pad_96 : std_logic_vector(95 downto 0) := (others => '0');
  constant pad_112 : std_logic_vector(111 downto 0) := (others => '0');
  -- instruction
  constant I_ENC : std_logic_vector(15 downto 0) := x"0000";
  constant I_DEC : std_logic_vector(15 downto 0) := x"1000";
  constant I_SGN : std_logic_vector(15 downto 0) := x"2000";
  constant I_VER : std_logic_vector(15 downto 0) := x"3000";
  constant I_ENCAP : std_logic_vector(15 downto 0) := x"4000";
  constant I_DECAP : std_logic_vector(15 downto 0) := x"5000";
  constant I_LDPRIVKEY : std_logic_vector(15 downto 0) := x"6000";

  -- status
  constant S_SUCCESS : std_logic_vector(15 downto 0) := x"E000";
  constant S_FAILURE : std_logic_vector(15 downto 0) := x"F000";

  -- segment header
  -- info (including reserved)
  constant H_MSG : std_logic_vector(5  downto 0) := "001000";
  constant H_SIG : std_logic_vector(5  downto 0) := "010000";
  constant H_CIP : std_logic_vector(5  downto 0) := "011000";
  constant H_PARAM : std_logic_vector(5  downto 0) := "100000";
  constant H_PUB : std_logic_vector(5  downto 0) := "101000";
  constant H_PRIV : std_logic_vector(5  downto 0) := "110000";
  constant H_SS : std_logic_vector(5  downto 0) := "111000";
  constant H_LEN_WIDTH : integer := 16;

  -- Picnic sign spezific:
  constant L5_H_PUB : std_logic_vector(31 downto 0) := H_PUB & "00" & x"00" & x"0040";
  constant L5_H_PRIV : std_logic_vector(31 downto 0) := H_PRIV & "11" & x"00" & x"0020";

  constant L5_H_MSG : std_logic_vector(31 downto 0) := H_MSG & "11" & x"00" & x"0040";

  constant L5_SEG_BLOCKS : integer := (65535 / 16);
  constant L5_BYTES_PER_SEG : integer := L5_SEG_BLOCKS * 16;

end protocol_pkg;