--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  File:            pcidec.vhd                                                                      |
--|                                                                                                    |
--|  Project:        pci32tLite                                                                        |
--|                                                                                                    |
--|  Description:     PCI decoder and PCI signals loader.                                                |
--|                    * LoaD signals: "ad" -> adr, cbe -> cmd.                                         |
--|                    * Decode memory and configuration space.                                         |
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

entity pcidec is
generic (
    BARS         : string := "1BARMEM"
);
port (

       -- General 
    clk_i           : in std_logic;
       rst_i           : in std_logic;
    -- pci 
    ad_i            : in std_logic_vector(31 downto 0);
    cbe_i            : in std_logic_vector(3 downto 0);
    idsel_i              : in std_logic;
    -- control
    bar0_i            : in std_logic_vector(31 downto 9);
    memEN_i            : in std_logic;
    ioEN_i            : in std_logic;
    pciadrLD_i           : in std_logic;
    adrcfg_o        : out std_logic;
    adrmem_o         : out std_logic;
    adr_o            : out std_logic_vector(24 downto 0);
    cmd_o            : out std_logic_vector(3 downto 0)
    
);   
end pcidec;


architecture rtl of pcidec is


--+-----------------------------------------------------------------------------+
--|                                    COMPONENTS                                    |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    CONSTANTS                                      |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    SIGNALS                                       |
--+-----------------------------------------------------------------------------+

      signal adr            : std_logic_vector(31 downto 0);
      signal cmd            : std_logic_vector(3 downto 0);
      signal idsel_s        : std_logic;
    signal a1            : std_logic;
    signal a0            : std_logic;

begin

    --+-------------------------------------------------------------------------+
    --|  Load PCI Signals                                                        |
    --+-------------------------------------------------------------------------+
    
    PCILD: process( rst_i, clk_i, ad_i, cbe_i, idsel_i )
    begin

        if( rst_i = '1' ) then 
            adr <= ( others => '1' );
            cmd <= ( others => '1' );
            idsel_s <= '0';
        elsif( rising_edge(clk_i) ) then 
        
            if ( pciadrLD_i = '1' ) then
        
                adr <= ad_i;
                cmd <= cbe_i;
                idsel_s <= idsel_i;
                
            end if;
        end if;
        
    end process PCILD;


    

    --+-------------------------------------------------------------------------+
    --|  Decoder                                                                |
    --+-------------------------------------------------------------------------+

    barmem_g: if (BARS="1BARMEM") generate
    adrmem_o <= '1' when (  ( memEN_i = '1' ) 
                        and ( adr(31 downto 25) = bar0_i(31 downto 25) )
                        and ( adr(1 downto 0) = "00" ) 
                        and ( cmd(3 downto 1) = "011" )  )
                    else '0';
    end generate;
    
    bario_g: if (BARS="1BARIO") generate
    adrmem_o <= '1' when (  ( ioEN_i = '1' ) 
                        and ( adr(31 downto 16) = "0000000000000000")
                        and ( adr(15 downto 9) = bar0_i(15 downto 9) )
                        and ( cmd(3 downto 1) = "001" )  )
                    else '0';
    end generate;
                
    adrcfg_o <= '1' when (  ( idsel_s = '1' ) 
                        and ( adr(1 downto 0) = "00" ) 
                        and ( cmd(3 downto 1) = "101" )  )
                    else '0';
    

    --+-------------------------------------------------------------------------+
    --|  Adresses WB A(1)/A(0)                                                    |
    --+-------------------------------------------------------------------------+
    barmema1a0_g: if (BARS="1BARMEM") generate
    a1 <= cbe_i(1) and cbe_i(0);
    a0 <= cbe_i(2) and cbe_i(0);
    end generate;

    barioa1a0_g: if (BARS="1BARIO") generate
    a1 <= adr(1);
    a0 <= adr(0);
    end generate;


    --+-------------------------------------------------------------------------+
    --|  Other outs                                                                |
    --+-------------------------------------------------------------------------+

    adr_o <= adr(24 downto 2) & a1 & a0;
    cmd_o <= cmd;


end rtl;
