--Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2018.2 (lin64) Build 2258646 Thu Jun 14 20:02:38 MDT 2018
--Date        : Mon Mar 25 10:28:04 2019
--Host        : localhost.localdomain running 64-bit Debian GNU/Linux 9.8 (stretch)
--Command     : generate_target picnic_l5_verify_pcie_top_wrapper.bd
--Design      : picnic_l5_verify_pcie_top_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity picnic_l5_verify_pcie_top_wrapper is
  port (
    pci_express_x8_rxn : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_rxp : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txn : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txp : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pcie_perstn : in STD_LOGIC;
    pcie_ref_clk_n : in STD_LOGIC;
    pcie_ref_clk_p : in STD_LOGIC
  );
end picnic_l5_verify_pcie_top_wrapper;

architecture STRUCTURE of picnic_l5_verify_pcie_top_wrapper is
  component picnic_l5_verify_pcie_top is
  port (
    pci_express_x8_rxn : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_rxp : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txn : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txp : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pcie_perstn : in STD_LOGIC;
    pcie_ref_clk_p : in STD_LOGIC;
    pcie_ref_clk_n : in STD_LOGIC
  );
  end component picnic_l5_verify_pcie_top;
begin
picnic_l5_verify_pcie_top_i: component picnic_l5_verify_pcie_top
     port map (
      pci_express_x8_rxn(7 downto 0) => pci_express_x8_rxn(7 downto 0),
      pci_express_x8_rxp(7 downto 0) => pci_express_x8_rxp(7 downto 0),
      pci_express_x8_txn(7 downto 0) => pci_express_x8_txn(7 downto 0),
      pci_express_x8_txp(7 downto 0) => pci_express_x8_txp(7 downto 0),
      pcie_perstn => pcie_perstn,
      pcie_ref_clk_n => pcie_ref_clk_n,
      pcie_ref_clk_p => pcie_ref_clk_p
    );
end STRUCTURE;
