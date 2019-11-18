library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_pipeline is
  port(
    -- Clock and Reset
    signal Clk_CI   : in std_logic;
    signal Rst_RBI  : in std_logic;
    -- Input signals
    signal Plain_DI  : in std_logic_vector(N - 1 downto 0);
    signal Key_DI    : in std_logic_vector(K - 1 downto 0);
    signal Valid_SI  : in std_logic;
    signal Ready_SI  : in std_logic;
    -- Output signals
    signal Cipher_DO : out std_logic_vector(N - 1 downto 0);
    signal Valid_SO  : out std_logic
  );
end entity;

architecture behavorial of lowmc_pipeline is
  type REG_TYPE is array(0 to R - 1) of std_logic_vector(N - 1 downto 0);
  signal Reg_DN, Reg_DP : REG_TYPE;
  signal Valid_SN, Valid_SP : std_logic_vector(0 to R - 1);
  signal K0_out : std_logic_vector(0 to N - 1);

  component lowmc_matrix_nk
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(K - 1 downto 0);
      -- Output signals
      signal Data_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component lowmc_round_i
    generic(
      constant Round_DI : in integer range 0 to R
    );
    port(
      -- Input signals
      signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
      signal State_L_DI : in std_logic_vector((N - S) - 1 downto 0);
      signal Key_DI : in std_logic_vector(K - 1 downto 0);
      -- Output signals
      signal State_NL_DO : out std_logic_vector(S - 1 downto 0);
      signal State_L_DO : out std_logic_vector((N - S) - 1 downto 0)
    );
  end component;

  component lowmc_round_r
    port(
      -- Input signals
      signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
      signal State_L_DI : in std_logic_vector((N - S) - 1 downto 0);
      signal Key_DI : in std_logic_vector(K - 1 downto 0);
      -- Output signals
      signal State_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

begin

  --pre round
  K0 : lowmc_matrix_nk
  port map(
    Data_DI => Key_DI,
    Data_DO => K0_out
  );

  Reg_DN(0) <= Plain_DI xor K0_out xor C0;
  Valid_SN(0) <= Valid_SI;

  -- the rounds
  ROUND_GEN : for i in 0 to R - 2 generate
    ROUND_I : lowmc_round_i
    generic map(
      Round_DI => i
    )
    port map(
      State_NL_DI => Reg_DP(i)(N - 1 downto N - S),
      State_L_DI => Reg_DP(i)((N - S) - 1 downto 0),
      Key_DI => Key_DI,
      State_NL_DO => Reg_DN(i + 1)(N - 1 downto N - S),
      State_L_DO => Reg_DN(i + 1)((N - S) - 1 downto 0)
    );

    Valid_SN(i + 1) <= Valid_SP(i);
  end generate ROUND_GEN;

  -- last round
  ROUND_R : lowmc_round_r
  port map(
    State_NL_DI => Reg_DP(R - 1)(N - 1 downto N - S),
    State_L_DI => Reg_DP(R - 1)((N - S) - 1 downto 0),
    Key_DI => Key_DI,
    State_DO => Cipher_DO
  );

  Valid_SO <= Valid_SP(R - 1);

  -- the registers
  process (Clk_CI, Rst_RBI)
  begin
    if Rst_RBI = '0' then               -- asynchronous reset
      Reg_DP <= (others => (others => '0'));
      Valid_SP <= (others => '0');
    elsif Clk_CI'event and Clk_CI = '1' then  -- rising clock
      if Ready_SI = '1' then
        Reg_DP <= Reg_DN;
        Valid_SP <= Valid_SN;
      end if;
    end if;
  end process;

end behavorial;
