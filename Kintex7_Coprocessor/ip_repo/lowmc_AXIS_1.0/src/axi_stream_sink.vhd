library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_stream_sink is
  generic (
    C_S_AXIS_TDATA_WIDTH : integer := 128
  );
  port (
    -- Users to add ports here
    Data_DO : out std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
    Valid_SO : out std_logic;
    Last_SO : out std_logic;
    Ready_SI : in std_logic;
    -- User ports ends
    -- Do not modify the ports beyond this line

    -- AXI4Stream sink: Clock
    S_AXIS_ACLK : in std_logic;
    -- AXI4Stream sink: Reset
    S_AXIS_ARESETN : in std_logic;
    -- Ready to accept data in
    S_AXIS_TREADY : out std_logic;
    -- Data in
    S_AXIS_TDATA : in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
    -- Indicates boundary of last packet
    S_AXIS_TLAST : in std_logic;
    -- Data is in valid
    S_AXIS_TVALID : in std_logic
  );
end axi_stream_sink;

architecture behavorial of axi_stream_sink is
begin
  -- ready when pcie/dma is ready to receive output
  S_AXIS_TREADY <= Ready_SI;

  -- data is valid if handshake is made
  Valid_SO <= S_AXIS_TVALID and Ready_SI;
  Last_SO <= S_AXIS_TLAST;

  -- forward the data in reversed byte order
  REV_GEN : for i in 0 to C_S_AXIS_TDATA_WIDTH / 8 - 1 generate
    Data_DO((i + 1) * 8 - 1 downto i * 8) <=
          S_AXIS_TDATA((C_S_AXIS_TDATA_WIDTH / 8 - i) * 8 - 1
              downto (C_S_AXIS_TDATA_WIDTH / 8 - 1 - i) * 8);
  end generate REV_GEN;

end behavorial;
