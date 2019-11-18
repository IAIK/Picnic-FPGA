library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_l5_key_convertor is
  generic(
    DI_WIDTH : integer := 128; -- multiple of 8
    DO_WIDTH : integer := 64 -- multiple of 8
  );
  port(
    -- clk and reset (only for axi interface)
    clk : in std_logic;
    rst : in std_logic;
    -- Input
    di_data  : in std_logic_vector(DI_WIDTH - 1 downto 0);
    di_valid : in std_logic;
    di_ready : out std_logic;
    -- Output
    do_data  : out std_logic_vector(DO_WIDTH - 1 downto 0);
    do_valid : out std_logic;
    do_ready : in std_logic
  );
end axis_l5_key_convertor;

architecture behavorial of axis_l5_key_convertor is
  type states is (init, out1, out2, out3, out4);
  signal State_DN, State_DP : states;

  constant H_PRIV : std_logic_vector(5  downto 0) := "110000";
  constant L5_H_PRIV : std_logic_vector(31 downto 0) := H_PRIV & "11" & x"00" & x"0020";
  constant pad_32 : std_logic_vector(31 downto 0) := (others => '0');
  constant pad_96 : std_logic_vector(95 downto 0) := (others => '0');

begin

  -- output logic
  process (State_DP, di_data, di_valid, do_ready)
  begin
    -- default
    do_valid <= '0';
    do_data <= (others => '0');
    di_ready <= '0';

    case State_DP is
      when init =>
        do_data <= di_data(DI_WIDTH - 1 downto DI_WIDTH - DO_WIDTH);
        do_valid <= di_valid;
        di_ready <= do_ready;
      when out1 =>
        do_data <= di_data(DI_WIDTH - 1 downto DI_WIDTH - DO_WIDTH);
        do_valid <= di_valid;
        -- do not set ready here
      when out2 =>
        do_data <= di_data(DO_WIDTH - 1 downto 0);
        do_valid <= di_valid;
        di_ready <= do_ready;
      when out3 =>
        do_data <= di_data(DI_WIDTH - 1 downto DI_WIDTH - DO_WIDTH);
        do_valid <= di_valid;
        -- do not set ready here
      when out4 =>
        do_data <= di_data(DO_WIDTH - 1 downto 0);
        do_valid <= di_valid;
        di_ready <= do_ready;
    end case;
  end process;

  -- next state logic
  process (State_DP, di_data, di_valid, do_ready)
  begin
    -- default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if di_data(DI_WIDTH - 1 downto DI_WIDTH - DO_WIDTH) = L5_H_PRIV & pad_32
           and di_valid = '1' and do_ready = '1' then
          State_DN <= out1;
        end if;
      when out1 =>
        if di_valid = '1' and do_ready = '1' then
          State_DN <= out2;
        end if;
      when out2 =>
        if di_valid = '1' and do_ready = '1' then
          State_DN <= out3;
        end if;
      when out3 =>
        if di_valid = '1' and do_ready = '1' then
          State_DN <= out4;
        end if;
      when out4 =>
        if di_valid = '1' and do_ready = '1' then
          State_DN <= init;
        end if;
    end case;
  end process;

  process (clk, rst)
  begin  -- process register_p
    if clk'event and clk = '1' then
      if rst = '1' then               -- synchronous reset (active high)
        State_DP  <= init;
      else
        State_DP <= State_DN;
      end if;
    end if;
  end process;

end behavorial;
