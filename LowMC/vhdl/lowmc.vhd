library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc is
  port(
    -- Clock and Reset
    signal Clk_CI   : in std_logic;
    signal Rst_RBI  : in std_logic;
    -- Input signals
    signal Plain_DI  : in std_logic_vector(N - 1 downto 0);
    signal Key_DI    : in std_logic_vector(K - 1 downto 0);
    signal Start_SI  : in std_logic;
    -- Output signals
    signal Finish_SO : out std_logic;
    signal Cipher_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc is
  type states is (init, rounds, l_round);
  signal State_DN, State_DP : states;
  signal Data_DN, Data_DP : std_logic_vector(N - 1 downto 0);
  signal Data_Round_out, Data_Round_r_out : std_logic_vector(N - 1 downto 0);
  signal K0_out : std_logic_vector(N - 1 downto 0);
  signal Round_DN, Round_DP : integer range 0 to R;

  component lowmc_matrix_nk
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(K - 1 downto 0);
      -- Output signals
      signal Data_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component lowmc_round_i_multiplex
    port(
      -- Input signals
      signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
      signal State_L_DI : in std_logic_vector((N - S) - 1 downto 0);
      signal Key_DI : in std_logic_vector(K - 1 downto 0);
      signal Round_DI : in integer range 0 to R;
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

  -- a round
  K0 : lowmc_matrix_nk
  port map(
    Data_DI => Key_DI,
    Data_DO => K0_out
  );

  ROUND_I : lowmc_round_i_multiplex
  port map(
    State_NL_DI => Data_DP(N - 1 downto N - S),
    State_L_DI => Data_DP((N - S) - 1 downto 0),
    Key_DI => Key_DI,
    Round_DI => Round_DP,
    State_NL_DO => Data_Round_out(N - 1 downto N - S),
    State_L_DO => Data_Round_out((N - S) - 1 downto 0)
  );

  ROUND_R : lowmc_round_r
  port map(
    State_NL_DI => Data_DP(N - 1 downto N - S),
    State_L_DI => Data_DP((N - S) - 1 downto 0),
    Key_DI => Key_DI,
    State_DO => Data_Round_r_out
  );

  -- output logic
  process (State_DP, Data_DP, Round_DP, K0_out, Data_Round_out, Start_SI, Plain_DI, Data_Round_r_out)
  begin
    -- default
    Round_DN <= Round_DP;
    Data_DN <= Data_DP;
    Finish_SO <= '0';
    Cipher_DO <= Data_DP;

    -- output
    case State_DP is
      when init =>
        Round_DN <= 0;
        if Start_SI = '1' then
          Data_DN <= Plain_DI xor K0_out xor C0;
        end if;
        Finish_SO <= '1';
      when rounds =>
        Data_DN <= Data_Round_out;
        if Round_DP < R - 2 then
          Round_DN <= Round_DP + 1;
        end if;
      when l_round =>
        Data_DN <= Data_Round_r_out;
    end case;
  end process;

  -- next state logic
  process (State_DP, Start_SI, Round_DP)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          State_DN <= rounds;
        end if;
      when rounds =>
        if Round_DP < R - 2 then
          State_DN <= rounds;
        else
          State_DN <= l_round;
        end if;
      when l_round =>
        State_DN <= init;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RBI)
  begin  -- process register_p
    if Rst_RBI = '0' then               -- asynchronous reset (active low)
      Round_DP   <= 0;
      Data_DP    <= (others => '0');
      State_DP   <= init;
    elsif Clk_CI'event and Clk_CI = '1' then  -- rising clock edge
      Round_DP   <= Round_DN;
      Data_DP    <= Data_DN;
      State_DP   <= State_DN;
    end if;
  end process;

end behavorial;
