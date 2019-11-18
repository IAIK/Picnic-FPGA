library ieee;
use ieee.std_logic_1164.all;

library work;

package keccak_pkg is
  constant CUBE_LEN : integer := 5;
  constant W : integer := 64;
  constant B : integer := 1600;
  constant KECCAK_N : integer := 24;

  subtype T_ROW is std_logic_vector((W - 1) downto 0);
  type T_COLUMN is array (0 to CUBE_LEN - 1) of T_ROW;
  type T_STATE is array (0 to CUBE_LEN - 1) of T_COLUMN;

  type T_ROT is array(0 to 24) of integer;
  type T_RC is array(0 to KECCAK_N - 1) of std_logic_vector((W - 1) downto 0);

  constant ROT : T_ROT := (
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39,
    41, 45, 15, 21, 8, 18, 2, 61, 56, 14
  );

  constant RC : T_RC := (
    x"0000000000000001",
    x"0000000000008082",
    x"800000000000808a",
    x"8000000080008000",
    x"000000000000808b",
    x"0000000080000001",
    x"8000000080008081",
    x"8000000000008009",
    x"000000000000008a",
    x"0000000000000088",
    x"0000000080008009",
    x"000000008000000a",
    x"000000008000808b",
    x"800000000000008b",
    x"8000000000008089",
    x"8000000000008003",
    x"8000000000008002",
    x"8000000000000080",
    x"000000000000800a",
    x"800000008000000a",
    x"8000000080008081",
    x"8000000000008080",
    x"0000000080000001",
    x"8000000080008008"
  );

end keccak_pkg;