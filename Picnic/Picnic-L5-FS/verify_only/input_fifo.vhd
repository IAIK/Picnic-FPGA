library work;
use work.picnic_pkg.all;
use work.bram_pkg.all;
use work.protocol_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity input_fifo is
  port(
    -- Clock and Reset
    signal clk                : in std_logic;
    signal rst                : in std_logic;
    -- Inputs
    signal Init_DI            : in std_logic_vector(PDI_WIDTH - INIT_WIDTH - 1 downto 0);
    signal Init_SI            : in std_logic;
    signal Init_Len_DI        : integer range 0 to L5_BYTES_PER_SEG;
    signal Data_DI            : in std_logic_vector(PDI_WIDTH - 1 downto 0);
    signal Valid_SI           : in std_logic;
    signal Ready_SO           : out std_logic;
    -- Outputs
    signal Data_DO            : out std_logic_vector(PDI_WIDTH - 1 downto 0);
    signal Ready_Data_SI      : in std_logic;
    signal Unaligned_DO       : out std_logic_vector(UNALIGNED_WIDTH - 1 downto 0);
    signal Ready_Unaligned_SI : in std_logic;
    signal Valid_SO           : out std_logic;
    signal Sig_Len_DO         : out integer range 0 to MAX_SIG;
    signal Fin_SO             : out std_logic;
    signal Skip_SO            : out std_logic
  );
end entity;

architecture behavorial of input_fifo is
  type states is (init, state0, state1, state2, state3, state4, state5,
                        state6, state7, state8, state9, state10, state11,
                        state12, state13, state14, state15);
  signal State_DN, State_DP : states;

  signal Sig_len_DN, Sig_len_DP : integer range 0 to MAX_SIG;
  signal To_Rcv_DN, To_Rcv_DP : integer range 0 to L5_BYTES_PER_SEG;
  signal Saved_DN, Saved_DP : std_logic_vector(PDI_WIDTH - 1 downto 0);

  signal Fin_DN, Fin_DP : std_logic;

  constant PDI_BYTES : integer := (PDI_WIDTH / 8);
