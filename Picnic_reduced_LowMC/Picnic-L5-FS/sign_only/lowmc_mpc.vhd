library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_mpc is
  port(
    -- Clock and Reset
    signal Clk_CI   : in std_logic;
    signal Rst_RI   : in std_logic;
    -- Input signals
    signal Plain_DI  : in std_logic_vector(N - 1 downto 0);
    signal Key_DI    : in std_logic_vector(K - 1 downto 0);
    signal Key_R0_DI : in std_logic_vector(K - 1 downto 0);
    signal Key_R1_DI : in std_logic_vector(K - 1 downto 0);
    signal Rand_0_DI : in std_logic_vector(R * S - 1 downto 0);
    signal Rand_1_DI : in std_logic_vector(R * S - 1 downto 0);
    signal Rand_2_DI : in std_logic_vector(R * S - 1 downto 0);
    signal Start_SI  : in std_logic;
    signal Init_SI   : in std_logic;
    -- Output signals
    signal Finish_SO : out std_logic;
    signal Cipher_0_DO : out std_logic_vector(N - 1 downto 0);
    signal Cipher_1_DO : out std_logic_vector(N - 1 downto 0);
    signal Cipher_2_DO : out std_logic_vector(N - 1 downto 0);
    signal TS_0_DO : out std_logic_vector(R * S - 1 downto 0);
    signal TS_1_DO : out std_logic_vector(R * S - 1 downto 0);
    signal TS_2_DO : out std_logic_vector(R * S - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_mpc is
  type states is (init, sbox, rounds, i_sbox, i_rounds);
  signal State_DN, State_DP : states;
  signal Data_0_DN, Data_0_DP : std_logic_vector(N - 1 downto 0);
  signal Data_1_DN, Data_1_DP : std_logic_vector(N - 1 downto 0);
  signal Data_Round_0_out : std_logic_vector(N - 1 downto 0);
  signal Data_Round_1_out : std_logic_vector(N - 1 downto 0);
  signal K0_0_out, K0_1_out : std_logic_vector(N - 1 downto 0);
  signal Key_0_out, Key_1_out : std_logic_vector(S - 1 downto 0);
  signal Round_DN, Round_DP : integer range 0 to R;

  signal Cipher_prec_DN, Cipher_prec_DP : std_logic_vector(N - 1 downto 0);
  signal Round_in_prec_DN, Round_in_prec_DP : T_RS_MATRIX;
  signal Key_0_in : std_logic_vector(K - 1 downto 0);
  signal TS_0_DN, TS_0_DP : T_RS_MATRIX;
  signal TS_1_DN, TS_1_DP : T_RS_MATRIX;
  signal TS_2_DN, TS_2_DP : T_RS_MATRIX;
  signal TS_0_out : std_logic_vector(S - 1 downto 0);
  signal TS_1_out : std_logic_vector(S - 1 downto 0);
  signal TS_2_out : std_logic_vector(S - 1 downto 0);
  signal Sbox_0_DN, Sbox_0_DP : std_logic_vector(N - 1 downto 0);
  signal Sbox_1_DN, Sbox_1_DP : std_logic_vector(N - 1 downto 0);
  signal Rand_0_in, Rand_1_in, Rand_2_in : std_logic_vector(S - 1 downto 0);
  signal State_NL_1_in, State_NL_2_in : std_logic_vector(S - 1 downto 0);
  signal Sbox_0_out, Sbox_1_out : std_logic_vector(S - 1 downto 0);

  component lowmc_matrix_nk
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(K - 1 downto 0);
      -- Output signals
      signal Data_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component lowmc_matrix_sk
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(K - 1 downto 0);
      signal Round_DI : in integer range 0 to R;
      -- Output signals
      signal Data_DO : out std_logic_vector(S - 1 downto 0)
    );
  end component;

  component lowmc_matrix_nn is
    port(
      -- Input signals
      signal State_DI   : in std_logic_vector(N - 1 downto 0);
      -- Output signals
      signal State_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component lowmc_sbox_mpc
  port(
    -- Input signals
    signal State_NL_0_DI : in std_logic_vector(S - 1 downto 0);
    signal State_NL_1_DI : in std_logic_vector(S - 1 downto 0);
    signal State_NL_2_DI : in std_logic_vector(S - 1 downto 0);
    signal Rand_0_DI     : in std_logic_vector(S - 1 downto 0);
    signal Rand_1_DI     : in std_logic_vector(S - 1 downto 0);
    signal Rand_2_DI     : in std_logic_vector(S - 1 downto 0);
    -- Output signals
    signal State_NL_0_DO : out std_logic_vector(S - 1 downto 0);
    signal State_NL_1_DO : out std_logic_vector(S - 1 downto 0);
    signal TS_0_DO       : out std_logic_vector(S - 1 downto 0);
    signal TS_1_DO       : out std_logic_vector(S - 1 downto 0);
    signal TS_2_DO       : out std_logic_vector(S - 1 downto 0)
  );
end component;

begin

  K0_0 : lowmc_matrix_nk
  port map(
    Data_DI => Key_0_in,
    Data_DO => K0_0_out
  );

  K0_1 : lowmc_matrix_nk
  port map(
    Data_DI => Key_R1_DI,
    Data_DO => K0_1_out
  );

  -- S x K Matrix
  MATRIX_SK_0 : lowmc_matrix_sk
  port map(
    Data_DI => Key_0_in,
    Round_DI => Round_DP,
    Data_DO => Key_0_out
  );

  -- S x K Matrix
  MATRIX_SK_1 : lowmc_matrix_sk
  port map(
    Data_DI => Key_R1_DI,
    Round_DI => Round_DP,
    Data_DO => Key_1_out
  );


  -- SBOX_MPC
  SBOX_MPC : lowmc_sbox_mpc
  port map(
    State_NL_0_DI => Data_0_DP(N - 1 downto N - S),
    State_NL_1_DI => State_NL_1_in,
    State_NL_2_DI => State_NL_2_in,
    Rand_0_DI => Rand_0_in,
    Rand_1_DI => Rand_1_in,
    Rand_2_DI => Rand_2_in,
    State_NL_0_DO => Sbox_0_out,
    State_NL_1_DO => Sbox_1_out,
    TS_0_DO => TS_0_out,
    TS_1_DO => TS_1_out,
    TS_2_DO => TS_2_out
  );

  -- N x N Matrix
  MATRIX_NN_0 : lowmc_matrix_nn
  port map(
    State_DI => Sbox_0_DP,
    State_DO => Data_Round_0_out
  );

  -- N x N Matrix
  MATRIX_NN_1 : lowmc_matrix_nn
  port map(
    State_DI => Sbox_1_DP,
    State_DO => Data_Round_1_out
  );

  -- output logic
  process (State_DP, Data_0_DP, Data_1_DP, Cipher_prec_DP, Round_in_prec_DP, Round_DP, K0_0_out, K0_1_out,  Data_Round_0_out, Data_Round_1_out, Start_SI, Init_SI, Plain_DI, TS_0_out, TS_1_out, TS_2_out, TS_0_DP, TS_1_DP, TS_2_DP, Key_R0_DI, Key_DI, Sbox_0_DP, Sbox_1_DP, Sbox_0_out, Sbox_1_out, Rand_0_DI, Rand_1_DI, Rand_2_DI, Key_0_out, Key_1_out)
    variable first_round_in : std_logic_vector(N - 1 downto 0);
  begin
    -- default
    Round_DN <= Round_DP;
    Data_0_DN <= Data_0_DP;
    Data_1_DN <= Data_1_DP;
    Finish_SO <= '0';
    Sbox_0_DN <= Sbox_0_DP;
    Sbox_1_DN <= Sbox_1_DP;
    Cipher_0_DO <= Data_0_DP;
    Cipher_1_DO <= Data_1_DP;
    Cipher_2_DO <= Data_0_DP xor Data_1_DP xor Cipher_prec_DP; -- third share
    Cipher_prec_DN <= Cipher_prec_DP;
    Round_in_prec_DN <= Round_in_prec_DP;
    TS_0_DN <= TS_0_DP;
    TS_1_DN <= TS_1_DP;
    TS_2_DN <= TS_2_DP;
    Key_0_in <= Key_R0_DI;

    State_NL_1_in <= (others => '0');
    State_NL_2_in <= (others => '0');
    Rand_0_in <= (others => '0');
    Rand_1_in <= (others => '0');
    Rand_2_in <= (others => '0');

    for i in 0 to R - 1 loop
      TS_0_DO(R * S - i * S - 1 downto R * S - (i + 1) * S) <= TS_0_DP(i);
      TS_1_DO(R * S - i * S - 1 downto R * S - (i + 1) * S) <= TS_1_DP(i);
      TS_2_DO(R * S - i * S - 1 downto R * S - (i + 1) * S) <= TS_2_DP(i);
    end loop;

    -- output
    case State_DP is
      when init =>
        Round_DN <= 0;
        if Init_SI = '1' then
          Key_0_in <= Key_DI;
          first_round_in := Plain_DI xor K0_0_out xor C0;
          Data_0_DN <= first_round_in;
          Round_in_prec_DN(0) <= first_round_in(N - 1 downto N - S);
        elsif Start_SI = '1' then
          Data_0_DN <= Plain_DI xor K0_0_out xor C0;
          Data_1_DN <= K0_1_out;
          TS_0_DN <= (others => (others => '0'));
          TS_1_DN <= (others => (others => '0'));
          TS_2_DN <= (others => (others => '0'));
        end if;
        Finish_SO <= '1';
      when sbox =>
        State_NL_1_in <= Data_1_DP(N - 1 downto N - S);
        State_NL_2_in <= Data_0_DP(N - 1 downto N - S) xor Data_1_DP(N - 1 downto N - S) xor Round_in_prec_DP(Round_DP);
        Rand_0_in <= Rand_0_DI(R * S - (Round_DP) * S - 1 downto R * S - (Round_DP + 1) * S);
        Rand_1_in <= Rand_1_DI(R * S - (Round_DP) * S - 1 downto R * S - (Round_DP + 1) * S);
        Rand_2_in <= Rand_2_DI(R * S - (Round_DP) * S - 1 downto R * S - (Round_DP + 1) * S);
        Sbox_0_DN <= (Sbox_0_out xor Key_0_out xor CONSTANTS(Round_DP)) & Data_0_DP(N - S - 1 downto 0);
        Sbox_1_DN <= (Sbox_1_out xor Key_1_out) & Data_1_DP(N - S - 1 downto 0);
        TS_0_DN(Round_DP) <= TS_0_out;
        TS_1_DN(Round_DP) <= TS_1_out;
        TS_2_DN(Round_DP) <= TS_2_out;
      when rounds =>
        Data_0_DN <= Data_Round_0_out;
        Data_1_DN <= Data_Round_1_out;
        if Round_DP < R - 1 then
          Round_DN <= Round_DP + 1;
        end if;
      when i_sbox =>
        Sbox_0_DN <= (Sbox_0_out xor Key_0_out xor CONSTANTS(Round_DP)) & Data_0_DP(N - S - 1 downto 0);
        Key_0_in <= Key_DI;
      when i_rounds =>
        Key_0_in <= Key_DI;
        Data_0_DN <= Data_Round_0_out;
        if Round_DP < R - 1 then
          Round_DN <= Round_DP + 1;
          Round_in_prec_DN(Round_DP + 1) <= Data_Round_0_out(N - 1 downto N - S);
        else
          Cipher_prec_DN <= Data_Round_0_out;
        end if;
    end case;
  end process;

  -- next state logic
  process (State_DP, Start_SI, Init_SI, Round_DP)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Init_SI = '1' then
          State_DN <= i_sbox;
        elsif Start_SI = '1' then
          State_DN <= sbox;
        end if;
      when sbox =>
        State_DN <= rounds;
      when rounds =>
        if Round_DP < R - 1 then
          State_DN <= sbox;
        else
          State_DN <= init;
        end if;
      when i_sbox =>
        State_DN <= i_rounds;
      when i_rounds =>
        if Round_DP < R - 1 then
          State_DN <= i_sbox;
        else
          State_DN <= init;
        end if;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RI)
  begin  -- process register_p
    if Clk_CI'event and Clk_CI = '1' then
      if Rst_RI = '1' then               -- synchronous reset (active high)
        Round_DP   <= 0;
        Data_0_DP  <= (others => '0');
        Data_1_DP  <= (others => '0');
        State_DP   <= init;
        Cipher_prec_DP <= (others => '0');
        Round_in_prec_DP <= (others => (others => '0'));
        TS_0_DP <= (others => (others => '0'));
        TS_1_DP <= (others => (others => '0'));
        TS_2_DP <= (others => (others => '0'));
        Sbox_0_DP <= (others => '0');
        Sbox_1_DP <= (others => '0');
      else
        Round_DP   <= Round_DN;
        Data_0_DP  <= Data_0_DN;
        Data_1_DP  <= Data_1_DN;
        State_DP   <= State_DN;
        Cipher_prec_DP <= Cipher_prec_DN;
        Round_in_prec_DP <= Round_in_prec_DN;
        TS_0_DP <= TS_0_DN;
        TS_1_DP <= TS_1_DN;
        TS_2_DP <= TS_2_DN;
        Sbox_0_DP <= Sbox_0_DN;
        Sbox_1_DP <= Sbox_1_DN;
      end if;
    end if;
  end process;

end behavorial;
