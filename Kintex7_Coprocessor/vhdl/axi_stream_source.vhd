library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_stream_source is
  generic (
    C_M_AXIS_TDATA_WIDTH : integer := 128
  );
  port (
    -- Users to add ports here
    Data_DI : in std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
    Valid_DI : in std_logic;
    Last_SI : in std_logic;
    Ready_SO : out std_logic;
    -- User ports ends
    -- Do not modify the ports beyond this line

    -- Global ports
    M_AXIS_ACLK : in std_logic;
    --
    M_AXIS_ARESETN : in std_logic;
    -- Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted.
    M_AXIS_TVALID : out std_logic;
    -- TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
    M_AXIS_TDATA : out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
    -- TLAST indicates the boundary of a packet.
    M_AXIS_TLAST : out std_logic;
    -- TREADY indicates that the slave can accept a transfer in the current cycle.
    M_AXIS_TREADY : in std_logic
  );
end axi_stream_source;

architecture behavorial of axi_stream_source is
begin
  -- I/O Connections assignments
  M_AXIS_TVALID <= Valid_DI;
  Ready_SO <= M_AXIS_TREADY;
  M_AXIS_TLAST <= Last_SI;

  -- forward the data in reversed byte order
  REV_GEN : for i in 0 to C_M_AXIS_TDATA_WIDTH / 8 - 1 generate
    M_AXIS_TDATA((i + 1) * 8 - 1 downto i * 8) <=
          Data_DI((C_M_AXIS_TDATA_WIDTH / 8 - i) * 8 - 1
              downto (C_M_AXIS_TDATA_WIDTH / 8 - 1 - i) * 8);
  end generate REV_GEN;

end behavorial;
