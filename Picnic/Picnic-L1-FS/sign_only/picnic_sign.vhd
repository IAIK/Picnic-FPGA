library work;
use work.lowmc_pkg.all;
use work.keccak_pkg.all;
use work.picnic_pkg.all;
use work.bram_pkg.all;
use work.protocol_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity picnic_sign is
  port(
    -- Clock and Reset
    signal clk          : in std_logic;
    signal rst          : in std_logic;
    -- Public Data Inputs
    signal pdi_data     : in std_logic_vector(PDI_WIDTH - 1 downto 0);
    signal pdi_valid    : in std_logic;
    signal pdi_ready    : out std_logic;
    --Secret Data Inputs
    signal sdi_data     : in std_logic_vector(SDI_WIDTH - 1 downto 0);
    signal sdi_valid    : in std_logic;
    signal sdi_ready    : out std_logic;
    -- Public Data Outputs
    signal pdo_data     : out std_logic_vector(PDO_WIDTH - 1 downto 0);
    signal pdo_valid    : out std_logic;
    signal pdo_ready    : in std_logic;
    signal pdo_last     : out std_logic;
    -- Status
    signal status_ready : out std_logic
  );
end entity;

architecture behavorial of picnic_sign is
  type S_ARR is array(0 to 2) of std_logic_vector(PICNIC_S - 1 downto 0);

  -- seed_BRAM
  signal seed_addra, seed_addrb : std_logic_vector(SEED_ADDR_WIDTH - 1 downto 0);
  signal seed_wea, seed_web : std_logic;
  type SEED_ARR is  array(0 to 2) of std_logic_vector(SEED_DATA_WIDTH - 1 downto 0);
  signal seed_dina, seed_dinb : SEED_ARR;
  signal seed_douta, seed_doutb : SEED_ARR;

  -- view_i_BRAM
  signal view_i_addra, view_i_addrb : std_logic_vector(VIEW_I_ADDR_WIDTH - 1 downto 0);
  signal view_i_wea, view_i_web : std_logic;
  type IVIEW_ARR is  array(0 to 2) of std_logic_vector(VIEW_I_DATA_WIDTH - 1 downto 0);
  signal view_i_dina, view_i_dinb : IVIEW_ARR;
  signal view_i_douta, view_i_doutb : IVIEW_ARR;

  -- view_o_BRAM
  signal view_o_addra, view_o_addrb : std_logic_vector(VIEW_O_ADDR_WIDTH - 1 downto 0);
  signal view_o_wea, view_o_web : std_logic;
  type VIEW_O_ARR is  array(0 to 2) of std_logic_vector(VIEW_O_DATA_WIDTH - 1 downto 0);
  signal view_o_dina, view_o_dinb : VIEW_O_ARR;
  signal view_o_douta, view_o_doutb : VIEW_O_ARR;

  -- view_ts_BRAM
  signal view_ts_addra, view_ts_addrb : std_logic_vector(VIEW_TS_ADDR_WIDTH - 1 downto 0);
  signal view_ts_wea, view_ts_web : std_logic;
  type VIEW_TS_ARR is  array(0 to 2) of std_logic_vector(VIEW_TS_DATA_WIDTH - 1 downto 0);
  signal view_ts_dina, view_ts_dinb : VIEW_TS_ARR;
  signal view_ts_douta, view_ts_doutb : VIEW_TS_ARR;

  -- commit_BRAM
  signal comm_addra, comm_addrb : std_logic_vector(COMMIT_ADDR_WIDTH - 1 downto 0);
  signal comm_wea, comm_web : std_logic;
  type COMMIT_ARR is  array(0 to 2) of std_logic_vector(COMMIT_DATA_WIDTH - 1 downto 0);
  signal comm_dina, comm_dinb : COMMIT_ARR;
  signal comm_douta, comm_doutb : COMMIT_ARR;

  -- counter
  signal Counter_DN, Counter_DP : integer range 0 to T;
  signal Counter_Trans_DN, Counter_Trans_DP : integer range 0 to 15;

  -- seeds
  signal seed_start, seed_next, seed_ready : std_logic;
  signal seed_out : S_ARR;

  -- tapes
  signal tape_start, tape_finish : std_logic;
  signal tape_k0_out, tape_k1_out : std_logic_vector(PICNIC_S - 1 downto 0);
  type TAPE_ARR is  array(0 to 2) of std_logic_vector(R * S - 1 downto 0);
  signal tape_rand_out : TAPE_ARR;
  signal tape_round_in : integer range 0 to T;

  -- mpc
  signal mpc_start, mpc_init, mpc_finish : std_logic;
  signal mpc_c_out : S_ARR;
  signal mpc_ts_out : TAPE_ARR;

  -- commit
  signal comm_start, comm_finish : std_logic;
  type COMM_ARR is  array(0 to 2) of std_logic_vector(DIGEST_L - 1 downto 0);
  signal comm_out : COMM_ARR;
  signal comm_key_0_in, comm_key_1_in : std_logic_vector(PICNIC_S - 1 downto 0);

  -- h3
  signal h3_start, h3_valid, h3_ready : std_logic;
  signal h3_block : std_logic_vector(PICNIC_S - 1 downto 0);
  signal h3_chal_out : std_logic_vector(2 * T - 1 downto 0);
  signal h3_sig_len_out : integer range 0 to MAX_SIG;

  -- fifo
  signal fifo_valid_data, fifo_valid_unaligned, fifo_init : std_logic;
  signal fifo_ready_in, fifo_valid_out, fifo_ready_out : std_logic;
  signal fifo_data, fifo_out : std_logic_vector(PDO_WIDTH - 1 downto 0);
  signal fifo_unaligned : std_logic_vector(UNALIGNED_WIDTH - 1 downto 0);
  signal fifo_init_data : std_logic_vector(INIT_WIDTH - 1 downto 0);
  signal fifo_skip : std_logic;

  -- constants
  constant SIG_OUTS : integer := (CHAL_ROUND / PDO_WIDTH);

  -- state machine
  type states is (init, inst_ldpriv, read_priv_h, read_priv_l,
    read_pub_c, read_pub_p, inst_sgn, read_msg,
    picnic_start, picnic_seeds, picnic_salt,
    picnic_tapes_init, picnic_tapes_start, picnic_tape_finish,
    picnic_mpc_start, picnic_mpc_finish_commit, picnic_mpc_bram,
    picnic_mpc_bram_last, picnic_commit_finish, picnic_commit_bram,
    picnic_h3_oshare, picnic_h3_commit0, picnic_h3_commit1,
    picnic_h3_pk_C, picnic_h3_pk_p, picnic_h3_salt0, picnic_h3_salt1,
    picnic_h3_msg, picnic_chal_fin, picnic_out_header, picnic_out_chal,
    picnic_out_salt0, picnic_out_salt1, picnic_fifo_commit0,
    picnic_fifo_commit1, picnic_fifo_trans, picnic_fifo_trans_last,
    picnic_fifo_seed0, picnic_fifo_seed1, picnic_fifo_ishare,
    picnic_success);
  signal State_DN, State_DP : states;

  -- registers
  signal SK_DN, SK_DP : std_logic_vector(PICNIC_S - 1 downto 0);
  signal PC_DN, PC_DP : std_logic_vector(PICNIC_S - 1 downto 0);
  signal PP_DN, PP_DP : std_logic_vector(PICNIC_S - 1 downto 0);
  signal MSG_DN, MSG_DP : std_logic_vector(MSG_LEN - 1 downto 0);
  signal Salt_DN, Salt_DP : std_logic_vector(SALT_LEN - 1 downto 0);

  -- components

  component xilinx_TDP_RAM is
    generic(
      ADDR_WIDTH : integer := 32;
      DATA_WIDTH : integer := 64;
      ENTRIES    : integer := 32  -- number of entries  (should be a power of 2)
      );
    port(
      clk : in std_logic;  -- clock

      addra : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Port A Address bus, width determined from RAM_DEPTH
      addrb : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Port B Address bus, width determined from RAM_DEPTH
      dina  : in std_logic_vector(DATA_WIDTH-1 downto 0);  -- Port A RAM input data
      dinb  : in std_logic_vector(DATA_WIDTH-1 downto 0);  -- Port B RAM input data

      wea : in std_logic;  -- Port A Write enable
      web : in std_logic;  -- Port B Write enable
      ena : in std_logic;  -- Port A RAM Enable, for additional power savings, disable port when not in use
      enb : in std_logic;  -- Port B RAM Enable, for additional power savings, disable port when not in use

      douta : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- Port A RAM output data
      doutb : out std_logic_vector(DATA_WIDTH-1 downto 0)   -- Port B RAM output data
      );
  end component;

  component seeds
    port(
      -- Clock and Reset
      signal Clk_CI      : in std_logic;
      signal Rst_RI      : in std_logic;
      -- Input signals
      signal Start_SI    : in std_logic;
      signal Next_SI     : in std_logic;
      signal Plain_DI    : in std_logic_vector(N - 1 downto 0);
      signal Key_DI      : in std_logic_vector(K - 1 downto 0);
      signal Cipher_DI   : in std_logic_vector(N - 1 downto 0);
      signal Message_DI  : in std_logic_vector(MSG_LEN - 1 downto 0);
      -- Output signals
      signal Ready_SO    : out std_logic;
      signal Seed_0_DO   : out std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_1_DO   : out std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_2_DO   : out std_logic_vector(PICNIC_S - 1 downto 0)
    );
  end component;

  component tapes
    port(
      -- Clock and Reset
      signal Clk_CI    : in std_logic;
      signal Rst_RI    : in std_logic;
      -- Input signals
      signal Start_SI  : in std_logic;
      signal Seed_0_DI : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_1_DI : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_2_DI : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Salt_DI   : in std_logic_vector(SALT_LEN - 1 downto 0);
      signal Round_DI  : in integer range 0 to T;
      -- Output signals
      signal Finish_SO : out std_logic;
      signal Key_R0_DO : out std_logic_vector(K - 1 downto 0);
      signal Key_R1_DO : out std_logic_vector(K - 1 downto 0);
      signal Rand_0_DO : out std_logic_vector(R * S - 1 downto 0);
      signal Rand_1_DO : out std_logic_vector(R * S - 1 downto 0);
      signal Rand_2_DO : out std_logic_vector(R * S - 1 downto 0)
    );
  end component;

  component lowmc_mpc
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
  end component;

  component commit
    port(
      -- Clock and Reset
      signal Clk_CI      : in std_logic;
      signal Rst_RI      : in std_logic;
      -- Input signals
      signal Start_SI    : in std_logic;
      signal Seed_0_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_1_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_2_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Key_DI      : in std_logic_vector(K - 1 downto 0);
      signal Key_R0_DI   : in std_logic_vector(K - 1 downto 0);
      signal Key_R1_DI   : in std_logic_vector(K - 1 downto 0);
      signal TS_0_DI     : in std_logic_vector(R * S - 1 downto 0);
      signal TS_1_DI     : in std_logic_vector(R * S - 1 downto 0);
      signal TS_2_DI     : in std_logic_vector(R * S - 1 downto 0);
      signal Cipher_0_DI : in std_logic_vector(N - 1 downto 0);
      signal Cipher_1_DI : in std_logic_vector(N - 1 downto 0);
      signal Cipher_2_DI : in std_logic_vector(N - 1 downto 0);
      -- Output signals
      signal Finish_SO   : out std_logic;
      signal Commit_0_DO : out std_logic_vector(DIGEST_L - 1 downto 0);
      signal Commit_1_DO : out std_logic_vector(DIGEST_L - 1 downto 0);
      signal Commit_2_DO : out std_logic_vector(DIGEST_L - 1 downto 0)
    );
  end component;

  component h3
    port(
        -- Clock and Reset
      signal Clk_CI      : in std_logic;
      signal Rst_RI      : in std_logic;
      -- Input signals
      signal Start_SI    : in std_logic;
      signal Valid_SI    : in std_logic;
      signal Block_DI    : in std_logic_vector(PICNIC_S - 1 downto 0);
      -- Output signals
      signal Ready_SO    : out std_logic;
      signal Chal_DO     : out std_logic_vector(2 * T - 1 downto 0);
      signal Sig_Len_DO  : out integer range 0 to MAX_SIG
    );
  end component;

  component output_fifo
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
  end component;

