library work;
use work.picnic_pkg.all;
use work.bram_pkg.all;
use work.protocol_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity input_fifo is
  port(
    -- Clock and Reset
    signal clk                : in std_logic;
    signal rst                : in std_logic;
    -- Inputs
    signal Init_DI            : in std_logic_vector(PDI_WIDTH - INIT_WIDTH - 1 downto 0);
    signal Init_SI            : in std_logic;
    signal Data_DI            : in std_logic_vector(PDI_WIDTH - 1 downto 0);
    signal Valid_SI           : in std_logic;
    signal Ready_SO           : out std_logic;
    -- Outputs
    signal Data_DO            : out std_logic_vector(PDI_WIDTH - 1 downto 0);
    signal Ready_Data_SI      : in std_logic;
    signal Unaligned_DO       : out std_logic_vector(UNALIGNED_WIDTH - 1 downto 0);
    signal Ready_Unaligned_SI : in std_logic;
    signal Valid_SO           : out std_logic;
    signal Skip_SO            : out std_logic
  );
end entity;

architecture behavorial of input_fifo is
  type states is (init, state0, state1, state2, state3, state4, state5,
                        state6, state7, state8, state9, state10, state11,
                        state12, state13, state14, state15);
  signal State_DN, State_DP : states;

  signal Saved_DN, Saved_DP : std_logic_vector(PDI_WIDTH - 1 downto 0);
