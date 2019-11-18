library work;
use work.lowmc_pkg.all;
use work.keccak_pkg.all;
use work.picnic_pkg.all;
use work.bram_pkg.all;
use work.protocol_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity picnic_verify is
  port(
    -- Clock and Reset
    signal clk          : in std_logic;
    signal rst          : in std_logic;
    -- Public Data Inputs
    signal pdi_data     : in std_logic_vector(PDI_WIDTH - 1 downto 0);
    signal pdi_valid    : in std_logic;
    signal pdi_ready    : out std_logic;
    -- Public Data Outputs
    signal pdo_data     : out std_logic_vector(PDO_WIDTH - 1 downto 0);
    signal pdo_valid    : out std_logic;
    signal pdo_ready    : in std_logic;
    signal pdo_last     : out std_logic;
    -- Status
    signal status_ready : out std_logic
  );
end entity;

architecture behavorial of picnic_verify is
  type S_ARR is array(0 to 1) of std_logic_vector(PICNIC_S - 1 downto 0);

  -- seed_BRAM
  signal seed_addra, seed_addrb : std_logic_vector(SEED_ADDR_WIDTH - 1 downto 0);
  signal seed_wea, seed_web : std_logic_vector(1 downto 0);
  type SEED_ARR is  array(0 to 1) of std_logic_vector(SEED_DATA_WIDTH - 1 downto 0);
  signal seed_dina, seed_dinb : SEED_ARR;
  signal seed_douta, seed_doutb : SEED_ARR;

  -- view_i_BRAM
  signal view_i_addra, view_i_addrb : std_logic_vector(VIEW_I_ADDR_WIDTH - 1 downto 0);
  signal view_i_wea, view_i_web : std_logic;
  signal view_i_dina, view_i_dinb : std_logic_vector(VIEW_I_DATA_WIDTH - 1 downto 0);
  signal view_i_douta, view_i_doutb : std_logic_vector(VIEW_I_DATA_WIDTH - 1 downto 0);

  -- view_o_BRAM
  signal view_o_addra, view_o_addrb : std_logic_vector(VIEW_O_ADDR_WIDTH - 1 downto 0);
  signal view_o_wea, view_o_web : std_logic;
  type VIEW_O_ARR is  array(0 to 2) of std_logic_vector(VIEW_O_DATA_WIDTH - 1 downto 0);
  signal view_o_dina, view_o_dinb : VIEW_O_ARR;
  signal view_o_douta, view_o_doutb : VIEW_O_ARR;

  -- view_ts_BRAM
  signal view_ts_addra, view_ts_addrb : std_logic_vector(VIEW_TS_ADDR_WIDTH - 1 downto 0);
  signal view_ts_wea, view_ts_web : std_logic;
  signal view_ts_dina, view_ts_dinb : std_logic_vector(VIEW_TS_DATA_WIDTH - 1 downto 0);
  signal view_ts_douta, view_ts_doutb : std_logic_vector(VIEW_TS_DATA_WIDTH - 1 downto 0);

  -- commit_BRAM
  signal comm_addra, comm_addrb : std_logic_vector(COMMIT_ADDR_WIDTH - 1 downto 0);
  signal comm_wea, comm_web : std_logic_vector(2 downto 0);
  type COMMIT_ARR is  array(0 to 2) of std_logic_vector(COMMIT_DATA_WIDTH - 1 downto 0);
  signal comm_dina, comm_dinb : COMMIT_ARR;
  signal comm_douta, comm_doutb : COMMIT_ARR;

  -- counter
  signal Counter_DN, Counter_DP : integer range 0 to T;
  signal Counter_Trans_DN, Counter_Trans_DP : integer range 0 to 31;

  -- tapes
  signal tape_start, tape_finish : std_logic;
  signal tape_seed : S_ARR;
  signal tape_seed0_in, tape_seed1_in, tape_seed2_in : std_logic_vector(Picnic_S - 1 downto 0);
  signal tape_k0_out, tape_k1_out : std_logic_vector(PICNIC_S - 1 downto 0);
  type TAPE_ARR is  array(0 to 2) of std_logic_vector(R * S - 1 downto 0);
  signal tape_rand_out : TAPE_ARR;
  signal tape_round_in : integer range 0 to T;

  -- mpc
  signal mpc_start, mpc_finish : std_logic;
  signal mpc_c_out : S_ARR;
  signal mpc_ts_out : std_logic_vector(R * S - 1 downto 0);
  signal mpc_ts_in_DN, mpc_ts_in_DP : std_logic_vector(R * S - 1 downto 0);
  signal mpc_k0_in, mpc_k1_in : std_logic_vector(PICNIC_S - 1 downto 0);
  signal mpc_rand0_in, mpc_rand1_in : std_logic_vector(R * S - 1 downto 0);
  signal mpc_ET_in : integer range 0 to 2;

  -- commit
  signal comm_start, comm_finish : std_logic;
  type COMM_ARR is  array(0 to 1) of std_logic_vector(DIGEST_L - 1 downto 0);
  signal comm_out : COMM_ARR;

  -- h3
  signal h3_start, h3_valid, h3_ready : std_logic;
  signal h3_block : std_logic_vector(PICNIC_S - 1 downto 0);
  signal h3_chal_out : std_logic_vector(2 * T - 1 downto 0);

  -- ififo
  signal ififo_valid_out, ififo_ready_data_in, ififo_init : std_logic;
  signal ififo_ready_unaligned_in, ififo_skip, ififo_fin : std_logic;
  signal ififo_valid_in, ififo_ready_out : std_logic;
  signal ififo_data_in, ififo_out : std_logic_vector(PDI_WIDTH - 1 downto 0);
  signal ififo_unaligned_out : std_logic_vector(UNALIGNED_WIDTH - 1 downto 0);
  signal ififo_init_data : std_logic_vector(PDI_WIDTH - INIT_WIDTH - 1 downto 0);
  signal ififo_sig_len_out : integer range 0 to MAX_SIG;
  signal ififo_init_len : integer range 0 to L5_BYTES_PER_SEG;

  -- constants
  constant SIG_INS : integer := (CHAL_ROUND / PDI_WIDTH);

  -- state machine
  type states is (init, read_pub_c0, read_pub_c1, read_pub_p0, read_pub_p1,
    inst_ver, read_msg, picnic_in_header, picnic_in_chal, picnic_in_chal_last,
    picnic_in_salt0, picnic_in_salt1,
    picnic_ififo_commit, picnic_ififo_trans, picnic_ififo_trans_last,
    picnic_ififo_seed0, picnic_ififo_seed1, picnic_ififo_seed2,
    picnic_ififo_seed3, picnic_ififo_ishare0, picnic_ififo_ishare1,
    picnic_finish_read_reject, picnic_reject, picnic_finish_read_reject_fifo,
    picnic_verify_start, picnic_verify_tapes_start,
    picnic_verify_mpc_ts_bram, picnic_verify_mpc_ts_bram_last,
    picnic_verify_tapes_finish, picnic_verify_mpc_start,
    picnic_verify_mpc_finish_commit, picnic_verify_commit_finish,
    picnic_verify_commit_bram, picnic_verify_h3_oshare,
    picnic_verify_h3_commit0, picnic_verify_h3_commit1,
    picnic_verify_h3_pk_C, picnic_verify_h3_pk_p, picnic_verify_h3_salt,
    picnic_verify_h3_msg, picnic_verify_chal_fin,
    out_message_head, out_message, picnic_success, picnic_failure);
  signal State_DN, State_DP : states;

  -- registers
  signal Challenge_DP, Challenge_DN : std_logic_vector(2 * T - 1 downto 0);
  signal Cur_Len_DP, Cur_Len_DN : integer range 0 to MAX_SIG;
  signal Read_Len_DP, Read_Len_DN : integer range 0 to MAX_SIG;
  signal PC_DN, PC_DP : std_logic_vector(PICNIC_S - 1 downto 0);
  signal PP_DN, PP_DP : std_logic_vector(PICNIC_S - 1 downto 0);
  signal MSG_DN, MSG_DP : std_logic_vector(MSG_LEN - 1 downto 0);
  signal Verified_SN, Verified_SP : std_logic;
  signal View_iShare_DN, View_iShare_DP : std_logic_vector(PICNIC_S - 1 downto 0);
  signal ET_DN, ET_DP : integer range 0 to 3;
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

  component tapes is
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

  component lowmc_mpc is
    port(
      -- Clock and Reset
      signal Clk_CI   : in std_logic;
      signal Rst_RI   : in std_logic;
      -- Input signals
      signal Plain_DI  : in std_logic_vector(N - 1 downto 0);
      signal Key_R0_DI : in std_logic_vector(K - 1 downto 0);
      signal Key_R1_DI : in std_logic_vector(K - 1 downto 0);
      signal Rand_0_DI : in std_logic_vector(R * S - 1 downto 0);
      signal Rand_1_DI : in std_logic_vector(R * S - 1 downto 0);
      signal Start_SI  : in std_logic;
      signal ET        : in integer range 0 to 2;
      signal TS_1_DI   : in std_logic_vector(R * S - 1 downto 0);
      -- Output signals
      signal Finish_SO : out std_logic;
      signal Cipher_0_DO : out std_logic_vector(N - 1 downto 0);
      signal Cipher_1_DO : out std_logic_vector(N - 1 downto 0);
      signal TS_0_DO : out std_logic_vector(R * S - 1 downto 0)
    );
  end component;

  component commit is
    port(
      -- Clock and Reset
      signal Clk_CI      : in std_logic;
      signal Rst_RI      : in std_logic;
      -- Input signals
      signal Start_SI    : in std_logic;
      signal Seed_0_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Seed_1_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
      signal Key_R0_DI   : in std_logic_vector(K - 1 downto 0);
      signal Key_R1_DI   : in std_logic_vector(K - 1 downto 0);
      signal TS_0_DI     : in std_logic_vector(R * S - 1 downto 0);
      signal TS_1_DI     : in std_logic_vector(R * S - 1 downto 0);
      signal Cipher_0_DI : in std_logic_vector(N - 1 downto 0);
      signal Cipher_1_DI : in std_logic_vector(N - 1 downto 0);
      -- Output signals
      signal Finish_SO   : out std_logic;
      signal Commit_0_DO : out std_logic_vector(DIGEST_L - 1 downto 0);
      signal Commit_1_DO : out std_logic_vector(DIGEST_L - 1 downto 0)
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

  component input_fifo
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
  end component;

begin

  -- -- BRAM for the seed0, seed1
  SEED_BRAM_GEN : for i in 0 to 1 generate
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
    wea => seed_wea(i),
    web => seed_web(i),
    ena => '1',
    enb => '1',
    douta => seed_douta(i),
    doutb => seed_doutb(i)
  );
  end generate SEED_BRAM_GEN;

  -- -- BRAM for the view_ishare
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
    dina => view_i_dina,
    dinb => view_i_dinb,
    wea => view_i_wea,
    web => view_i_web,
    ena => '1',
    enb => '1',
    douta => view_i_douta,
    doutb => view_i_doutb
  );

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

  -- -- BRAM for the view_ts
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
    dina => view_ts_dina,
    dinb => view_ts_dinb,
    wea => view_ts_wea,
    web => view_ts_web,
    ena => '1',
    enb => '1',
    douta => view_ts_douta,
    doutb => view_ts_doutb
  );

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
      wea => comm_wea(i),
      web => comm_web(i),
      ena => '1',
      enb => '1',
      douta => comm_douta(i),
      doutb => comm_doutb(i)
    );
  end generate COMM_BRAM_GEN;

  -- calculates the tapes for mpc
  TAPE : tapes
  port map (
    Clk_CI    => clk,
    Rst_RI    => rst,
    Start_SI  => tape_start,
    Seed_0_DI => tape_seed0_in,
    Seed_1_DI => tape_seed1_in,
    Seed_2_DI => tape_seed2_in,
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
    Key_R0_DI   => mpc_k0_in,
    Key_R1_DI   => mpc_k1_in,
    Rand_0_DI   => mpc_rand0_in,
    Rand_1_DI   => mpc_rand1_in,
    Start_SI    => mpc_start,
    ET          => mpc_ET_in,
    TS_1_DI     => mpc_ts_in_DP,
    Finish_SO   => mpc_finish,
    Cipher_0_DO => mpc_c_out(0),
    Cipher_1_DO => mpc_c_out(1),
    TS_0_DO     => mpc_ts_out
  );

  COMM : commit
  port map (
    Clk_CI      => clk,
    Rst_RI      => rst,
    Start_SI    => comm_start,
    Seed_0_DI   => tape_seed(0),
    Seed_1_DI   => tape_seed(1),
    Key_R0_DI   => mpc_k0_in,
    Key_R1_DI   => mpc_k1_in,
    TS_0_DI     => mpc_ts_out,
    TS_1_DI     => mpc_ts_in_DP,
    Cipher_0_DI => mpc_c_out(0),
    Cipher_1_DI => mpc_c_out(1),
    Finish_SO   => comm_finish,
    Commit_0_DO => comm_out(0),
    Commit_1_DO => comm_out(1)
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
    Sig_Len_DO  => open
  );

  IFIFO : input_fifo
  port map (
    clk                => clk,
    rst                => rst,
    Init_DI            => ififo_init_data,
    Init_SI            => ififo_init,
    Init_Len_DI        => ififo_init_len,
    Data_DI            => ififo_data_in,
    Valid_SI           => ififo_valid_in,
    Ready_SO           => ififo_ready_out,
    Data_DO            => ififo_out,
    Ready_Data_SI      => ififo_ready_data_in,
    Unaligned_DO       => ififo_unaligned_out,
    Ready_Unaligned_SI => ififo_ready_unaligned_in,
    Valid_SO           => ififo_valid_out,
    Sig_Len_DO         => ififo_sig_len_out,
    Fin_SO             => ififo_fin,
    Skip_SO            => ififo_skip
  );

  -- commit inputs
  TAP_GEN : for i in 0 to 1 generate
    tape_seed(i) <= seed_douta(i) & seed_doutb(i);
  end generate TAP_GEN;

  -- output logic
  process (State_DP, pdi_valid, pdi_data, Counter_DP, PC_DP, PP_DP, MSG_DP, pdo_ready, Counter_Trans_DP, Challenge_DP, Verified_SP, ififo_ready_out, ififo_valid_out, Cur_Len_DP, ififo_skip, view_ts_douta, view_ts_doutb, mpc_ts_in_DP, view_i_douta, view_i_doutb, mpc_finish, comm_finish, h3_chal_out, h3_ready, mpc_c_out, ififo_out, ififo_unaligned_out, tape_k0_out, tape_k1_out, comm_out, view_o_douta, view_o_doutb, comm_douta, comm_doutb, seed_douta, seed_doutb, Read_len_DP, View_iShare_DP, ET_DP, tape_finish, tape_rand_out, Salt_DP)

    variable ET_VEC : std_logic_vector(1 downto 0);
    variable ET : integer range 0 to 3;
    variable ET_inc : integer range 0 to 3;
    variable C_INDEX : integer range 0 to 3;
    variable mpc_c_out_2 : std_logic_vector(PICNIC_S - 1 downto 0);
  begin
    -- default
    seed_addra <= (others => '0');
    seed_addrb <= (others => '0');
    seed_dina <= (others => (others => '0'));
    seed_dinb <= (others => (others => '0'));
    seed_wea <= "00";
    seed_web <= "00";

    view_i_addra <= (others => '0');
    view_i_addrb <= (others => '0');
    view_i_dina <= (others => '0');
    view_i_dinb <= (others => '0');
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
    view_ts_dina <= (others => '0');
    view_ts_dinb <= (others => '0');
    view_ts_wea <= '0';
    view_ts_web <= '0';

    comm_addra <= (others => '0');
    comm_addrb <= (others => '0');
    comm_dina <= (others => (others => '0'));
    comm_dinb <= (others => (others => '0'));
    comm_wea <= "000";
    comm_web <= "000";

    ififo_valid_in <= '0';
    ififo_ready_data_in <= '0';
    ififo_ready_unaligned_in <= '0';
    ififo_init <= '0';
    ififo_data_in <= (others => '0');
    ififo_init_data <= (others => '0');
    ififo_init_len <= 0;

    pdi_ready <= '0';
    Counter_DN <= Counter_DP;
    Counter_Trans_DN <= Counter_Trans_DP;
    PC_DN <= PC_DP;
    PP_DN <= PP_DP;
    MSG_DN <= MSG_DP;
    status_ready <= '0';
    pdo_valid <= '0';
    pdo_data <= (others => '0');
    pdo_last <= '0';
    Challenge_DN <= Challenge_DP;
    Cur_Len_DN <= Cur_Len_DP;
    Read_len_DN <= Read_len_DP;
    Verified_SN <= Verified_SP;
    View_iShare_DN <= View_iShare_DP;
    tape_start <= '0';
    mpc_ts_in_DN <= mpc_ts_in_DP;
    mpc_start <= '0';
    mpc_k0_in <= (others => '0');
    mpc_k1_in <= (others => '0');
    mpc_rand0_in <= (others => '0');
    mpc_rand1_in <= (others => '0');
    h3_block <= (others => '0');
    h3_start <= '0';
    h3_valid <= '0';
    mpc_c_out_2 := mpc_c_out(0) xor mpc_c_out(1) xor PC_DP;
    mpc_ET_in <= 0;
    ET_DN <= ET_DP;
    comm_start <= '0';
    tape_seed0_in <= (others => '0');
    tape_seed1_in <= (others => '0');
    tape_seed2_in <= (others => '0');
    tape_round_in <= 0;
    Salt_DN <= Salt_DP;

    case State_DP is
      when init =>
        pdi_ready <= '1';
      when read_pub_c0 =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          PC_DN(PICNIC_S - 1 downto PICNIC_S - PDI_WIDTH) <= pdi_data;
        end if;
      when read_pub_c1 =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          PC_DN(PICNIC_S - PDI_WIDTH - 1 downto 0) <= pdi_data;
        end if;
      when read_pub_p0 =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          PP_DN(PICNIC_S - 1 downto PICNIC_S - PDI_WIDTH) <= pdi_data;
        end if;
      when read_pub_p1 =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          PP_DN(PICNIC_S - PDI_WIDTH - 1 downto 0) <= pdi_data;
        end if;
      when inst_ver =>
        Verified_SN <= '1';
        pdi_ready <= '1';
        Counter_DN <= 0;
      when read_msg =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          Counter_DN <= Counter_DP + 1;
          MSG_DN(MSG_LEN - 1 downto PDI_WIDTH) <= MSG_DP(MSG_LEN - PDI_WIDTH - 1 downto 0);
          MSG_DN(PDI_WIDTH - 1 downto 0) <= pdi_data;
        end if;
      when picnic_in_header =>
        pdi_ready <= '1';
        ififo_init_len <= to_integer(unsigned(pdi_data(111 downto 96)));
        Cur_Len_DN <= 0;
        Read_len_DN <= 0;
        Counter_DN <= 0;
        ififo_init <= '1'; -- gets the fifo into the init state
      when picnic_in_chal =>
        pdi_ready <= '1';
        if pdi_valid = '1' then
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
          Counter_DN <= Counter_DP + 1;
          Challenge_DN(2 * T - 1 - Counter_DP * PDI_WIDTH downto 2 * T - Counter_DP * PDI_WIDTH - PDI_WIDTH) <= pdi_data;
        end if;
      when picnic_in_chal_last =>
        pdi_ready <= '1';
        Counter_DN <= 0;
        Counter_Trans_DN <= 0;
        Challenge_DN(2 * T - SIG_INS * PDI_WIDTH - 1 downto 0) <= pdi_data(PDI_WIDTH - 1 downto PDI_WIDTH - INIT_WIDTH + (CHAL_ROUND - 2 * T));
        if pdi_valid = '1' and pdi_data(PDI_WIDTH - INIT_WIDTH + (CHAL_ROUND - 2 * T) - 1 downto PDI_WIDTH - INIT_WIDTH) /= CHAL_PAD then
          -- challenge pad has to be zero
          Verified_SN <= '0';
        end if;
        ififo_init_data <= pdi_data(PDI_WIDTH - INIT_WIDTH - 1 downto 0);
        ififo_valid_in <= pdi_valid;
        Cur_Len_DN <= CHAL_ROUND_BYTE;
        if pdi_valid = '1' then
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_in_salt0 =>
        Salt_DN(SALT_LEN - 1 downto PDI_WIDTH) <= ififo_out;
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_in_salt1 =>
        Salt_DN(PDI_WIDTH - 1 downto 0) <= ififo_out;
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
        -- ET
        ET_VEC := Challenge_DP(2 * T - 2) & Challenge_DP(2 * T - 1);
        ET := to_integer(unsigned(ET_VEC));
        ET_DN <= ET;
      when picnic_ififo_commit =>
        -- ET
        case ET_DP is
          when 0 =>
            C_INDEX := 2;
          when 1 =>
            C_INDEX := 0;
          when 2 =>
            C_INDEX := 1;
          when others =>
            C_INDEX := 0; -- does not matter
            Verified_SN <= '0'; -- reject if "11"
        end case;
        -- store in bram
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + Counter_Trans_DP, COMMIT_ADDR_WIDTH));
        comm_wea(C_INDEX) <= '1';
        comm_dina(C_INDEX) <= ififo_out;
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
          if Counter_Trans_DP >= 3 then
            Counter_Trans_DN <= 0;
          else
            Counter_Trans_DN <= Counter_Trans_DP + 1;
          end if;
        end if;
      when picnic_ififo_trans =>
        -- store in bram
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 1, VIEW_TS_ADDR_WIDTH));
        view_ts_wea <= '1';
        view_ts_web <= '1';
        view_ts_dina <= ififo_out(PDI_WIDTH - 1 downto PDI_WIDTH - VIEW_TS_DATA_WIDTH);
        view_ts_dinb <= ififo_out(PDI_WIDTH - VIEW_TS_DATA_WIDTH - 1 downto 0);
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Counter_Trans_DN <= Counter_Trans_DP + 2;
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_ififo_trans_last =>
        -- store in bram
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 1, VIEW_TS_ADDR_WIDTH));
        view_ts_wea <= '1';
        view_ts_web <= '1';
        view_ts_dina <= ififo_unaligned_out(RS_LAST_SEG + VIEW_TS_DATA_WIDTH - 1 downto RS_LAST_SEG);
        view_ts_dinb <= ififo_unaligned_out(RS_LAST_SEG - 1 downto 0) & RS_PAD_VER;
        if ififo_valid_out = '1' and ififo_unaligned_out(3 downto 0) /= "0000" then
          -- TS_PAD has to be 0!
          Verified_SN <= '0';
        end if;
        -- also store first seed part in case of skip
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_dina(0) <= ififo_out;
        seed_wea <= "01";
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_Unaligned_in <= '1';
        ififo_ready_data_in <= '1'; -- try to extract both
        if ififo_valid_out = '1' and ififo_skip = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8 + UNALIGNED_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        elsif ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + UNALIGNED_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_ififo_seed0 =>
        -- store first seed part
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_dina(0) <= ififo_out;
        seed_wea <= "01";
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_ififo_seed1 =>
        -- store seed in bram
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        seed_dina(0) <= ififo_out;
        seed_wea <= "01";
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_ififo_seed2 =>
        -- store first seed part
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_dina(1) <= ififo_out;
        seed_wea <= "10";
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;

      when picnic_ififo_seed3 =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        seed_dina(1) <= ififo_out;
        seed_wea <= "10";
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        -- next already?
        if ififo_valid_out = '1' and ET_DP = 0 then
          Challenge_DN <= Challenge_DP(2 * T - 3 downto 0) & Challenge_DP(2 * T - 1 downto 2 * T - 2);
          ET_VEC := Challenge_DP(2 * T - 4) & Challenge_DP(2 * T - 3);
          ET := to_integer(unsigned(ET_VEC));
          ET_DN <= ET;
          if Counter_DP >= T - 1 then
            Counter_DN <= 0;
          else
            Counter_DN <= Counter_DP + 1;
          end if;
          Counter_Trans_DN <= 0;
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        elsif ififo_valid_out = '1' then
          Counter_Trans_DN <= 0;
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_ififo_ishare0 =>
        -- store ishare in bram
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        view_i_wea <= '1';
        view_i_web <= '1';
        view_i_dina <= ififo_out(PDI_WIDTH - 1 downto PDI_WIDTH - VIEW_I_DATA_WIDTH);
        view_i_dinb <= ififo_out(VIEW_I_DATA_WIDTH - 1 downto 0);
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_ififo_ishare1 =>
        -- store ishare in bram
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, VIEW_I_ADDR_WIDTH));
        view_i_wea <= '1';
        view_i_web <= '1';
        view_i_dina <= ififo_out(PDI_WIDTH - 1 downto PDI_WIDTH - VIEW_I_DATA_WIDTH);
        view_i_dinb <= ififo_out(VIEW_I_DATA_WIDTH - 1 downto 0);
        -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        -- next already?
        if ififo_valid_out = '1' then
          Challenge_DN <= Challenge_DP(2 * T - 3 downto 0) & Challenge_DP(2 * T - 1 downto 2 * T - 2);
          ET_VEC := Challenge_DP(2 * T - 4) & Challenge_DP(2 * T - 3);
          ET := to_integer(unsigned(ET_VEC));
          ET_DN <= ET;
          if Counter_DP >= T - 1 then
            Counter_DN <= 0;
          else
            Counter_DN <= Counter_DP + 1;
          end if;
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_finish_read_reject =>
        Verified_SN <= '0';
        if pdi_valid = '1' then
          pdi_ready <= '1';
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_finish_read_reject_fifo =>
        Verified_SN <= '0';
         -- fifo_communication
        ififo_data_in <= pdi_data;
        ififo_valid_in <= pdi_valid;
        pdi_ready <= ififo_ready_out;
        ififo_ready_data_in <= '1';
        if ififo_valid_out = '1' then
          Cur_Len_DN <= Cur_Len_DP + PDI_WIDTH / 8;
          Read_len_DN <= Read_len_DP + PDI_WIDTH / 8;
        end if;
      when picnic_reject =>
        Verified_SN <= '0'; -- reject
      when picnic_verify_start =>
        -- prepare addresses for bram
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
      when picnic_verify_tapes_start =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        tape_round_in <= Counter_DP;
        tape_start <= '1';
        -- ET
        Challenge_DN <= Challenge_DP(2 * T - 3 downto 0) & Challenge_DP(2 * T - 1 downto 2 * T - 2);
        ET_VEC := Challenge_DP(2 * T - 2) & Challenge_DP(2 * T - 1);
        ET := to_integer(unsigned(ET_VEC));
        ET_DN <= ET;
        case ET is
          when 0 =>
            tape_seed0_in <= seed_douta(0) & seed_doutb(0);
            tape_seed1_in <= seed_douta(1) & seed_doutb(1);
          when 1 =>
            tape_seed1_in <= seed_douta(0) & seed_doutb(0);
            tape_seed2_in <= seed_douta(1) & seed_doutb(1);
          when 2 =>
            tape_seed2_in <= seed_douta(0) & seed_doutb(0);
            tape_seed0_in <= seed_douta(1) & seed_doutb(1);
          when others =>
        end case;
        -- prepare transcript
        Counter_Trans_DN <= 0;
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + 1, VIEW_TS_ADDR_WIDTH));
        -- prepare ishare
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP , VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
      when picnic_verify_mpc_ts_bram =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        tape_round_in <= Counter_DP;
        -- ET
        case ET_DP is
          when 0 =>
            tape_seed0_in <= seed_douta(0) & seed_doutb(0);
            tape_seed1_in <= seed_douta(1) & seed_doutb(1);
          when 1 =>
            tape_seed1_in <= seed_douta(0) & seed_doutb(0);
            tape_seed2_in <= seed_douta(1) & seed_doutb(1);
          when 2 =>
            tape_seed2_in <= seed_douta(0) & seed_doutb(0);
            tape_seed0_in <= seed_douta(1) & seed_doutb(1);
          when others =>
         end case;
        -- store ts
        mpc_ts_in_DN(R * S - Counter_Trans_DP * VIEW_TS_DATA_WIDTH - 1 downto R * S - Counter_Trans_DP * VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH - VIEW_TS_DATA_WIDTH) <= view_ts_douta & view_ts_doutb;
        -- next ts
        view_ts_addra <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 2, VIEW_TS_ADDR_WIDTH));
        view_ts_addrb <= std_logic_vector(to_unsigned(Counter_DP * VIEW_ENTRIE_PER_TS + Counter_Trans_DP + 3, VIEW_TS_ADDR_WIDTH));
        Counter_Trans_DN <= Counter_Trans_DP + 2;
        -- prepare ishare
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP , VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, VIEW_I_ADDR_WIDTH));
        View_iShare_DN(PICNIC_S - 1 downto PICNIC_S - PDI_WIDTH) <= view_i_douta & view_i_doutb;
      when picnic_verify_mpc_ts_bram_last =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        tape_round_in <= Counter_DP;
        -- store ts
        mpc_ts_in_DN(RS_LAST_SEG_UNPAD + VIEW_TS_DATA_WIDTH - 1 downto 0) <= view_ts_douta & view_ts_doutb(VIEW_TS_DATA_WIDTH - 1 downto VIEW_TS_DATA_WIDTH - RS_LAST_SEG_UNPAD);
        -- prepare ishare
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, VIEW_I_ADDR_WIDTH));
      when picnic_verify_tapes_finish =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        tape_round_in <= Counter_DP;
        -- prepare ishare
        view_i_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, VIEW_I_ADDR_WIDTH));
        view_i_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, VIEW_I_ADDR_WIDTH));
        View_iShare_DN(PDI_WIDTH - 1 downto 0) <= view_i_douta & view_i_doutb;
      when picnic_verify_mpc_start =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        -- ET
        case ET_DP is
          when 0 =>
            mpc_k0_in <= tape_k0_out;
            mpc_k1_in <= tape_k1_out;
            mpc_rand0_in <= tape_rand_out(0);
            mpc_rand1_in <= tape_rand_out(1);
          when 1 =>
            mpc_k0_in <= tape_k1_out;
            mpc_k1_in <= View_iShare_DP;
            mpc_rand0_in <= tape_rand_out(1);
            mpc_rand1_in <= tape_rand_out(2);
          when 2 =>
            mpc_k0_in <= View_iShare_DP;
            mpc_k1_in <= tape_k0_out;
            mpc_rand0_in <= tape_rand_out(2);
            mpc_rand1_in <= tape_rand_out(0);
          when others =>
        end case;
        mpc_ET_in <= ET_DP;
        mpc_start <= '1';
      when picnic_verify_mpc_finish_commit =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        -- ET
        case ET_DP is
          when 0 =>
            mpc_k0_in <= tape_k0_out;
            mpc_k1_in <= tape_k1_out;
            mpc_rand0_in <= tape_rand_out(0);
            mpc_rand1_in <= tape_rand_out(1);
            ET_inc := 1;
            C_index := 2;
          when 1 =>
            mpc_k0_in <= tape_k1_out;
            mpc_k1_in <= View_iShare_DP;
            mpc_rand0_in <= tape_rand_out(1);
            mpc_rand1_in <= tape_rand_out(2);
            ET_inc := 2;
            C_index := 0;
          when 2 =>
            mpc_k0_in <= View_iShare_DP;
            mpc_k1_in <= tape_k0_out;
            mpc_rand0_in <= tape_rand_out(2);
            mpc_rand1_in <= tape_rand_out(0);
            ET_inc := 0;
            C_index := 1;
          when others =>
            ET_inc := 1;
            C_index := 2;
        end case;
        mpc_ET_in <= ET_DP;
        if mpc_finish = '1' then
          -- store viw_oshare in BRAM
          view_o_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, VIEW_O_ADDR_WIDTH));
          view_o_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, VIEW_O_ADDR_WIDTH));
          -- share 0
          view_o_dina(ET_DP) <= mpc_c_out(0)(PICNIC_S - 1 downto PICNIC_S - VIEW_O_DATA_WIDTH);
          view_o_dinb(ET_DP) <= mpc_c_out(0)(PICNIC_S - VIEW_O_DATA_WIDTH - 1 downto 0);
          -- share 1
          view_o_dina(ET_inc) <= mpc_c_out(1)(PICNIC_S - 1 downto PICNIC_S - VIEW_O_DATA_WIDTH);
          view_o_dinb(ET_inc) <= mpc_c_out(1)(PICNIC_S - VIEW_O_DATA_WIDTH - 1 downto 0);
          -- share 2
          view_o_dina(C_index) <= mpc_c_out_2(PICNIC_S - 1 downto PICNIC_S - VIEW_O_DATA_WIDTH);
          view_o_dinb(C_index) <= mpc_c_out_2(PICNIC_S - VIEW_O_DATA_WIDTH - 1 downto 0);

          view_o_wea <= '1';
          view_o_web <= '1';
          comm_start <= '1';
        end if;
      when picnic_verify_commit_finish =>
        seed_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
        seed_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
        -- ET
        case ET_DP is
          when 0 =>
            mpc_k0_in <= tape_k0_out;
            mpc_k1_in <= tape_k1_out;
            ET_inc := 1;
          when 1 =>
            mpc_k0_in <= tape_k1_out;
            mpc_k1_in <= View_iShare_DP;
            ET_inc := 2;
          when 2 =>
            mpc_k0_in <= View_iShare_DP;
            mpc_k1_in <= tape_k0_out;
            ET_inc := 0;
          when others =>
            ET_inc := 1;
        end case;
        if comm_finish = '1' then
          -- store commit in BRAM
          comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, SEED_ADDR_WIDTH));
          comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, SEED_ADDR_WIDTH));
          -- c0
          comm_dina(ET_DP) <= comm_out(0)(DIGEST_L - 1 downto DIGEST_L - COMMIT_DATA_WIDTH);
          comm_dinb(ET_DP) <= comm_out(0)(DIGEST_L - COMMIT_DATA_WIDTH - 1 downto DIGEST_L - COMMIT_DATA_WIDTH - COMMIT_DATA_WIDTH);
          -- c1
          comm_dina(ET_inc) <= comm_out(1)(DIGEST_L - 1 downto DIGEST_L - COMMIT_DATA_WIDTH);
          comm_dinb(ET_inc) <= comm_out(1)(DIGEST_L - COMMIT_DATA_WIDTH - 1 downto DIGEST_L - COMMIT_DATA_WIDTH - COMMIT_DATA_WIDTH);
          comm_wea(ET_DP) <= '1';
          comm_web(ET_DP) <= '1';
          comm_wea(ET_INC) <= '1';
          comm_web(ET_INC) <= '1';
        end if;
      when picnic_verify_commit_bram =>
        -- ET
        case ET_DP is
          when 0 =>
            ET_inc := 1;
          when 1 =>
            ET_inc := 2;
          when 2 =>
            ET_inc := 0;
          when others =>
            ET_inc := 1;
        end case;
        -- store second half of commit in BRAM
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, SEED_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, SEED_ADDR_WIDTH));
        -- c0
        comm_dina(ET_DP) <= comm_out(0)(COMMIT_DATA_WIDTH + COMMIT_DATA_WIDTH - 1 downto COMMIT_DATA_WIDTH);
        comm_dinb(ET_DP) <= comm_out(0)(COMMIT_DATA_WIDTH - 1 downto 0);
        -- c1
        comm_dina(ET_inc) <= comm_out(1)(COMMIT_DATA_WIDTH + COMMIT_DATA_WIDTH - 1 downto COMMIT_DATA_WIDTH);
        comm_dinb(ET_inc) <= comm_out(1)(COMMIT_DATA_WIDTH - 1 downto 0);
        comm_wea(ET_DP) <= '1';
        comm_web(ET_DP) <= '1';
        comm_wea(ET_INC) <= '1';
        comm_web(ET_INC) <= '1';
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
      when picnic_verify_h3_oshare =>
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
      when picnic_verify_h3_commit0 =>
        comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP, COMMIT_ADDR_WIDTH));
        comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 1, COMMIT_ADDR_WIDTH));
        h3_valid <= '1';
        h3_block <= comm_douta(Counter_Trans_DP) & comm_doutb(Counter_Trans_DP);
        if h3_ready = '1' then
          comm_addra <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 2, COMMIT_ADDR_WIDTH));
          comm_addrb <= std_logic_vector(to_unsigned(Counter_DP + Counter_DP + Counter_DP + Counter_DP + 3, COMMIT_ADDR_WIDTH));
        end if;
      when picnic_verify_h3_commit1 =>
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
      when picnic_verify_h3_pk_C =>
        h3_valid <= '1';
        h3_block <= PC_DP;
      when picnic_verify_h3_pk_p =>
        Counter_DN <= 0;
        h3_valid <= '1';
        h3_block <= PP_DP;
      when picnic_verify_h3_salt =>
        h3_valid <= '1';
        h3_block <= Salt_DP;
      when picnic_verify_h3_msg =>
        h3_valid <= '1';
        h3_block <= MSG_DP(MSG_LEN - 1 downto MSG_LEN - PICNIC_S);
        if h3_ready = '1' then
          Counter_DN <= Counter_DP + 1;
          -- rotate msg
          MSG_DN(PICNIC_S - 1 downto 0) <= MSG_DP(MSG_LEN - 1 downto MSG_LEN - PICNIC_S);
          MSG_DN(MSG_LEN - 1 downto PICNIC_S) <= MSG_DP(MSG_LEN - PICNIC_S - 1 downto 0);
        end if;
      when picnic_verify_chal_fin =>
        if h3_ready = '1' and h3_chal_out /= Challenge_DP then
          -- challenge has to match!
          Verified_SN <= '0';
        end if;
      when out_message_head =>
        pdo_valid <= '1';
        pdo_last <= '1';
        pdo_data <= (L5_H_MSG & pad_96);
        Counter_DN <= 0;
      when out_message =>
        pdo_valid <= '1';
        pdo_data <= MSG_DP(MSG_LEN - 1 downto MSG_LEN - PDO_WIDTH);
        if pdo_ready = '1' then
          if Counter_DP >= 3 then
            pdo_last <= '1';
          end if;
          Counter_DN <= Counter_DP + 1;
          -- rotate msg
          MSG_DN(PDO_WIDTH - 1 downto 0) <= MSG_DP(MSG_LEN - 1 downto MSG_LEN - PDO_WIDTH);
          MSG_DN(MSG_LEN - 1 downto PDO_WIDTH) <= MSG_DP(MSG_LEN - PDO_WIDTH - 1 downto 0);
        end if;
      when picnic_success =>
        pdo_valid <='1';
        pdo_last <= '1';
        pdo_data <= S_SUCCESS & pad_112;
        status_ready <= '1';
      when picnic_failure =>
        pdo_valid <='1';
        pdo_last <= '1';
        pdo_data <= S_FAILURE & pad_112;
        status_ready <= '1';
    end case;
  end process;

  -- next state logic
  process (State_DP, pdi_valid, pdi_data, Counter_DP, pdo_ready, Verified_SP, ififo_valid_out, Counter_Trans_DP, Challenge_DP, ififo_skip, Cur_Len_DP, tape_finish, mpc_finish, comm_finish, h3_ready, Read_len_DP, ET_DP, ififo_sig_len_out, ififo_fin)
  begin
    -- default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if pdi_valid = '1' and pdi_data = I_VER & pad_112 then
          State_DN <= inst_ver;
        elsif pdi_valid = '1' and pdi_data = L5_H_PUB & pad_96 then
          State_DN <= read_pub_c0;
        end if;
      when read_pub_c0 =>
        if pdi_valid = '1' then
          State_DN <= read_pub_c1;
        end if;
      when read_pub_c1 =>
        if pdi_valid = '1' then
          State_DN <= read_pub_p0;
        end if;
      when read_pub_p0 =>
        if pdi_valid = '1' then
          State_DN <= read_pub_p1;
        end if;
      when read_pub_p1 =>
        if pdi_valid = '1' then
          State_DN <= init;
        end if;
      when inst_ver =>
        -- only support 512 bit msg for now
        if pdi_valid = '1' and pdi_data = L5_H_MSG_VER & pad_96 then
          State_DN <= read_msg;
        elsif pdi_valid = '1' then
          State_DN <= init;
        end if;
      when read_msg =>
        if pdi_valid = '1' and Counter_DP >= 3 then
          State_DN <= picnic_in_header;
        end if;
      when picnic_in_header =>
        -- too small
        if pdi_valid = '1' and pdi_data(PDO_WIDTH - 1 downto PDO_WIDTH - 8) = H_SIG & "11" then
          State_DN <= picnic_finish_read_reject;
        elsif to_integer(unsigned(pdi_data(111 downto 96))) < CHAL_ROUND_BYTE then
          State_DN <= picnic_finish_read_reject;
        elsif pdi_valid = '1' and pdi_data(PDO_WIDTH - 1 downto PDO_WIDTH - 8) = H_SIG & "00" then
          State_DN <= picnic_in_chal;
        elsif pdi_valid = '1' then
          State_DN <= picnic_reject;
        end if;
      when picnic_in_chal =>
        if pdi_valid = '1' and Counter_DP >= SIG_INS - 1 then
          State_DN <= picnic_in_chal_last;
        end if;
      when picnic_in_chal_last =>
        if pdi_valid = '1' and pdi_data(PDI_WIDTH - INIT_WIDTH + (CHAL_ROUND - 2 * T) - 1 downto PDI_WIDTH - INIT_WIDTH) /= CHAL_PAD then
          State_DN <= picnic_finish_read_reject_fifo;
        elsif pdi_valid = '1' then
          State_DN <= picnic_in_salt0;
        end if;
      when picnic_in_salt0 =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_in_salt1;
        end if;
      when picnic_in_salt1 =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_commit;
        end if;
      when picnic_ififo_commit =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' and Counter_Trans_DP >= 3 then
          State_DN <= picnic_ififo_trans;
        end if;
      when picnic_ififo_trans =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' and Counter_Trans_DP >= VIEW_ENTRIE_PER_TS - 4 then
          State_DN <= picnic_ififo_trans_last;
        end if;
      when picnic_ififo_trans_last =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' and ififo_skip = '1' then
          State_DN <= picnic_ififo_seed1;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_seed0;
        end if;
      when picnic_ififo_seed0 =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_seed1;
        end if;
      when picnic_ififo_seed1 =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_seed2;
        end if;
      when picnic_ififo_seed2 =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_seed3;
        end if;
      when picnic_ififo_seed3 =>
        if ififo_valid_out = '1' and ET_DP = 0 and Counter_DP >= T - 1 and Cur_Len_DP = ififo_sig_len_out - PDO_WIDTH / 8 then
          State_DN <= picnic_verify_start;
        elsif ififo_valid_out = '1' and ET_DP = 0 and Counter_DP >= T - 1 then
          State_DN <= picnic_finish_read_reject_fifo; -- too big
        elsif ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' and ET_DP = 0 then
          State_DN <= picnic_ififo_commit;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_ishare0;
        end if;
      when picnic_ififo_ishare0 =>
        if ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_ishare1;
        end if;
      when picnic_ififo_ishare1 =>
        if ififo_valid_out = '1' and Counter_DP >= T - 1 and Cur_Len_DP = ififo_sig_len_out - PDO_WIDTH / 8 then
          State_DN <= picnic_verify_start;
        elsif ififo_valid_out = '1' and Counter_DP >= T - 1 then
          State_DN <= picnic_finish_read_reject_fifo; -- too big
        elsif ififo_fin = '1' then
          State_DN <= picnic_reject;
        elsif ififo_valid_out = '1' then
          State_DN <= picnic_ififo_commit;
        end if;
      when picnic_finish_read_reject =>
        if Read_len_DP >= ififo_sig_len_out - PDI_WIDTH / 8 then
          State_DN <= out_message_head;
        end if;
      when picnic_finish_read_reject_fifo =>
        if ififo_fin = '1' then
          State_DN <= out_message_head;
        end if;
      when picnic_reject =>
        State_DN <= out_message_head;
      when picnic_verify_start =>
        if ififo_fin = '0' then
          State_DN <= picnic_finish_read_reject_fifo;
        elsif Verified_SP = '0' then
          State_DN <= out_message_head; -- a "11" was found
        else
          State_DN <= picnic_verify_tapes_start; -- continue with check
        end if;
      when picnic_verify_tapes_start =>
        State_DN <= picnic_verify_mpc_ts_bram;
      when picnic_verify_mpc_ts_bram =>
        if Counter_Trans_DP >= VIEW_ENTRIE_PER_TS - 4 then
          State_DN <= picnic_verify_mpc_ts_bram_last;
        end if;
      when picnic_verify_mpc_ts_bram_last =>
        State_DN <= picnic_verify_tapes_finish;
      when picnic_verify_tapes_finish =>
        if tape_finish = '1' then
          State_DN <= picnic_verify_mpc_start;
        end if;
      when picnic_verify_mpc_start =>
        if mpc_finish = '1' then
          State_DN <= picnic_verify_mpc_finish_commit;
        end if;
      when picnic_verify_mpc_finish_commit =>
        if mpc_finish = '1' then
          State_DN <= picnic_verify_commit_finish;
        end if;
      when picnic_verify_commit_finish =>
        if comm_finish = '1' then
          State_DN <= picnic_verify_commit_bram;
        end if;
      when picnic_verify_commit_bram =>
        if Counter_DP >= T - 1 then
          State_DN <= picnic_verify_h3_oshare;
        else
          State_DN <= picnic_verify_start;
        end if;
      when picnic_verify_h3_oshare =>
        if h3_ready = '1' and Counter_DP >= T - 1 and Counter_Trans_DP >= 2 then
          State_DN <= picnic_verify_h3_commit0;
        end if;
      when picnic_verify_h3_commit0 =>
        if h3_ready = '1' then
          State_DN <= picnic_verify_h3_commit1;
        end if;
      when picnic_verify_h3_commit1 =>
        if h3_ready = '1' and Counter_DP >= T - 1 and Counter_Trans_DP >= 2 then
          State_DN <= picnic_verify_h3_pk_C;
        elsif h3_ready = '1' then
          State_DN <= picnic_verify_h3_commit0;
        end if;
      when picnic_verify_h3_pk_C =>
        if h3_ready = '1' then
          State_DN <= picnic_verify_h3_pk_p;
        end if;
      when picnic_verify_h3_pk_p =>
        if h3_ready = '1' then
          State_DN <= picnic_verify_h3_salt;
        end if;
      when picnic_verify_h3_salt =>
        if h3_ready = '1' then
          State_DN <= picnic_verify_h3_msg;
        end if;
      when picnic_verify_h3_msg =>
        if h3_ready = '1' and Counter_DP >= 1 then
          State_DN <= picnic_verify_chal_fin;
        end if;
      when picnic_verify_chal_fin =>
        if h3_ready = '1' then
          State_DN <= out_message_head;
        end if;
      when out_message_head =>
        if pdo_ready = '1' then
          State_DN <= out_message;
        end if;
      when out_message =>
        if pdo_ready = '1' and Counter_DP >= 3 then
          if Verified_SP = '1' then
            State_DN <= picnic_success;
          else
            State_DN <= picnic_Failure;
          end if;
        end if;
      when picnic_success =>
        if pdo_ready = '1' then
          State_DN <= init;
        end if;
      when picnic_failure =>
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
        PC_DP              <= (others => '0');
        PP_DP              <= (others => '0');
        MSG_DP             <= (others => '0');
        Counter_DP         <= 0;
        Counter_Trans_DP   <= 0;
        Challenge_DP       <= (others => '0');
        Cur_Len_DP         <= 0;
        Read_len_DP        <= 0;
        Verified_SP        <= '0';
        mpc_ts_in_DP       <= (others => '0');
        View_iShare_DP     <= (others => '0');
        ET_DP              <= 0;
        Salt_DP            <= (others => '0');
      else
        State_DP           <= State_DN;
        Counter_DP         <= Counter_DN;
        PC_DP              <= PC_DN;
        PP_DP              <= PP_DN;
        MSG_DP             <= MSG_DN;
        Counter_Trans_DP   <= Counter_Trans_DN;
        Challenge_DP       <= Challenge_DN;
        Cur_Len_DP         <= Cur_Len_DN;
        Read_len_DP        <= Read_len_DN;
        Verified_SP        <= Verified_SN;
        mpc_ts_in_DP       <= mpc_ts_in_DN;
        View_iShare_DP     <= View_iShare_DN;
        ET_DP              <= ET_DN;
        Salt_DP            <= Salt_DN;
      end if;
    end if;
  end process;
end behavorial;