begin

  -- -- BRAM for the seed0, seed1, seed2
  SEED_BRAM_GEN : for i in 0 to 2 generate
    SEED0_RAM : xilinx_TDP_RAM
    generic map(
      ADDR_WIDTH => SEED_ADDR_WIDTH,
      DATA_WIDTH => SEED_DATA_WIDTH,
      ENTRIES => SEED_ENTRIES
    )
    port map(
      clk => clk,
      addra => seed_addra,
      addrb => seed_addrb,
      dina => seed_dina(i),
      dinb => seed_dinb(i),
      wea => seed_wea,
      web => seed_web,
      ena => '1',
      enb => '1',
      douta => seed_douta(i),
      doutb => seed_doutb(i)
    );
  end generate SEED_BRAM_GEN;

  -- -- BRAM for the view_ishare0, view_ishare1, view_ishare2
  View_I_BRAM_GEN : for i in 0 to 2 generate
    VIEW_I_RAM : xilinx_TDP_RAM
    generic map(
      ADDR_WIDTH => VIEW_I_ADDR_WIDTH,
      DATA_WIDTH => VIEW_I_DATA_WIDTH,
      ENTRIES => VIEW_I_ENTRIES
    )
    port map(
      clk => clk,
      addra => view_i_addra,
      addrb => view_i_addrb,
      dina => view_i_dina(i),
      dinb => view_i_dinb(i),
      wea => view_i_wea,
      web => view_i_web,
      ena => '1',
      enb => '1',
      douta => view_i_douta(i),
      doutb => view_i_doutb(i)
    );
  end generate View_I_BRAM_GEN;

  -- -- BRAM for the view_oshare0, view_oshare1, view_oshare2
  VIW_O_BRAM_GEN : for i in 0 to 2 generate
    VIEW_O_RAM : xilinx_TDP_RAM
    generic map(
      ADDR_WIDTH => VIEW_O_ADDR_WIDTH,
      DATA_WIDTH => VIEW_O_DATA_WIDTH,
      ENTRIES => VIEW_O_ENTRIES
    )
    port map(
      clk => clk,
      addra => view_o_addra,
      addrb => view_o_addrb,
      dina => view_o_dina(i),
      dinb => view_o_dinb(i),
      wea => view_o_wea,
      web => view_o_web,
      ena => '1',
      enb => '1',
      douta => view_o_douta(i),
      doutb => view_o_doutb(i)
    );
  end generate VIW_O_BRAM_GEN;

  -- -- BRAM for the view_ts0, view_ts1, view_ts2
  VIW_TS_BRAM_GEN : for i in 0 to 2 generate
    VIEW_TS_RAM : xilinx_TDP_RAM
    generic map(
      ADDR_WIDTH => VIEW_TS_ADDR_WIDTH,
      DATA_WIDTH => VIEW_TS_DATA_WIDTH,
      ENTRIES => VIEW_TS_ENTRIES
    )
    port map(
      clk => clk,
      addra => view_ts_addra,
      addrb => view_ts_addrb,
      dina => view_ts_dina(i),
      dinb => view_ts_dinb(i),
      wea => view_ts_wea,
      web => view_ts_web,
      ena => '1',
      enb => '1',
      douta => view_ts_douta(i),
      doutb => view_ts_doutb(i)
    );
  end generate VIW_TS_BRAM_GEN;

  -- -- BRAM for the commit0, commit1, commit2
  COMM_BRAM_GEN : for i in 0 to 2 generate
    COMM_RAM : xilinx_TDP_RAM
    generic map(
      ADDR_WIDTH => COMMIT_ADDR_WIDTH,
      DATA_WIDTH => COMMIT_DATA_WIDTH,
      ENTRIES => COMMIT_ENTRIES
    )
    port map(
      clk => clk,
      addra => comm_addra,
      addrb => comm_addrb,
      dina => comm_dina(i),
      dinb => comm_dinb(i),
      wea => comm_wea,
      web => comm_web,
      ena => '1',
      enb => '1',
      douta => comm_douta(i),
      doutb => comm_doutb(i)
    );
  end generate COMM_BRAM_GEN;

  -- calculates the random seeds
  SEED : seeds
  port map (
    Clk_CI      => clk,
    Rst_RI      => rst,
    Start_SI    => seed_start,
    Next_SI     => seed_next,
    Plain_DI    => PP_DP,
    Key_DI      => SK_DP,
    Cipher_DI   => PC_DP,
    Message_DI  => MSG_DP,
    Ready_SO    => seed_ready,
    Seed_0_DO   => seed_out(0),
    Seed_1_DO   => seed_out(1),
    Seed_2_DO   => seed_out(2)
  );

  -- calculates the tapes for mpc
  TAPE : tapes
  port map (
    Clk_CI    => clk,
    Rst_RI    => rst,
    Start_SI  => tape_start,
    Seed_0_DI => seed_doutb(0),
    Seed_1_DI => seed_doutb(1),
    Seed_2_DI => seed_doutb(2),
    Salt_DI   => Salt_DP,
    Round_DI  => tape_round_in,
    Finish_SO => tape_finish,
    Key_R0_DO => tape_k0_out,
    Key_R1_DO => tape_k1_out,
    Rand_0_DO => tape_rand_out(0),
    Rand_1_DO => tape_rand_out(1),
    Rand_2_DO => tape_rand_out(2)
  );

  MPC : lowmc_mpc
  port map (
    Clk_CI      => clk,
    Rst_RI      => rst,
    Plain_DI    => PP_DP,
    Key_DI      => SK_DP,
    Key_R0_DI   => tape_k0_out,
    Key_R1_DI   => tape_k1_out,
    Rand_0_DI   => tape_rand_out(0),
    Rand_1_DI   => tape_rand_out(1),
    Rand_2_DI   => tape_rand_out(2),
    Start_SI    => mpc_start,
    Init_SI     => mpc_init,
    Finish_SO   => mpc_finish,
    Cipher_0_DO => mpc_c_out(0),
    Cipher_1_DO => mpc_c_out(1),
    Cipher_2_DO => mpc_c_out(2),
    TS_0_DO     => mpc_ts_out(0),
    TS_1_DO     => mpc_ts_out(1),
    TS_2_DO     => mpc_ts_out(2)
  );

  COMM : commit
  port map (
    Clk_CI      => clk,
    Rst_RI      => rst,
    Start_SI    => comm_start,
    Seed_0_DI   => seed_douta(0),
    Seed_1_DI   => seed_douta(1),
    Seed_2_DI   => seed_douta(2),
    Key_DI      => SK_DP,
    Key_R0_DI   => comm_key_0_in,
    Key_R1_DI   => comm_key_1_in,
    TS_0_DI     => mpc_ts_out(0),
    TS_1_DI     => mpc_ts_out(1),
    TS_2_DI     => mpc_ts_out(2),
    Cipher_0_DI => mpc_c_out(0),
    Cipher_1_DI => mpc_c_out(1),
    Cipher_2_DI => mpc_c_out(2),
    Finish_SO   => comm_finish,
    Commit_0_DO => comm_out(0),
    Commit_1_DO => comm_out(1),
    Commit_2_DO => comm_out(2)
  );

  H3_MOD : h3
  port map (
    Clk_CI      => clk,
    Rst_RI      => rst,
    Start_SI    => h3_start,
    Valid_SI    => h3_valid,
    Block_DI    => h3_block,
    Ready_SO    => h3_ready,
    Chal_DO     => h3_chal_out,
    Sig_Len_DO  => h3_sig_len_out
  );

  FIFO : output_fifo
  port map (
    clk                => clk,
    rst                => rst,
    Init_DI            => fifo_init_data,
    Init_SI            => fifo_init,
    Data_DI            => fifo_data,
    Valid_Data_SI      => fifo_valid_data,
    Unaligned_DI       => fifo_unaligned,
    Valid_Unaligned_SI => fifo_valid_unaligned,
    Ready_SI           => fifo_ready_in,
    Data_DO            => fifo_out,
    Valid_SO           => fifo_valid_out,
    Ready_SO           => fifo_ready_out,
    Skip_SO            => fifo_skip
  );

  -- comm input
  comm_key_0_in <= view_i_douta(0) & view_i_doutb(0);
  comm_key_1_in <= view_i_douta(1) & view_i_doutb(1);

  -- output logic
  process (State_DP, sdi_valid, sdi_data, pdi_valid, pdi_data, Counter_DP, PC_DP, PP_DP, MSG_DP, SK_DP, seed_out, seed_ready, tape_finish, tape_k0_out, tape_k1_out, mpc_finish, mpc_c_out, Counter_Trans_DP, mpc_ts_out, comm_finish, comm_out, h3_ready, view_o_douta, view_o_doutb, comm_douta, comm_doutb, h3_sig_len_out, pdo_ready, h3_chal_out, fifo_ready_out, fifo_out, fifo_valid_out, view_ts_douta, view_ts_doutb, seed_douta, seed_doutb, view_i_douta, view_i_doutb, Salt_DP)
    variable tape_k2_out : std_logic_vector(PICNIC_S - 1 downto 0);
    variable ET_VEC : std_logic_vector(1 downto 0);
    variable ET : integer range 0 to 2;
    variable C_INDEX : integer range 0 to 2;
  begin
    -- default
    seed_addra <= (others => '0');
    seed_addrb <= (others => '0');
    seed_dina <= (others => (others => '0'));
    seed_dinb <= (others => (others => '0'));
    seed_wea <= '0';
    seed_web <= '0';

    view_i_addra <= (others => '0');
    view_i_addrb <= (others => '0');
    view_i_dina <= (others => (others => '0'));
    view_i_dinb <= (others => (others => '0'));
    view_i_wea <= '0';
    view_i_web <= '0';

    view_o_addra <= (others => '0');
    view_o_addrb <= (others => '0');
    view_o_dina <= (others => (others => '0'));
    view_o_dinb <= (others => (others => '0'));
    view_o_wea <= '0';
    view_o_web <= '0';

    view_ts_addra <= (others => '0');
    view_ts_addrb <= (others => '0');
    view_ts_dina <= (others => (others => '0'));
    view_ts_dinb <= (others => (others => '0'));
    view_ts_wea <= '0';
    view_ts_web <= '0';

    comm_addra <= (others => '0');
    comm_addrb <= (others => '0');
    comm_dina <= (others => (others => '0'));
    comm_dinb <= (others => (others => '0'));
    comm_wea <= '0';
    comm_web <= '0';

    fifo_valid_data <= '0';
    fifo_valid_unaligned <= '0';
    fifo_ready_in <= '0';
    fifo_init <= '0';
    fifo_data <= (others => '0');
    fifo_unaligned <= (others => '0');
    fifo_init_data <= (others => '0');

    pdi_ready <= '0';
    sdi_ready <= '0';
    SK_DN <= SK_DP;
    Counter_DN <= Counter_DP;
    Counter_Trans_DN <= Counter_Trans_DP;
    PC_DN <= PC_DP;
    PP_DN <= PP_DP;
    MSG_DN <= MSG_DP;
    seed_start <= '0';
    seed_next <= '0';
    status_ready <= '0';
    tape_start <= '0';
    tape_k2_out := tape_k0_out xor tape_k1_out xor SK_DP;
    mpc_init <= '0';
    mpc_start <= '0';
    comm_start <= '0';
    h3_block <= (others => '0');
    h3_start <= '0';
    h3_valid <= '0';
    pdo_valid <= '0';
    pdo_data <= (others => '0');
    pdo_last <= '0';
    tape_round_in <= 0;
    Salt_DN <= Salt_DP;

    case State_DP is
      when init =>
        pdi_ready <= '1';
      when inst_ldpriv =>
        sdi_ready <= '1';
      when read_priv_h =>
        sdi_ready <= '1';
        if sdi_valid = '1' then
          SK_DN(PICNIC_S - 1 downto PICNIC_S - SDI_WIDTH) <= sdi_data;
        end if;
      when read_priv_l =>
        sdi_ready <= '1';
        if sdi_valid = '1' then
          SK_DN(PICNIC_S - SDI_WIDTH - 1 downto 0) <= sdi_data;
        end if;
      when read_pub_c =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          PC_DN <= pdi_data;
        end if;
      when read_pub_p =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          PP_DN <= pdi_data;
        end if;
      when inst_sgn =>
        pdi_ready <= '1';
        Counter_DN <= 0;
      when read_msg =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          Counter_DN <= Counter_DP + 1;
          MSG_DN(MSG_LEN - 1 downto PDI_WIDTH) <= MSG_DP(MSG_LEN - PDI_WIDTH - 1 downto 0);
          MSG_DN(PDI_WIDTH - 1 downto 0) <= pdi_data;
        end if;
      when picnic_start =>
        mpc_init <= '1'; -- start first mpc run to get constants
        seed_start <= '1';
        Counter_DN <= 0;
      when picnic_seeds =>
        if seed_ready = '1' then
          if Counter_DP >= T - 1 then
            Counter_DN <= 0;
          else
            Counter_DN <= Counter_DP + 1;
          end if;
          seed_next <= '1';
          -- store seeds in bram
          seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
          for i in 0 to 2 loop
            seed_dina(i) <= seed_out(i);
          end loop;
          seed_wea <= '1';
        end if;
      when picnic_salt =>
        if seed_ready = '1' then
          Salt_DN <= seed_out(0) & seed_out(1);
        end if;
      when picnic_tapes_init =>
        -- prepare addresses for bram
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
      when picnic_tapes_start =>
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        tape_round_in <= Counter_DP;
        tape_start <= '1';
      when picnic_tape_finish =>
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        tape_round_in <= Counter_DP;
        if tape_finish = '1' then
          -- store view_ishare in BRAM
          view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
          view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
          view_i_dina(0) <= tape_k0_out(PICNIC_S - 1 downto PICNIC_S - VIEW_I_DATA_WIDTH);
          view_i_dinb(0) <= tape_k0_out(PICNIC_S - VIEW_I_DATA_WIDTH - 1 downto 0);
          view_i_dina(1) <= tape_k1_out(PICNIC_S - 1 downto PICNIC_S - VIEW_I_DATA_WIDTH);
          view_i_dinb(1) <= tape_k1_out(PICNIC_S - VIEW_I_DATA_WIDTH - 1 downto 0);
          view_i_dina(2) <= tape_k2_out(PICNIC_S - 1 downto PICNIC_S - VIEW_I_DATA_WIDTH);
          view_i_dinb(2) <= tape_k2_out(PICNIC_S - VIEW_I_DATA_WIDTH - 1 downto 0);
          view_i_wea <= '1';
          view_i_web <= '1';
        end if;
      when picnic_mpc_start =>
        if mpc_finish = '1' then
          mpc_start <= '1';
        end if;
        -- seeds/iview for the commit/tape module
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
          view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + 1, SEED_ADDR_WIDTH));
      when picnic_mpc_finish_commit =>
        if mpc_finish = '1' then
          -- store viw_oshare in BRAM
          view_o_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_O_ADDR_WIDTH));
          view_o_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_O_ADDR_WIDTH));
          for i in 0 to 2 loop
            view_o_dina(i) <= mpc_c_out(i)(PICNIC_S - 1 downto PICNIC_S - VIEW_O_DATA_WIDTH);
            view_o_dinb(i) <= mpc_c_out(i)(PICNIC_S - VIEW_O_DATA_WIDTH - 1 downto 0);
          end loop;
          view_o_wea <= '1';
          view_o_web <= '1';
          -- store view_transcript in BRAM
          Counter_Trans_DN <= 2;
          view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS, VIEW_TS_ADDR_WIDTH));
          view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + 1, VIEW_TS_ADDR_WIDTH));
          for i in 0 to 2 loop
            view_ts_dina(i) <= mpc_ts_out(i)(R * S - 1 downto R * S - VIEW_TS_DATA_WIDTH);
            view_ts_dinb(i) <= mpc_ts_out(i)(R * S - VIEW_TS_DATA_WIDTH - 1 downto R * S - VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH);
          end loop;
          view_ts_wea <= '1';
          view_ts_web <= '1';
          -- start commit and tape
          comm_start <= '1';
          tape_start <= '1';
        end if;
        tape_round_in <= Counter_DP + 1;
        -- seeds/iview for the commit/tape module
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + 1, SEED_ADDR_WIDTH));
      when picnic_mpc_bram =>
        Counter_Trans_DN <= Counter_Trans_DP + 2;
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 1, VIEW_TS_ADDR_WIDTH));
        for i in 0 to 2 loop
          view_ts_dina(i) <= mpc_ts_out(i)(R * S - Counter_Trans_DP * VIEW_TS_DATA_WIDTH - 1 downto R * S - Counter_Trans_DP * VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH);
          view_ts_dinb(i) <= mpc_ts_out(i)(R * S -  Counter_Trans_DP * VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH - 1 downto R * S - Counter_Trans_DP * VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH);
        end loop;
        view_ts_wea <= '1';
        view_ts_web <= '1';
        tape_round_in <= Counter_DP + 1;
        -- seeds/iview for the commit/tape module
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + 1, SEED_ADDR_WIDTH));
      when picnic_mpc_bram_last =>
        -- last entry of TS BRAM
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 1, VIEW_TS_ADDR_WIDTH));
        for i in 0 to 2 loop
          view_ts_dina(i) <= mpc_ts_out(i)(RS_LAST_SEG + VIEW_TS_DATA_WIDTH - 1 downto RS_LAST_SEG);
          view_ts_dinb(i) <= mpc_ts_out(i)(RS_LAST_SEG - 1 downto 0) & RS_PAD;
        end loop;
        tape_round_in <= Counter_DP + 1;
        view_ts_wea <= '1';
        view_ts_web <= '1';
        -- seeds/iview for the commit/tape module
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + 1, SEED_ADDR_WIDTH));
      when picnic_commit_finish =>
        tape_round_in <= Counter_DP + 1;
        -- seeds/iview for the commit/tape module
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + 1, SEED_ADDR_WIDTH));
        if comm_finish = '1' and tape_finish = '1' then
          -- store commit in BRAM
          comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
          comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
          for i in 0 to 2 loop
            comm_dina(i) <= comm_out(i)(DIGEST_L - 1 downto DIGEST_L - COMMIT_DATA_WIDTH);
            comm_dinb(i) <= comm_out(i)(DIGEST_L - COMMIT_DATA_WIDTH - 1 downto DIGEST_L - COMMIT_DATA_WIDTH - COMMIT_DATA_WIDTH);
          end loop;
          comm_wea <= '1';
          comm_web <= '1';
          -- store view_ishare in BRAM
          view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 2, VIEW_I_ADDR_WIDTH));
          view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 3, VIEW_I_ADDR_WIDTH));
          view_i_dina(0) <= tape_k0_out(PICNIC_S - 1 downto PICNIC_S - VIEW_I_DATA_WIDTH);
          view_i_dinb(0) <= tape_k0_out(PICNIC_S - VIEW_I_DATA_WIDTH - 1 downto 0);
          view_i_dina(1) <= tape_k1_out(PICNIC_S - 1 downto PICNIC_S - VIEW_I_DATA_WIDTH);
          view_i_dinb(1) <= tape_k1_out(PICNIC_S - VIEW_I_DATA_WIDTH - 1 downto 0);
          view_i_dina(2) <= tape_k2_out(PICNIC_S - 1 downto PICNIC_S - VIEW_I_DATA_WIDTH);
          view_i_dinb(2) <= tape_k2_out(PICNIC_S - VIEW_I_DATA_WIDTH - 1 downto 0);
          view_i_wea <= '1';
          view_i_web <= '1';
        end if;
      when picnic_commit_bram =>
        -- store second half of commit in BRAM
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, SEED_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, SEED_ADDR_WIDTH));
        for i in 0 to 2 loop
          comm_dina(i) <= comm_out(i)(COMMIT_DATA_WIDTH + COMMIT_DATA_WIDTH - 1 downto COMMIT_DATA_WIDTH);
          comm_dinb(i) <= comm_out(i)(COMMIT_DATA_WIDTH - 1 downto 0);
        end loop;
        comm_wea <= '1';
        comm_web <= '1';
        if Counter_DP >= T - 1 then
          -- prepare h3
          Counter_DN <= 0;
          Counter_Trans_DN <= 0;
          h3_start <= '1';
          -- view_o_addra <= std_logic_vector(to_unsigned(0, VIEW_O_ADDR_WIDTH));
          view_o_addrb <= std_logic_vector(to_unsigned(1, VIEW_O_ADDR_WIDTH));
        else
          -- increment T counter
          Counter_DN <= Counter_DP + 1;
        end if;
      when picnic_h3_oshare =>
        view_o_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_O_ADDR_WIDTH));
        view_o_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_O_ADDR_WIDTH));
        h3_valid <= '1';
        h3_block <= view_o_douta(Counter_Trans_DP) & view_o_doutb(Counter_Trans_DP);
        if h3_ready = '1' then
          if Counter_DP >= T - 1 and Counter_Trans_DP >= 2 then
            -- prepare for commit
            comm_addra <= std_logic_vector(to_unsigned(0, COMMIT_ADDR_WIDTH));
            comm_addrb <= std_logic_vector(to_unsigned(1, COMMIT_ADDR_WIDTH));
            Counter_Trans_DN <= 0;
            Counter_DN <= 0;
          elsif Counter_Trans_DP >= 2 then
            Counter_Trans_DN <= 0;
            Counter_DN <= Counter_DP + 1;
            view_o_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 2, VIEW_O_ADDR_WIDTH));
            view_o_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 3, VIEW_O_ADDR_WIDTH));
          else
            Counter_Trans_DN <= Counter_Trans_DP + 1;
          end if;
        end if;
      when picnic_h3_commit0 =>
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, COMMIT_ADDR_WIDTH));
        h3_valid <= '1';
        h3_block <= comm_douta(Counter_Trans_DP) & comm_doutb(Counter_Trans_DP);
        if h3_ready = '1' then
          comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, COMMIT_ADDR_WIDTH));
          comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, COMMIT_ADDR_WIDTH));
        end if;
      when picnic_h3_commit1 =>
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, COMMIT_ADDR_WIDTH));
        h3_valid <= '1';
        h3_block <= comm_douta(Counter_Trans_DP) & comm_doutb(Counter_Trans_DP);
        if h3_ready = '1' then
          comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, COMMIT_ADDR_WIDTH));
          comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, COMMIT_ADDR_WIDTH));
          if Counter_Trans_DP >= 2 then
            Counter_Trans_DN <= 0;
            Counter_DN <= Counter_DP + 1;
            comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 4, COMMIT_ADDR_WIDTH));
            comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 5, COMMIT_ADDR_WIDTH));
          else
            Counter_Trans_DN <= Counter_Trans_DP + 1;
          end if;
        end if;
      when picnic_h3_pk_C =>
        h3_valid <= '1';
        h3_block <= PC_DP;
      when picnic_h3_pk_p =>
        Counter_DN <= 0;
        h3_valid <= '1';
        h3_block <= PP_DP;
      when picnic_h3_salt0 =>
        h3_valid <= '1';
        h3_block <= Salt_DP(SALT_LEN - 1 downto PICNIC_S);
      when picnic_h3_salt1 =>
        h3_valid <= '1';
        h3_block <= Salt_DP(PICNIC_S - 1 downto 0);
      when picnic_h3_msg =>
        h3_valid <= '1';
        h3_block <= MSG_DP(MSG_LEN - 1 downto MSG_LEN - PICNIC_S);
        if h3_ready = '1' then
          Counter_DN <= Counter_DP + 1;
          -- rotate msg
          MSG_DN(PICNIC_S - 1 downto 0) <= MSG_DP(MSG_LEN - 1 downto MSG_LEN - PICNIC_S);
          MSG_DN(MSG_LEN - 1 downto PICNIC_S) <= MSG_DP(MSG_LEN - PICNIC_S - 1 downto 0);
        end if;
      when picnic_chal_fin =>
      when picnic_out_header =>
        pdo_data <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(h3_sig_len_out, H_LEN_WIDTH)) & pad_96;
        pdo_valid <= '1';
        pdo_last <= '1';
        Counter_DN <= 0;
        fifo_init <= '1'; -- gets the fifo into the init state
      when picnic_out_chal =>
        pdo_data <= h3_chal_out(2 * T - 1 - Counter_DP * PDO_WIDTH downto 2 * T - Counter_DP * PDO_WIDTH - PDO_WIDTH);
        pdo_valid <= '1';
        if pdo_ready = '1' and Counter_DP >= SIG_OUTS - 1 then
          Counter_DN <= 0;
          -- init the fifo
          fifo_init_data <= h3_chal_out(2 * T - SIG_OUTS * PDO_WIDTH - 1 downto 0) & CHAL_PAD;
          fifo_valid_data <= '1';
          fifo_valid_unaligned <= '1';
        elsif pdo_ready = '1' then
          Counter_DN <= Counter_DP + 1;
        end if;
      when picnic_out_salt0 =>
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= Salt_DP(SALT_LEN - 1 downto PICNIC_S);
      when picnic_out_salt1 =>
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= Salt_DP(PICNIC_S - 1 downto 0);
        -- prepare commit bram
        comm_addra <= std_logic_vector(to_unsigned(0, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(1, COMMIT_ADDR_WIDTH));
      when picnic_fifo_commit0 =>
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, COMMIT_ADDR_WIDTH));
        -- ET
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        ET := to_integer(unsigned(ET_VEC));
        case ET is
          when 0 =>
            C_INDEX := 2;
          when 1 =>
            C_INDEX := 0;
          when 2 =>
            C_INDEX := 1;
        end case;
        -- fifo communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= comm_douta(C_INDEX) & comm_doutb(C_INDEX);
        -- next
        if fifo_ready_out = '1' then
          -- next half of commit
          comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, COMMIT_ADDR_WIDTH));
          comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, COMMIT_ADDR_WIDTH));
        end if;
      when picnic_fifo_commit1 =>
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, COMMIT_ADDR_WIDTH));
        -- ET
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        ET := to_integer(unsigned(ET_VEC));
        case ET is
          when 0 =>
            C_INDEX := 2;
          when 1 =>
            C_INDEX := 0;
          when 2 =>
            C_INDEX := 1;
        end case;
        -- fifo communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= comm_douta(C_INDEX) & comm_doutb(C_INDEX);
        -- prepare transcript
        Counter_Trans_DN <= 0;
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + 1, VIEW_TS_ADDR_WIDTH));
      when picnic_fifo_trans =>
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 1, VIEW_TS_ADDR_WIDTH));
        -- ET
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        ET := to_integer(unsigned(ET_VEC));
        case ET is
          when 0 =>
            C_INDEX := 1;
          when 1 =>
            C_INDEX := 2;
          when 2 =>
            C_INDEX := 0;
        end case;
        -- fifo_communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= view_ts_douta(C_INDEX) & view_ts_doutb(C_INDEX);
        -- next
        if fifo_ready_out = '1' then
          -- prepare next part of transcript
          view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 2, VIEW_TS_ADDR_WIDTH));
          view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 3, VIEW_TS_ADDR_WIDTH));
          Counter_Trans_DN <= Counter_Trans_DP + 2;
        end if;
        -- prepare seeds
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
      when picnic_fifo_trans_last =>
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 1, VIEW_TS_ADDR_WIDTH));
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        -- ET
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        ET := to_integer(unsigned(ET_VEC));
        case ET is
          when 0 =>
            C_INDEX := 1;
          when 1 =>
            C_INDEX := 2;
          when 2 =>
            C_INDEX := 0;
        end case;
        -- fifo_communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_unaligned <= '1';
        fifo_unaligned <= view_ts_douta(C_INDEX) & view_ts_doutb(C_INDEX)(VIEW_TS_DATA_WIDTH - 1 downto VIEW_TS_DATA_WIDTH - RS_LAST_SEG);
        -- if possible, also set data (skip unnecessary wait cycle sometimes)
        fifo_valid_data <= '1';
        fifo_data <= seed_douta(ET);
      when picnic_fifo_seed0 =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        -- ET
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        ET := to_integer(unsigned(ET_VEC));
        -- fifo_communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= seed_douta(ET);
      when picnic_fifo_seed1 =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP, SEED_ADDR_WIDTH));
        -- ET
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        ET := to_integer(unsigned(ET_VEC));
        case ET is
          when 0 =>
            C_INDEX := 1;
          when 1 =>
            C_INDEX := 2;
          when 2 =>
            C_INDEX := 0;
        end case;
        -- fifo_communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= seed_douta(C_INDEX);
        -- next already?
        if fifo_ready_out = '1' and ET = 0 then
          if Counter_DP >= T - 1 then
            pdo_last <= '1';
          end if;
          Counter_DN <= Counter_DP + 1;
        end if;
        -- prepare view_ishare
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        -- prepare commit
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 4, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 5, COMMIT_ADDR_WIDTH));
      when picnic_fifo_ishare =>
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        -- fifo_communication
        pdo_data <= fifo_out;
        pdo_valid <= fifo_valid_out;
        fifo_ready_in <= pdo_ready;
        fifo_valid_data <= '1';
        fifo_data <= view_i_douta(2) & view_i_doutb(2);
        -- next already?
        if fifo_ready_out = '1' then
          if Counter_DP >= T - 1 then
            pdo_last <= '1';
          end if;
          Counter_DN <= Counter_DP + 1;
        end if;
        -- prepare commit
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 4, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 5, COMMIT_ADDR_WIDTH));
      when picnic_success =>
        pdo_valid <='1';
        pdo_data <= S_SUCCESS & pad_112;
        status_ready <= '1';
        pdo_last <= '1';
    end case;
  end process;

  -- next state logic
  process (State_DP, pdi_valid, pdi_data, Counter_DP, seed_ready, tape_finish, mpc_finish, Counter_Trans_DP, comm_finish, h3_ready, pdo_ready, h3_chal_out, fifo_ready_out, fifo_skip, sdi_valid, sdi_data)
    variable ET_VEC : std_logic_vector(1 downto 0);
  begin
    -- default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if pdi_valid = '1' and pdi_data = I_LDPRIVKEY & pad_112 then
          State_DN <= inst_ldpriv;
        elsif pdi_valid = '1' and pdi_data = I_SGN & pad_112 then
          State_DN <= inst_sgn;
        elsif pdi_valid = '1' and pdi_data = L1_H_PUB & pad_96 then
          State_DN <= read_pub_c;
        end if;
      when inst_ldpriv =>
        if sdi_valid = '1' and sdi_data = L1_H_PRIV & pad_32 then
          State_DN <= read_priv_h;
        elsif sdi_valid = '1' then
          State_DN <= init;
        end if;
      when read_priv_h =>
        if sdi_valid = '1' then
          State_DN <= read_priv_l;
        end if;
      when read_priv_l =>
        if sdi_valid = '1' then
          State_DN <= init;
        end if;
      when read_pub_c =>
        if pdi_valid = '1' then
          State_DN <= read_pub_p;
        end if;
      when read_pub_p =>
        if pdi_valid = '1' then
          State_DN <= init;
        end if;
      when inst_sgn =>
        -- only support 512 bit msg for now
        if pdi_valid = '1' and pdi_data = L1_H_MSG & pad_96 then
          State_DN <= read_msg;
        elsif pdi_valid = '1' then
          State_DN <= init;
        end if;
      when read_msg =>
        if pdi_valid = '1' and Counter_DP >= 3 then
          State_DN <= picnic_start;
        end if;
      when picnic_start =>
        State_DN <= picnic_seeds;
      when picnic_seeds =>
        if seed_ready = '1' and Counter_DP >= T - 1 then
          State_DN <= picnic_salt;
        end if;
      when picnic_salt =>
        if seed_ready = '1' then
          State_DN <= picnic_tapes_init;
        end if;
      when picnic_tapes_init =>
        State_DN <= picnic_tapes_start;
      when picnic_tapes_start =>
        State_DN <= picnic_tape_finish;
      when picnic_tape_finish =>
        if tape_finish = '1' then
          State_DN <= picnic_mpc_start;
        end if;
      when picnic_mpc_start =>
        if mpc_finish = '1' then
          State_DN <= picnic_mpc_finish_commit;
        end if;
      when picnic_mpc_finish_commit =>
        if mpc_finish = '1' then
          State_DN <= picnic_mpc_bram;
        end if;
      when picnic_mpc_bram =>
        if Counter_Trans_DP >= VIEW_ENTRIE_PER_TS - 4 then
          State_DN <= picnic_mpc_bram_last;
        end if;
      when picnic_mpc_bram_last =>
        State_DN <= picnic_commit_finish;
      when picnic_commit_finish =>
        if comm_finish = '1' and tape_finish = '1' then
          State_DN <= picnic_commit_bram;
        end if;
      when picnic_commit_bram =>
        if Counter_DP >= T - 1 then
          State_DN <= picnic_h3_oshare;
        else
          State_DN <= picnic_mpc_start;
        end if;
      when picnic_h3_oshare =>
        if h3_ready = '1' and Counter_DP >= T - 1 and Counter_Trans_DP >= 2 then
          State_DN <= picnic_h3_commit0;
        end if;
      when picnic_h3_commit0 =>
        if h3_ready = '1' then
          State_DN <= picnic_h3_commit1;
        end if;
      when picnic_h3_commit1 =>
        if h3_ready = '1' and Counter_DP >= T - 1 and Counter_Trans_DP >= 2 then
          State_DN <= picnic_h3_pk_C;
        elsif h3_ready = '1' then
          State_DN <= picnic_h3_commit0;
        end if;
      when picnic_h3_pk_C =>
        if h3_ready = '1' then
          State_DN <= picnic_h3_pk_p;
        end if;
      when picnic_h3_pk_p =>
        if h3_ready = '1' then
          State_DN <= picnic_h3_salt0;
        end if;
      when picnic_h3_salt0 =>
        if h3_ready = '1' then
          State_DN <= picnic_h3_salt1;
        end if;
      when picnic_h3_salt1 =>
        if h3_ready = '1' then
          State_DN <= picnic_h3_msg;
        end if;
      when picnic_h3_msg =>
        if h3_ready = '1' and Counter_DP >= 3 then
          State_DN <= picnic_chal_fin;
        end if;
      when picnic_chal_fin =>
        if h3_ready = '1' then
          State_DN <= picnic_out_header;
        end if;
      when picnic_out_header =>
        if pdo_ready = '1' and h3_ready = '1' then
          State_DN <= picnic_out_chal;
        end if;
      when picnic_out_chal =>
        if pdo_ready = '1' and Counter_DP >= SIG_OUTS - 1 then
          State_DN <= picnic_out_salt0;
        end if;
      when picnic_out_salt0 =>
        if fifo_ready_out = '1' then
          State_DN <= picnic_out_salt1;
        end if;
      when picnic_out_salt1 =>
        if fifo_ready_out = '1' then
          State_DN <= picnic_fifo_commit0;
        end if;
      when picnic_fifo_commit0 =>
        if fifo_ready_out = '1' then
          State_DN <= picnic_fifo_commit1;
        end if;
      when picnic_fifo_commit1 =>
        if fifo_ready_out = '1' then
          State_DN <= picnic_fifo_trans;
        end if;
      when picnic_fifo_trans =>
        if fifo_ready_out = '1' and Counter_Trans_DP >= VIEW_ENTRIE_PER_TS - 4 then
          State_DN <= picnic_fifo_trans_last;
        end if;
      when picnic_fifo_trans_last =>
        if fifo_ready_out = '1' and fifo_skip = '1' then
          State_DN <= picnic_fifo_seed1;
        elsif fifo_ready_out = '1' then
          State_DN <= picnic_fifo_seed0;
        end if;
      when picnic_fifo_seed0 =>
        if fifo_ready_out = '1' then
          State_DN <= picnic_fifo_seed1;
        end if;
      when picnic_fifo_seed1 =>
        ET_VEC := h3_chal_out(2 * T - Counter_DP - Counter_DP - 2) & h3_chal_out(2 * T - Counter_DP - Counter_DP - 1);
        if fifo_ready_out = '1' then
          if ET_VEC = "00" and Counter_DP >= T - 1 then
            State_DN <= picnic_success;
          elsif ET_VEC = "00" then
            State_DN <= picnic_fifo_commit0;
          else
            State_DN <= picnic_fifo_ishare;
          end if;
        end if;
      when picnic_fifo_ishare =>
        if fifo_ready_out = '1' and Counter_DP >= T - 1 then
          State_DN <= picnic_success;
        elsif fifo_ready_out = '1' then
          State_DN <= picnic_fifo_commit0;
        end if;
      when picnic_success =>
        if pdo_ready = '1' then
          State_DN <= init;
        end if;
    end case;
  end process;

  process (clk, rst)
  begin  -- process register_p
    if clk'event and clk = '1' then
      if rst = '1' then               -- synchronous reset (active high)
        State_DP           <= init;
        SK_DP              <= (others => '0');
        PC_DP              <= (others => '0');
        PP_DP              <= (others => '0');
        MSG_DP             <= (others => '0');
        Counter_DP         <= 0;
        Counter_Trans_DP   <= 0;
        Salt_DP            <= (others => '0');
      else
        State_DP           <= State_DN;
        SK_DP              <= SK_DN;
        Counter_DP         <= Counter_DN;
        PC_DP              <= PC_DN;
        PP_DP              <= PP_DN;
        MSG_DP             <= MSG_DN;
        Counter_Trans_DP   <= Counter_Trans_DN;
        Salt_DP            <= Salt_DN;
      end if;
    end if;
  end process;
end behavorial;