begin

  -- output logic
  process (State_DP, Saved_DP, Ready_Unaligned_SI, Ready_Data_SI, Init_DI, Valid_SI, Data_DI, Sig_len_DP, To_Rcv_DP, Init_Len_DI, Fin_DP, Init_SI)
  begin
    --default
    Saved_DN <= Saved_DP;
    Data_DO <= Saved_DP;
    Unaligned_DO <= (others => '0');
    Sig_len_DN <= Sig_len_DP;
    To_Rcv_DN <= To_Rcv_DP;
    Valid_SO <= Valid_SI;
    Ready_SO <= '0';
    Skip_SO <= '0';
    Fin_SO <= '0';
    Sig_Len_DO <= Sig_Len_DP;
    Fin_DN <= Fin_DP;

    case State_DP is
      when init =>
        Saved_DN(PDI_WIDTH - INIT_WIDTH - 1 downto 0) <= Init_DI;
        Saved_DN(PDI_WIDTH - 1 downto PDI_WIDTH - INIT_WIDTH) <= (others => '0');
        Fin_DN <= '0';
        Fin_SO <= '1';
        Valid_SO <= '0';
      when state0 =>
        -- 2/14 bytes
        Data_DO <= Saved_DP(15 downto 0) & Data_DI(PDI_WIDTH - 1 downto 16);
        Unaligned_DO <= Saved_DP(15 downto 0) & Data_DI(PDI_WIDTH - 1 downto 24);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(23 downto 0) <= Data_DI(23 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 24) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(15 downto 0) <= Data_DI(15 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 16) <= (others => '0');
          end if;
        end if;
      when state1 =>
        -- 3/13 bytes
        Data_DO <= Saved_DP(23 downto 0) & Data_DI(PDI_WIDTH - 1 downto 24);
        Unaligned_DO <= Saved_DP(23 downto 0) & Data_DI(PDI_WIDTH - 1 downto 32);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(31 downto 0) <= Data_DI(31 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 32) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(23 downto 0) <= Data_DI(23 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 24) <= (others => '0');
          end if;
        end if;
      when state2 =>
        -- 4/12 bytes
        Data_DO <= Saved_DP(31 downto 0) & Data_DI(PDI_WIDTH - 1 downto 32);
        Unaligned_DO <= Saved_DP(31 downto 0) & Data_DI(PDI_WIDTH - 1 downto 40);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(39 downto 0) <= Data_DI(39 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 40) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(31 downto 0) <= Data_DI(31 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 32) <= (others => '0');
          end if;
        end if;
      when state3 =>
        -- 5/11 bytes
        Data_DO <= Saved_DP(39 downto 0) & Data_DI(PDI_WIDTH - 1 downto 40);
        Unaligned_DO <= Saved_DP(39 downto 0) & Data_DI(PDI_WIDTH - 1 downto 48);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(47 downto 0) <= Data_DI(47 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 48) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(39 downto 0) <= Data_DI(39 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 40) <= (others => '0');
          end if;
        end if;
      when state4 =>
        -- 6/10 bytes
        Data_DO <= Saved_DP(47 downto 0) & Data_DI(PDI_WIDTH - 1 downto 48);
        Unaligned_DO <= Saved_DP(47 downto 0) & Data_DI(PDI_WIDTH - 1 downto 56);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(55 downto 0) <= Data_DI(55 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 56) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(47 downto 0) <= Data_DI(47 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 48) <= (others => '0');
          end if;
        end if;
      when state5 =>
        -- 7/9 bytes
        Data_DO <= Saved_DP(55 downto 0) & Data_DI(PDI_WIDTH - 1 downto 56);
        Unaligned_DO <= Saved_DP(55 downto 0) & Data_DI(PDI_WIDTH - 1 downto 64);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(63 downto 0) <= Data_DI(63 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 64) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(55 downto 0) <= Data_DI(55 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 56) <= (others => '0');
          end if;
        end if;
      when state6 =>
        -- 8/8 bytes
        Data_DO <= Saved_DP(63 downto 0) & Data_DI(PDI_WIDTH - 1 downto 64);
        Unaligned_DO <= Saved_DP(63 downto 0) & Data_DI(PDI_WIDTH - 1 downto 72);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(71 downto 0) <= Data_DI(71 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 72) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(63 downto 0) <= Data_DI(63 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 64) <= (others => '0');
          end if;
        end if;
      when state7 =>
        -- 9/7 bytes
        Data_DO <= Saved_DP(71 downto 0) & Data_DI(PDI_WIDTH - 1 downto 72);
        Unaligned_DO <= Saved_DP(71 downto 0) & Data_DI(PDI_WIDTH - 1 downto 80);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(79 downto 0) <= Data_DI(79 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 80) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(71 downto 0) <= Data_DI(71 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 72) <= (others => '0');
          end if;
        end if;
      when state8 =>
        -- 10/6 bytes
        Data_DO <= Saved_DP(79 downto 0) & Data_DI(PDI_WIDTH - 1 downto 80);
        Unaligned_DO <= Saved_DP(79 downto 0) & Data_DI(PDI_WIDTH - 1 downto 88);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 88) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(79 downto 0) <= Data_DI(79 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 80) <= (others => '0');
          end if;
        end if;
      when state9 =>
        -- 11/5 bytes
        Data_DO <= Saved_DP(87 downto 0) & Data_DI(PDI_WIDTH - 1 downto 88);
        Unaligned_DO <= Saved_DP(87 downto 0) & Data_DI(PDI_WIDTH - 1 downto 96);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 96) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 88) <= (others => '0');
          end if;
        end if;
      when state10 =>
        -- 12/4 bytes
        Data_DO <= Saved_DP(95 downto 0) & Data_DI(PDI_WIDTH - 1 downto 96);
        Unaligned_DO <= Saved_DP(95 downto 0) & Data_DI(PDI_WIDTH - 1 downto 104);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 104) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 96) <= (others => '0');
          end if;
        end if;
      when state11 =>
        -- 13/3 bytes
        Data_DO <= Saved_DP(103 downto 0) & Data_DI(PDI_WIDTH - 1 downto 104);
        Unaligned_DO <= Saved_DP(103 downto 0) & Data_DI(PDI_WIDTH - 1 downto 112);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(111 downto 0) <= Data_DI(111 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 112) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 104) <= (others => '0');
          end if;
        end if;
      when state12 =>
        -- 14/2 bytes
        Data_DO <= Saved_DP(111 downto 0) & Data_DI(PDI_WIDTH - 1 downto 112);
        Unaligned_DO <= Saved_DP(111 downto 0) & Data_DI(PDI_WIDTH - 1 downto 120);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 120) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(111 downto 0) <= Data_DI(111 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 112) <= (others => '0');
          end if;
        end if;
      when state13 =>
        -- 15/1 bytes
        Data_DO <= Data_DI;
        Unaligned_DO <= Saved_DP(119 downto 0);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' and Ready_Data_SI = '1' then
            Ready_SO <= '1';
            Skip_SO <= '1'; -- skip here
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Data_DO <= Saved_DP(119 downto 0) & Data_DI(PDI_WIDTH - 1 downto 120);
            Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 120) <= (others => '0');
          end if;
        end if;
      when state14 =>
        -- 0/16 bytes
        Data_DO <= Data_DI;
        Unaligned_DO <= Data_DI(PDI_WIDTH - 1 downto 8);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(7 downto 0) <= Data_DI(7 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 8) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN <= (others => '0');
          end if;
        end if;
      when state15 =>
        -- 1/15 bytes
        Data_DO <= Saved_DP(7 downto 0) & Data_DI(PDI_WIDTH - 1 downto 8);
        Unaligned_DO <= Saved_DP(7 downto 0) & Data_DI(PDI_WIDTH - 1 downto 16);
        if To_Rcv_DP = 0 and Fin_DP = '1' then
          Valid_SO <= '0';
          Fin_SO <= '1';
        elsif Valid_SI = '1' then
          if To_Rcv_DP = 0 and Fin_DP = '0' then
            -- Receive new header
            Ready_SO <= '1';
            if Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "00" & x"00" then
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            elsif Data_DI(PDI_WIDTH - 1 downto 112) = H_SIG & "11" & x"00" then
              Fin_DN <= '1';
              To_Rcv_DN <= to_integer(unsigned(Data_DI(111 downto 96)));
              Sig_Len_DN <= Sig_Len_DP + to_integer(unsigned(Data_DI(111 downto 96)));
            else
              -- wrong header
              Fin_SO <= '1';
            end if;
            Valid_SO <= '0';
            Fin_SO <= Fin_DP;
          elsif Ready_Unaligned_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(15 downto 0) <= Data_DI(15 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 16) <= (others => '0');
          elsif Ready_Data_SI = '1' then
            Ready_SO <= '1';
            if To_Rcv_DP >= 16 then
              To_Rcv_DN <= To_Rcv_DP - PDI_BYTES;
            end if;
            Saved_DN(7 downto 0) <= Data_DI(7 downto 0);
            Saved_DN(PDI_WIDTH - 1 downto 8) <= (others => '0');
          end if;
        end if;
    end case;

    -- initialize from first header
    if Init_SI = '1' then
      Sig_len_DN <= Init_Len_DI;
      if Init_Len_DI >= 112 then
        To_Rcv_DN <= Init_Len_DI - 112;
      else
        To_Rcv_DN <= 0;
      end if;
    end if;
  end process;

  -- next state logic
  process (State_DP, Init_SI, Valid_SI, Ready_Unaligned_SI, Ready_Data_SI, To_Rcv_DP, Data_DI, Fin_DP)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Valid_SI = '1' then
          State_DN <= state0;
        end if;
      when state0 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state1;
        end if;
      when state1 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state2;
        end if;
      when state2 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state3;
        end if;
      when state3 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state4;
        end if;
      when state4 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state5;
        end if;
      when state5 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state6;
        end if;
      when state6 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state7;
        end if;
      when state7 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state8;
        end if;
      when state8 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state9;
        end if;
      when state9 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state10;
        end if;
      when state10 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state11;
        end if;
      when state11 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state12;
        end if;
      when state12 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state13;
        end if;
      when state13 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' and Ready_data_SI = '1' then
          State_DN <= state14;
        end if;
      when state14 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
          State_DN <= state15;
        end if;
      when state15 =>
        if To_Rcv_DP = 0 then
          if Fin_DP = '1' or (Valid_SI = '1' and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "00" & x"00" and Data_DI(PDI_WIDTH - 1 downto 112) /= H_SIG & "11" & x"00") then
            State_DN <= init;
          end if;
        elsif Valid_SI = '1' and Ready_Data_SI = '1' and To_Rcv_DP < 16 then
          State_DN <= init;
        elsif Valid_SI = '1' and Ready_Unaligned_SI = '1' then
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
        Sig_len_DP   <= 0;
        To_Rcv_DP    <= 0;
        Fin_DP       <= '0';
      else
        State_DP     <= State_DN;
        Saved_DP     <= Saved_DN;
        Sig_len_DP   <= Sig_len_DN;
        To_Rcv_DP    <= To_Rcv_DN;
        Fin_DP       <= Fin_DN;
      end if;
    end if;
  end process;

end behavorial;
