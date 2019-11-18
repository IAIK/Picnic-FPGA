library work;
use work.keccak_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity keccak is
  generic(
    constant GEN_R : integer := 1344;
    constant OUT_BIT : integer := 256
  );
  port(
    -- Clock and Reset
    signal Clk_CI   : in std_logic;
    signal Rst_RI   : in std_logic;
    -- Input signals
    signal Block_DI   : in std_logic_vector(GEN_R - 1 downto 0);
    signal Absorb_SI  : in std_logic;
    signal Squeeze_SI : in std_logic;
    signal Init_SI    : in std_logic;
    -- Output signals
    signal Hash_DO  : out std_logic_vector(OUT_BIT - 1 downto 0);
    signal Valid_SO : out std_logic
  );
end entity;

architecture behavorial of keccak is
  -- CONSTANTS
  constant C : integer := B - GEN_R;
  constant R_LANES : integer := GEN_R / W;
  constant OUT_LANES : integer := OUT_BIT / W;

  type FSM is (init, rounds);
  signal FSM_DN, FSM_DP : FSM;
  signal State_DN, State_DP : T_STATE;
  signal State_in, State_out : T_STATE;
  signal Round_DN, Round_DP : integer range 0 to KECCAK_N;

  component keccak_round
    port(
      -- Input signals
      signal State_DI : in T_STATE;
      signal Round_DI : integer range 0 to KECCAK_N;
      -- Output signals
      signal State_DO : out T_STATE
    );
  end component;

begin

  -- a round
  ROUND : keccak_round
  port map(
    State_DI => State_in,
    Round_DI => Round_DP,
    State_DO => State_out
  );

  -- Output the hash
  process(State_DP)
    type T_OUT_LANES is array (0 to OUT_LANES) of T_ROW;
    variable Lane_end : T_OUT_LANES;
  begin
    ROW_OUT : for row in 0 to (CUBE_LEN - 1) loop
      COL_OUT : for col in 0 to (CUBE_LEN - 1) loop
        -- endianess correction
        END_OUT : for i in 0 to W / 8 - 1 loop
          Lane_end(row * CUBE_LEN + col)((i + 1) * 8 - 1 downto i * 8) := State_DP(row)(col)((W / 8 - i) * 8 - 1 downto (W / 8 - 1 - i) * 8);
        end loop END_OUT;

        exit ROW_OUT when row * CUBE_LEN + col = OUT_LANES;

        Hash_DO(OUT_BIT - (CUBE_LEN * row + col) * W - 1 downto OUT_BIT - (CUBE_LEN * row + col) * W - W) <= Lane_end(row * CUBE_LEN + col);
      end loop COL_OUT;
    end loop ROW_OUT;
    -- output of last incomplete slide if necessary
    if (OUT_LANES * W < OUT_BIT) then
      Hash_DO(OUT_BIT - OUT_LANES * W - 1 downto 0) <= Lane_end(OUT_LANES)(W - 1 downto W - OUT_BIT + OUT_LANES * W);
    end if;
  end process;

  -- next state and output logic
  process (FSM_DP, State_DP, Round_DP, State_out, Absorb_SI, Squeeze_SI, Init_SI, Block_DI)
    type T_R_LANES is array (0 to R_LANES - 1) of T_ROW;
    variable Lane_init, Lane_end : T_R_LANES;
  begin
    -- default:
    FSM_DN <= FSM_DP;
    Round_DN <= Round_DP;
    State_DN <= State_DP;
    Valid_SO <= '0';
    State_in <= State_DP;

    case FSM_DP is
      when init =>
        Valid_SO <= '1';
        if Init_SI = '1' then
          State_DN <= (others => (others => (others => '0')));
        else
          if Absorb_SI = '1' and Squeeze_SI = '0' then
            FSM_DN <= rounds;
            Round_DN <= 1;
            State_DN <= State_out;
            ROW_AB : for row in 0 to (CUBE_LEN - 1) loop
              COL_AB : for col in 0 to (CUBE_LEN - 1) loop
                exit ROW_AB when row * CUBE_LEN + col = R_LANES;
                -- endianess correction
                END_OUT : for i in 0 to W / 8 - 1 loop
                  Lane_init(row * CUBE_LEN + col) := Block_DI(GEN_R - (CUBE_LEN * row + col) * W - 1 downto GEN_R - (CUBE_LEN * row + col) * W - W);
                  Lane_end(row * CUBE_LEN + col)((i + 1) * 8 - 1 downto i * 8) := Lane_init(row * CUBE_LEN + col)((W / 8 - i) * 8 - 1 downto (W / 8 - 1 - i) * 8);
                end loop END_OUT;

                State_in(row)(col) <= State_DP(row)(col) xor Lane_end(row * CUBE_LEN + col);
              end loop COL_AB;
            end loop ROW_AB;
          elsif Absorb_SI = '0' and Squeeze_SI = '1' then
            FSM_DN <= rounds;
            Round_DN <= 1;
            State_DN <= State_out;
          end if;
        end if;
      when rounds =>
        State_DN <= State_out;
        if Round_DP < KECCAK_N - 1 then
          Round_DN <= Round_DP + 1;
        else
          Round_DN <= 0;
          FSM_DN <= init;
        end if;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RI)
  begin  -- process register_p
    if Clk_CI'event and Clk_CI = '1' then
      if Rst_RI = '1' then               -- synchronous reset (active high)
        State_DP <= (others =>(others =>(others => '0')));
        Round_DP <= 0;
        FSM_DP   <= init;
      else
        State_DP <= State_DN;
        Round_DP <= Round_DN;
        FSM_DP   <= FSM_DN;
      end if;
    end if;
  end process;
end behavorial;