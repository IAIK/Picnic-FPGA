--Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2018.2 (lin64) Build 2258646 Thu Jun 14 20:02:38 MDT 2018
--Date        : Sun Aug 12 22:43:51 2018
--Host        : debian running 64-bit Debian GNU/Linux 9.5 (stretch)
--Command     : generate_target lowmc_pcie_top_wrapper.bd
--Design      : lowmc_pcie_top_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity lowmc_pcie_top_wrapper is
  port (
    pci_express_x8_rxn : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_rxp : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txn : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txp : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pcie_perstn : in STD_LOGIC;
    pcie_ref_clk_n : in STD_LOGIC;
    pcie_ref_clk_p : in STD_LOGIC
  );
end lowmc_pcie_top_wrapper;

architecture STRUCTURE of lowmc_pcie_top_wrapper is
  component lowmc_pcie_top is
  port (
    pci_express_x8_rxn : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_rxp : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txn : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pci_express_x8_txp : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pcie_perstn : in STD_LOGIC;
    pcie_ref_clk_p : in STD_LOGIC;
    pcie_ref_clk_n : in STD_LOGIC
  );
  end component lowmc_pcie_top;
begin
lowmc_pcie_top_i: component lowmc_pcie_top
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
