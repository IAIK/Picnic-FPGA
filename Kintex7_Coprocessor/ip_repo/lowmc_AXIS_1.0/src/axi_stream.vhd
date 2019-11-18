library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_stream_lowmc_v1_0 is
  generic (
    C_S00_AXIS_TDATA_WIDTH : integer := 128;
    C_M00_AXIS_TDATA_WIDTH : integer := 128
  );
  port (
    Key_DI : std_logic_vector(127 downto 0);

    -- Ports of Axi Slave Bus Interface S00_AXIS
    s00_axis_tready : out std_logic;
    s00_axis_tdata : in std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0);
    s00_axis_tlast : in std_logic;
    s00_axis_tvalid : in std_logic;
    s00_axis_aclk : in std_logic;
    s00_axis_aresetn : in std_logic;

    -- Ports of Axi Master Bus Interface M00_AXIS
    m00_axis_tvalid : out std_logic;
    m00_axis_tdata : out std_logic_vector(C_M00_AXIS_TDATA_WIDTH-1 downto 0);
    m00_axis_tlast : out std_logic;
    m00_axis_tready : in std_logic;
    m00_axis_aclk : in std_logic;
    m00_axis_aresetn : in std_logic
  );
end axi_stream_lowmc_v1_0;

architecture arch_imp of axi_stream_lowmc_v1_0 is
  signal Valid_Slave, Valid_Master : std_logic;
  signal Last_Slave, Last_Master : std_logic;
  signal Data_Slave, Data_Master : std_logic_vector(N - 1 downto 0);
  signal Ready_Master : std_logic;
  signal Last_SN, Last_SP : std_logic_vector(0 to R - 1);

  -- component declaration
  component axi_stream_sink is
    generic (
      C_S_AXIS_TDATA_WIDTH : integer := 128
    );
    port (
      Data_DO : out std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
      Valid_SO : out std_logic;
      Last_SO : out std_logic;
      Ready_SI : in std_logic;
      S_AXIS_ACLK : in std_logic;
      S_AXIS_ARESETN : in std_logic;
      S_AXIS_TREADY : out std_logic;
      S_AXIS_TDATA : in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
      S_AXIS_TLAST : in std_logic;
      S_AXIS_TVALID : in std_logic
    );
  end component axi_stream_sink;

  -- component declaration
  component lowmc_pipeline
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
  end component;

  -- component declaration
  component axi_stream_source is
    generic (
      C_M_AXIS_TDATA_WIDTH : integer := 128
    );
    port (
      Data_DI : in std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
      Valid_DI : in std_logic;
      Last_SI : in std_logic;
      Ready_SO : out std_logic;
      M_AXIS_ACLK : in std_logic;
      M_AXIS_ARESETN : in std_logic;
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA : out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
      M_AXIS_TLAST : out std_logic;
      M_AXIS_TREADY : in std_logic
    );
  end component axi_stream_source;

begin

  -- Instantiation of Axi Bus Interface S00_AXIS
  axi_stream_sink_inst : axi_stream_sink
    generic map (
      C_S_AXIS_TDATA_WIDTH => C_S00_AXIS_TDATA_WIDTH
    )
    port map (
      Data_DO => Data_Slave,
      Valid_SO => Valid_Slave,
      Last_SO => Last_Slave,
      Ready_SI => Ready_Master,
      S_AXIS_ACLK => s00_axis_aclk,
      S_AXIS_ARESETN => s00_axis_aresetn,
      S_AXIS_TREADY => s00_axis_tready,
      S_AXIS_TDATA => s00_axis_tdata,
      S_AXIS_TLAST => s00_axis_tlast,
      S_AXIS_TVALID => s00_axis_tvalid
    );

  -- Instantiation of lowMC_pipeline
  lowmc_pipeline_inst : lowmc_pipeline
    port map(
      Clk_CI    => s00_axis_aclk,
      Rst_RBI   => s00_axis_aresetn,
      Plain_DI  => Data_Slave,
      Key_DI    => Key_DI,
      Valid_SI  => Valid_Slave,
      Ready_SI  => Ready_Master,
      Cipher_DO => Data_Master,
      Valid_SO  => Valid_Master
    );

  -- Instantiation of Axi Bus Interface M00_AXIS
  axi_stream_source_inst : axi_stream_source
    generic map (
      C_M_AXIS_TDATA_WIDTH => C_M00_AXIS_TDATA_WIDTH
    )
    port map (
      Data_DI => Data_Master,
      Valid_DI => Valid_Master,
      Last_SI => Last_Master,
      Ready_SO => Ready_Master,
      M_AXIS_ACLK => m00_axis_aclk,
      M_AXIS_ARESETN => m00_axis_aresetn,
      M_AXIS_TVALID => m00_axis_tvalid,
      M_AXIS_TDATA => m00_axis_tdata,
      M_AXIS_TLAST => m00_axis_tlast,
      M_AXIS_TREADY => m00_axis_tready
  );

  Last_SN(0) <= Last_Slave;
  LAST_GEN : for i in 0 to R - 2 generate
    Last_SN(i + 1) <= Last_SP(i);
  end generate;
  Last_Master <= Last_SP(R - 1);

  -- the registers
  process (m00_axis_aclk, m00_axis_aresetn)
  begin
    if m00_axis_aresetn = '0' then               -- asynchronous reset
      Last_SP <= (others => '0');
    elsif m00_axis_aclk'event and m00_axis_aclk = '1' then  -- rising clock
      if Ready_Master = '1' then
        Last_SP <= Last_SN;
      end if;
    end if;
  end process;

end arch_imp;
