--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  File:            pcipargen.vhd                                                                      |
--|                                                                                                    |
--|  Project:        pci32tLite                                                                        |
--|                                                                                                    |
--|  Description:     PCI Parity Generator.                                                            |
--|                                                                                                     |
--+-------------------------------------------------------------------------------------------------+
--+-----------------------------------------------------------------+
--|                                                                 |
--|  Copyright (C) 2005-2008 Peio Azkarate, peio.azkarate@gmail.com    | 
--|                                                                 |
--|  This source file may be used and distributed without             |
--|  restriction provided that this copyright statement is not        |
--|  removed from the file and that any derivative work contains    |
--|  the original copyright notice and the associated disclaimer.    |
--|                                                                  |
--|  This source file is free software; you can redistribute it     |
--|  and/or modify it under the terms of the GNU Lesser General     |
--|  Public License as published by the Free Software Foundation;   |
--|  either version 2.1 of the License, or (at your option) any     |
--|  later version.                                                 |
--|                                                                 |
--|  This source is distributed in the hope that it will be         |
--|  useful, but WITHOUT ANY WARRANTY; without even the implied     |
--|  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR        |
--|  PURPOSE.  See the GNU Lesser General Public License for more   |
--|  details.                                                       |
--|                                                                 |
--|  You should have received a copy of the GNU Lesser General      |
--|  Public License along with this source; if not, download it     |
--|  from http://www.opencores.org/lgpl.shtml                       |
--|                                                                 |
--+-----------------------------------------------------------------+ 


--+-----------------------------------------------------------------------------+
--|                                    LIBRARIES                                    |
--+-----------------------------------------------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

--+-----------------------------------------------------------------------------+
--|                                    ENTITY                                       |
--+-----------------------------------------------------------------------------+

entity pcipargen is
port (

    clk_i            : in std_logic;
    pcidatout_i        : in std_logic_vector(31 downto 0);
    cbe_i            : in std_logic_vector(3 downto 0);
    par_o            : out std_logic
    
);   
end pcipargen;


architecture rtl of pcipargen is


--+-----------------------------------------------------------------------------+
--|                                    COMPONENTS                                    |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    CONSTANTS                                      |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    SIGNALS                                       |
--+-----------------------------------------------------------------------------+

      signal d            : std_logic_vector(31 downto 0);
      signal pardat        : std_logic;
      signal parcbe        : std_logic;
      signal par            : std_logic;

begin


    d <= pcidatout_i;

    
    --+-------------------------------------------------------------------------+
    --|  building parity                                                        |
    --+-------------------------------------------------------------------------+
    
    pardat     <= d(0)  xor d(1)  xor d(2)  xor d(3)  xor d(4)  xor d(5)  xor d(6)  xor d(7)  xor 
               d(8)  xor d(9)  xor d(10) xor d(11) xor d(12) xor d(13) xor d(14) xor d(15) xor 
               d(16) xor d(17) xor d(18) xor d(19) xor d(20) xor d(21) xor d(22) xor d(23) xor 
               d(24) xor d(25) xor d(26) xor d(27) xor d(28) xor d(29) xor d(30) xor d(31);
                        
    parcbe     <= cbe_i(0) xor cbe_i(1) xor cbe_i(2) xor cbe_i(3); 
    
    par <= pardat xor parcbe;

    u1: entity work.sync port map ( clk => clk_i, d => par, q => par_o );
    
end rtl;
