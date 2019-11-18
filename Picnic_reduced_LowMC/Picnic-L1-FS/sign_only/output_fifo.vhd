library work;
use work.picnic_pkg.all;
use work.bram_pkg.all;
use work.protocol_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity output_fifo is
  port(
    -- Clock and Reset
    signal clk                : in std_logic;
    signal rst                : in std_logic;
    -- Inputs
    signal Init_DI            : in std_logic_vector(INIT_WIDTH - 1 downto 0);
    signal Init_SI            : in std_logic;
    signal Data_DI            : in std_logic_vector(PDO_WIDTH - 1 downto 0);
    signal Valid_Data_SI      : in std_logic;
    signal Unaligned_DI       : in std_logic_vector(UNALIGNED_WIDTH - 1 downto 0);
    signal Valid_Unaligned_SI : in std_logic;
    signal Ready_SI           : in std_logic;
    -- Outputs
    signal Data_DO            : out std_logic_vector(PDO_WIDTH - 1 downto 0);
    signal Valid_SO           : out std_logic;
    signal Ready_SO           : out std_logic;
    signal Skip_SO            : out std_logic
  );
end entity;

architecture behavorial of output_fifo is
  type states is (init, state0, state1, state2, state3, state4, state5,
                        state6, state7, state8, state9, state10, state11,
                        state12, state13, state14, state15);
  signal State_DN, State_DP : states;

  signal Saved_DN, Saved_DP : std_logic_vector(PDO_WIDTH - 1 downto 0);