begin

  -- output logic
  process (State_DP, Saved_DP, Ready_Unaligned_SI, Ready_Data_SI, Init_DI, Valid_SI, Data_DI)
  begin
    --default
    Saved_DN <= Saved_DP;
    Data_DO <= Saved_DP;
    Unaligned_DO <= (others => '0');
    Valid_SO <= Valid_SI;
    Ready_SO <= '0';
    Skip_SO <= '0';

    case State_DP is
      when init =>
        Saved_DN(PDI_WIDTH - INIT_WIDTH - 1 downto 0) <= Init_DI;
        Saved_DN(PDI_WIDTH - 1 downto PDI_WIDTH - INIT_WIDTH) <= (others => '0');
        Valid_SO <= '0';
      when state0 =>
        -- 9/7 bytes
        Data_DO <= Saved_DP(71 downto 0) & Data_DI(PDI_WIDTH - 1 downto 72);
        Unaligned_DO <= Saved_DP(71 downto 0) & Data_DI(PDI_WIDTH - 1 downto 112);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(111 downto 0) <= Data_DI(111 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 112) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(71 downto 0) <= Data_DI(71 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 72) <= (others => '0');
        end if;
      when state1 =>
        -- 14/2 bytes
        Data_DO <= Saved_DP(23 downto 0) & Data_DI(PDI_WIDTH - 1 downto 24);
        Unaligned_DO <= Saved_DP(111 downto 24);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          Skip_SO <= '1';
          Ready_SO <= '1';
          Saved_DN(23 downto 0) <= Data_DI(23 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 24) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Data_DO <= Saved_DP(111 downto 0) & Data_DI(PDI_WIDTH - 1 downto 112);
          Saved_DN(111 downto 0) <= Data_DI(111 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 112) <= (others => '0');
        end if;
      when state2 =>
        -- 3/13 bytes
        Data_DO <= Saved_DP(23 downto 0) & Data_DI(PDI_WIDTH - 1 downto 24);
        Unaligned_DO <= Saved_DP(23 downto 0) & Data_DI(PDI_WIDTH - 1 downto 64);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(63 downto 0) <= Data_DI(63 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 64) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(23 downto 0) <= Data_DI(23 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 24) <= (others => '0');
        end if;
      when state3 =>
        -- 8/8 bytes
        Data_DO <= Saved_DP(63 downto 0) & Data_DI(PDI_WIDTH - 1 downto 64);
        Unaligned_DO <= Saved_DP(63 downto 0) & Data_DI(PDI_WIDTH - 1 downto 104);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 104) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(63 downto 0) <= Data_DI(63 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 64) <= (others => '0');
        end if;
      when state4 =>
        -- 13/3 bytes
        Data_DO <= Saved_DP(15 downto 0) & Data_DI(PDI_WIDTH - 1 downto 16);
        Unaligned_DO <= Saved_DP(103 downto 16);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          Skip_SO <= '1';
          Ready_SO <= '1';
          Saved_DN(15 downto 0) <= Data_DI(15 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 16) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Data_DO <= Saved_DP(103 downto 0) & Data_DI(PDI_WIDTH - 1 downto 104);
          Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 104) <= (others => '0');
        end if;
      when state5 =>
        -- 2/14 bytes
        Data_DO <= Saved_DP(15 downto 0) & Data_DI(PDI_WIDTH - 1 downto 16);
        Unaligned_DO <= Saved_DP(15 downto 0) & Data_DI(PDI_WIDTH - 1 downto 56);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(55 downto 0) <= Data_DI(55 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 56) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(15 downto 0) <= Data_DI(15 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 16) <= (others => '0');
        end if;
      when state6 =>
        -- 7/9 byte
        Data_DO <= Saved_DP(55 downto 0) & Data_DI(PDI_WIDTH - 1 downto 56);
        Unaligned_DO <= Saved_DP(55 downto 0) & Data_DI(PDI_WIDTH - 1 downto 96);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 96) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(55 downto 0) <= Data_DI(55 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 56) <= (others => '0');
        end if;
      when state7 =>
        -- 12/4 bytes
        Data_DO <= Saved_DP(7 downto 0) & Data_DI(PDI_WIDTH - 1 downto 8);
        Unaligned_DO <= Saved_DP(95 downto 8);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          Skip_SO <= '1';
          Ready_SO <= '1';
          Saved_DN(7 downto 0) <= Data_DI(7 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 8) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Data_DO <= Saved_DP(95 downto 0) & Data_DI(PDI_WIDTH - 1 downto 96);
          Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 96) <= (others => '0');
        end if;
      when state8 =>
        -- 1/15 bytes
        Data_DO <= Saved_DP(7 downto 0) & Data_DI(PDI_WIDTH - 1 downto 8);
        Unaligned_DO <= Saved_DP(7 downto 0) & Data_DI(PDI_WIDTH - 1 downto 48);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(47 downto 0) <= Data_DI(47 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 48) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(7 downto 0) <= Data_DI(7 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 8) <= (others => '0');
        end if;
      when state9 =>
        -- 6/10 bytes
        Data_DO <= Saved_DP(47 downto 0) & Data_DI(PDI_WIDTH - 1 downto 48);
        Unaligned_DO <= Saved_DP(47 downto 0) & Data_DI(PDI_WIDTH - 1 downto 88);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 88) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(47 downto 0) <= Data_DI(47 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 48) <= (others => '0');
        end if;
      when state10 =>
        -- 11/5 bytes
        Data_DO <= Data_DI;
        Unaligned_DO <= Saved_DP(87 downto 0);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          Skip_SO <= '1';
          Ready_SO <= '1';
          Saved_DN <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Data_DO <= Saved_DP(87 downto 0) & Data_DI(PDI_WIDTH - 1 downto 88);
          Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 88) <= (others => '0');
        end if;
      when state11 =>
        -- 0/16 bytes
        Data_DO <= Data_DI;
        Unaligned_DO <= Data_DI(PDI_WIDTH - 1 downto 40);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(39 downto 0) <= Data_DI(39 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 40) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN <= (others => '0');
        end if;
      when state12 =>
        -- 5/11 bytes
        Data_DO <= Saved_DP(39 downto 0) & Data_DI(PDI_WIDTH - 1 downto 40);
        Unaligned_DO <= Saved_DP(39 downto 0) & Data_DI(PDI_WIDTH - 1 downto 80);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(79 downto 0) <= Data_DI(79 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 80) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(39 downto 0) <= Data_DI(39 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 40) <= (others => '0');
        end if;
      when state13 =>
        -- 10/6 bytes
        Data_DO <= Saved_DP(79 downto 0) & Data_DI(PDI_WIDTH - 1 downto 80);
        Unaligned_DO <= Saved_DP(79 downto 0) & Data_DI(PDI_WIDTH - 1 downto 120);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 120) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(79 downto 0) <= Data_DI(79 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 80) <= (others => '0');
        end if;
      when state14 =>
        -- 15/1 bytes
        Data_DO <= Saved_DP(31 downto 0) & Data_DI(PDI_WIDTH - 1 downto 32);
        Unaligned_DO <= Saved_DP(119 downto 32);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          Skip_SO <= '1';
          Ready_SO <= '1';
          Saved_DN(31 downto 0) <= Data_DI(31 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 32) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Data_DO <= Saved_DP(119 downto 0) & Data_DI(PDI_WIDTH - 1 downto 120);
          Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 120) <= (others => '0');
        end if;
      when state15 =>
        -- 4/12 bytes
        Data_DO <= Saved_DP(31 downto 0) & Data_DI(PDI_WIDTH - 1 downto 32);
        Unaligned_DO <= Saved_DP(31 downto 0) & Data_DI(PDI_WIDTH - 1 downto 72);
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(71 downto 0) <= Data_DI(71 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 72) <= (others => '0');
        elsif Valid_SI = '1' and Ready_Data_SI = '1' then
          Ready_SO <= '1';
          Saved_DN(31 downto 0) <= Data_DI(31 downto 0);
          Saved_DN(PDI_WIDTH - 1 downto 32) <= (others => '0');
        end if;
    end case;
  end process;

  -- next state logic
  process (State_DP, Init_SI, Valid_SI, Ready_Unaligned_SI, Ready_Data_SI)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Valid_SI = '1' then
          State_DN <= state0;
        end if;
      when state0 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state1;
        end if;
      when state1 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          State_DN <= state2;
        end if;
      when state2 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state3;
        end if;
      when state3 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state4;
        end if;
      when state4 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          State_DN <= state5;
        end if;
      when state5 =>
      if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
        State_DN <= state6;
      end if;
      when state6 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state7;
        end if;
      when state7 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          State_DN <= state8;
        end if;
      when state8 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state9;
        end if;
      when state9 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state10;
        end if;
      when state10 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          State_DN <= state11;
        end if;
      when state11 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state12;
        end if;
      when state12 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state13;
        end if;
      when state13 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state14;
        end if;
      when state14 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
          State_DN <= state15;
        end if;
      when state15 =>
        if Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state0;
        end if;
    end case;

    if Init_SI = '1' then
      State_DN <= init;
    end if;
  end process;

  process (clk, rst)
  begin  -- process register_p
    if clk'event and clk = '1' then
      if rst = '1' then               -- synchronous reset (active high)
        State_DP     <= init;
        Saved_DP     <= (others => '0');
      else
        State_DP     <= State_DN;
        Saved_DP     <= Saved_DN;
      end if;
    end if;
  end process;

end behavorial;