begin

  -- output logic
  process (State_DP, Saved_DP, Valid_Data_SI, Valid_Unaligned_SI, Ready_SI, Init_DI, Data_DI, Unaligned_DI)
  begin
    --default
    Saved_DN <= Saved_DP;
    Data_DO <= Saved_DP;
    Valid_SO <= '0';
    Ready_SO <= Ready_SI;
    Skip_SO <= '0';

    case State_DP is
      when init =>
        Ready_SO <= '1';
        Saved_DN(INIT_WIDTH - 1 downto 0) <= Init_DI;
        Saved_DN(PDO_WIDTH - 1 downto INIT_WIDTH) <= (others => '0');
      when state0 =>
        -- 7/9 byte
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(INIT_WIDTH - 1 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 72 - INIT_WIDTH);
          Saved_DN(15 downto 0) <= Unaligned_DI(15 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 16) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(INIT_WIDTH - 1 downto 0) & Data_DI(PDO_WIDTH - 1 downto INIT_WIDTH);
          Saved_DN(INIT_WIDTH - 1 downto 0) <= Data_DI(INIT_WIDTH - 1 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto INIT_WIDTH) <= (others => '0');
        end if;
      when state1 =>
        -- 2/14 bytes
        if Ready_SI = '1' and Valid_data_SI = '1' and Valid_Unaligned_SI = '1' then
          Skip_SO <= '1';
          Valid_SO <= '1';
          Data_DO <= Saved_DP(15 downto 0) & Unaligned_DI & Data_DI(PDO_WIDTH - 1 downto 104);
          Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 104) <= (others => '0');
        elsif Ready_SI = '1' and Valid_data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(15 downto 0) & Data_DI(PDO_WIDTH - 1 downto 16);
          Saved_DN(15 downto 0) <= Data_DI(15 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 16) <= (others => '0');
        end if;
      when state2 =>
        -- 13/3 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(103 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 64);
          Saved_DN(63 downto 0) <= Unaligned_DI(63 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 64) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(103 downto 0) & Data_DI(PDO_WIDTH - 1 downto 104);
          Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 104) <= (others => '0');
        end if;
      when state3 =>
        -- 8/8 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(63 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 24);
          Saved_DN(23 downto 0) <= Unaligned_DI(23 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 104) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(63 downto 0) & Data_DI(PDO_WIDTH - 1 downto 64);
          Saved_DN(63 downto 0) <= Data_DI(63 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 64) <= (others => '0');
        end if;
      when state4 =>
        -- 3/13 bytes
        if Ready_SI = '1' and Valid_data_SI = '1' and Valid_Unaligned_SI = '1' then
          Skip_SO <= '1';
          Valid_SO <= '1';
          Data_DO <= Saved_DP(23 downto 0) & Unaligned_DI & Data_DI(PDO_WIDTH - 1 downto 112);
          Saved_DN(111 downto 0) <= Data_DI(111 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 112) <= (others => '0');
        elsif Ready_SI = '1' and Valid_data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(23 downto 0) & Data_DI(PDO_WIDTH - 1 downto 24);
          Saved_DN(23 downto 0) <= Data_DI(23 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 24) <= (others => '0');
        end if;
      when state5 =>
        -- 14/2 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(111 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 72);
          Saved_DN(71 downto 0) <= Unaligned_DI(71 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 72) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(111 downto 0) & Data_DI(PDO_WIDTH - 1 downto 112);
          Saved_DN(111 downto 0) <= Data_DI(111 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 112) <= (others => '0');
        end if;
      when state6 =>
        -- 9/7 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(71 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 32);
          Saved_DN(31 downto 0) <= Unaligned_DI(31 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 32) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(71 downto 0) & Data_DI(PDO_WIDTH - 1 downto 72);
          Saved_DN(71 downto 0) <= Data_DI(71 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 72) <= (others => '0');
        end if;
      when state7 =>
        -- 4/12 bytes
        if Ready_SI = '1' and Valid_data_SI = '1' and Valid_Unaligned_SI = '1' then
          Skip_SO <= '1';
          Valid_SO <= '1';
          Data_DO <= Saved_DP(31 downto 0) & Unaligned_DI & Data_DI(PDO_WIDTH - 1 downto 120);
          Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 120) <= (others => '0');
        elsif Ready_SI = '1' and Valid_data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(31 downto 0) & Data_DI(PDO_WIDTH - 1 downto 32);
          Saved_DN(31 downto 0) <= Data_DI(31 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 32) <= (others => '0');
        end if;
      when state8 =>
        -- 15/1 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(119 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 80);
          Saved_DN(79 downto 0) <= Unaligned_DI(79 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 80) <= (others => '0');
         elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(119 downto 0) & Data_DI(PDO_WIDTH - 1 downto 120);
          Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 120) <= (others => '0');
        end if;
      when state9 =>
        -- 10/6 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(79 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 40);
          Saved_DN(39 downto 0) <= Unaligned_DI(39 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 40) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(79 downto 0) & Data_DI(PDO_WIDTH - 1 downto 80);
          Saved_DN(79 downto 0) <= Data_DI(79 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 80) <= (others => '0');
        end if;
      when state10 =>
        -- 5/11 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(39 downto 0) & Unaligned_DI;
          Saved_DN <= (others => '0');
        elsif Ready_SI = '1' and Valid_data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(39 downto 0) & Data_DI(PDO_WIDTH - 1 downto 40);
          Saved_DN(39 downto 0) <= Data_DI(39 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 40) <= (others => '0');
        end if;
      when state11 =>
        -- 0/16 bytes
        if Ready_SI = '1' and Valid_data_SI = '1' and Valid_Unaligned_SI = '1' then
          Skip_SO <= '1';
          Valid_SO <= '1';
          Data_DO <= Unaligned_DI & Data_DI(PDO_WIDTH - 1 downto 88);
          Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 88) <= (others => '0');
        elsif Ready_SI = '1' and Valid_data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Data_DI;
          Saved_DN <= (others => '0');
        end if;
      when state12 =>
        -- 11/5 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(87 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 48);
          Saved_DN(47 downto 0) <= Unaligned_DI(47 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 48) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(87 downto 0) & Data_DI(PDO_WIDTH - 1 downto 88);
          Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 88) <= (others => '0');
        end if;
      when state13 =>
        -- 6/10 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(47 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 8);
          Saved_DN(7 downto 0) <= Unaligned_DI(7 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 8) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(47 downto 0) & Data_DI(PDO_WIDTH - 1 downto 48);
          Saved_DN(47 downto 0) <= Data_DI(47 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 48) <= (others => '0');
        end if;
      when state14 =>
        -- 1/15 bytes
        if Ready_SI = '1' and Valid_data_SI = '1' and Valid_Unaligned_SI = '1' then
          Skip_SO <= '1';
          Valid_SO <= '1';
          Data_DO <= Saved_DP(7 downto 0) & Unaligned_DI & Data_DI(PDO_WIDTH - 1 downto 96);
          Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 96) <= (others => '0');
        elsif Ready_SI = '1' and Valid_data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(7 downto 0) & Data_DI(PDO_WIDTH - 1 downto 8);
          Saved_DN(7 downto 0) <= Data_DI(7 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 8) <= (others => '0');
        end if;
      when state15 =>
        -- 12/4 bytes
        if Ready_SI = '1' and Valid_Unaligned_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(95 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto INIT_WIDTH);
          Saved_DN(INIT_WIDTH - 1 downto 0) <= Unaligned_DI(INIT_WIDTH - 1 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto INIT_WIDTH) <= (others => '0');
        elsif Ready_SI = '1' and Valid_Data_SI = '1' then
          Valid_SO <= '1';
          Data_DO <= Saved_DP(95 downto 0) & Data_DI(PDO_WIDTH - 1 downto 96);
          Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
          Saved_DN(PDO_WIDTH - 1 downto 96) <= (others => '0');
        end if;
    end case;
  end process;

  -- next state logic
  process (State_DP, Valid_Data_SI, Valid_Unaligned_SI, Ready_SI, Init_SI)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Valid_Data_SI = '1' and Valid_Unaligned_SI = '1' then
          State_DN <= state0;
        end if;
      when state0 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state1;
        end if;
      when state1 =>
        if Valid_Unaligned_SI = '1' and Valid_Data_SI = '1' and Ready_SI = '1' then
          State_DN <= state2;
        end if;
      when state2 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state3;
        end if;
      when state3 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state4;
        end if;
      when state4 =>
        if Valid_Unaligned_SI = '1' and Valid_Data_SI = '1' and Ready_SI = '1' then
          State_DN <= state5;
        end if;
      when state5 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state6;
        end if;
      when state6 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state7;
        end if;
      when state7 =>
        if Valid_Unaligned_SI = '1' and Valid_Data_SI = '1' and Ready_SI = '1' then
          State_DN <= state8;
        end if;
      when state8 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state9;
        end if;
      when state9 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state10;
        end if;
      when state10 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state11;
        end if;
      when state11 =>
        if Valid_Unaligned_SI = '1' and Valid_Data_SI = '1' and Ready_SI = '1' then
          State_DN <= state12;
        end if;
      when state12 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state13;
        end if;
      when state13 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
          State_DN <= state14;
        end if;
      when state14 =>
        if Valid_Unaligned_SI = '1' and Valid_Data_SI = '1' and Ready_SI = '1' then
          State_DN <= state15;
        end if;
      when state15 =>
        if Valid_Unaligned_SI = '1' and Ready_SI = '1' then
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

end architecture behavorial;
