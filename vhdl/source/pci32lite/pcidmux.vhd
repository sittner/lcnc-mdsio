--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  File:            pcidmux.vhd                                                                      |
--|                                                                                                    |
--|  Project:        pci32tLite                                                                        |
--|                                                                                                    |
--|  Description:     Data Multiplex wb <-> regs <-> pci                                                |
--|                    Data Multiplex D16 whisbone <-> D32 PCI.                                          |
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

entity pcidmux is
generic (
    BARS         : string := "1BARMEM";
    WBSIZE         : integer := 16;
    WBENDIAN     : string := "BIG"
);
port (

       -- General 
    clk_i           : in std_logic;
       rst_i           : in std_logic;
    --  
    d_in            : in std_logic_vector(31 downto 0);
    d_out           : out std_logic_vector(31 downto 0);
    --
    wbdatLD_i       : in std_logic;
    rdcfg_i               : in std_logic;
    cbe_i               : in std_logic_vector(3 downto 0);    
    --
    wb_dat_i        : in std_logic_vector((WBSIZE-1) downto 0);
    wb_dat_o        : out std_logic_vector((WBSIZE-1) downto 0);
    rg_dat_i        : in std_logic_vector(31 downto 0);
    rg_dat_o        : out std_logic_vector(31 downto 0)
        
);   
end pcidmux;


architecture rtl of pcidmux is


--+-----------------------------------------------------------------------------+
--|                                    COMPONENTS                                    |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    CONSTANTS                                      |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    SIGNALS                                       |
--+-----------------------------------------------------------------------------+

      signal pcidatin        : std_logic_vector(31 downto 0);
      signal pcidatout    : std_logic_vector(31 downto 0);
      signal wb_dat_is    : std_logic_vector((WBSIZE-1) downto 0);
      signal wbrgdMX        : std_logic;
      signal wbdMX        : std_logic_vector(1 downto 0);

begin

    -- Mux control signals
    wbrgdMX <= not rdcfg_i;
    wbdMX(0) <= '0' when ( cbe_i(0) = '0' or cbe_i(2) = '0' ) else '1';
    wbdMX(1) <= '0' when ( cbe_i(0) = '0' or cbe_i(1) = '0' ) else '1';

    --+-------------------------------------------------------------------------+
    --|  Load Whisbone Datain                                                    |
    --+-------------------------------------------------------------------------+
    
    WBDATLD: process( rst_i, clk_i, wbdatLD_i, wb_dat_i )
    begin

        if( rst_i = '1' ) then 
            wb_dat_is <= ( others => '1' );
        elsif( rising_edge(clk_i) ) then 
        
            if ( wbdatLD_i = '1' ) then
                wb_dat_is <= wb_dat_i;
            end if;
            
        end if;
        
    end process WBDATLD;


    --+-------------------------------------------------------------------------+
    --|  Route PCI data in toward Registers and Whisbone                        |
    --+-------------------------------------------------------------------------+
    rg_dat_o <= pcidatin;
    

    --+-------------------------------------------------------------------------+
    --|  PCI <-> WB Data route and swap                                            |
    --+-------------------------------------------------------------------------+
    --+-----------------------------------------+
    --| PCI(Little endian) <-> WB(Little endian)|
    --| WB bus 32Bits                            |
    --+-----------------------------------------+
    dat32: if (WBSIZE = 32 and WBENDIAN = "LITTLE") generate
        pcidatout(31 downto 0)  <= wb_dat_is(31 downto 0) when ( wbrgdMX = '1' ) else rg_dat_i(31 downto 0);
        wb_dat_o(31 downto 0)   <= pcidatin(31 downto 0);
    end generate;

    --+-----------------------------------------+
    --| PCI(Little endian) <-> WB(Big endian)      |
    --| WB bus 16Bits                            |
    --+-----------------------------------------+
    dat16b: if (WBSIZE = 16 and WBENDIAN = "BIG") generate
        --pcidatout(31 downto 24) <= wb_dat_is(7 downto 0) when ( wbrgdMX_i = '1' ) else rg_dat_i(31 downto 24);
        --pcidatout(23 downto 16) <= wb_dat_is(15 downto 8) when ( wbrgdMX_i = '1' ) else rg_dat_i(23 downto 16);
        --pcidatout(15 downto 8)  <= wb_dat_is(7 downto 0) when ( wbrgdMX_i = '1' ) else rg_dat_i(15 downto 8);
        --pcidatout(7 downto 0)   <= wb_dat_is(15 downto 8) when ( wbrgdMX_i = '1' ) else rg_dat_i(7 downto 0);
        --wb_dat_o(15 downto 8)   <= pcidatin(23 downto 16) when ( wbdMX_i(1) = '1' ) else pcidatin(7 downto 0);
        --wb_dat_o(7 downto 0)    <= pcidatin(31 downto 24) when ( wbdMX_i(1) = '1' ) else pcidatin(15 downto 8);
        PCIWBMUX: process(cbe_i, pcidatin, wbrgdMX, wb_dat_is, rg_dat_i)
            begin
                case cbe_i is
                    when b"1100" => 
                        wb_dat_o(7 downto 0)  <= pcidatin(7 downto 0);
                        wb_dat_o(15 downto 8) <= pcidatin(15 downto 8);
                    when b"0011" => 
                        wb_dat_o(7 downto 0)  <= pcidatin(23 downto 16);
                        wb_dat_o(15 downto 8) <= pcidatin(31 downto 24);
                    when b"1110" => 
                        wb_dat_o(7 downto 0)  <= (others => '1');
                        wb_dat_o(15 downto 8) <= pcidatin(7 downto 0);
                    when b"1101" => 
                        wb_dat_o(7 downto 0)  <= pcidatin(15 downto 8); 
                        wb_dat_o(15 downto 8) <= (others => '1'); 
                    when b"1011" => 
                        wb_dat_o(7 downto 0)  <= (others => '1');
                        wb_dat_o(15 downto 8) <= pcidatin(23 downto 16);
                    when b"0111" => 
                        wb_dat_o(7 downto 0)  <= pcidatin(31 downto 24); 
                        wb_dat_o(15 downto 8) <= (others => '1');
                    when others    => 
                        wb_dat_o(15 downto 0) <= pcidatin(15 downto 0);
                end case;

                if (wbrgdMX = '1') then
                    case cbe_i is
                        when b"1100" => 
                            pcidatout(31 downto 16) <= (others => '1');
                            pcidatout(15 downto 0) <= wb_dat_is(15 downto 0);
                        when b"0011" => 
                            pcidatout(31 downto 16) <= wb_dat_is(15 downto 0);
                            pcidatout(15 downto 0) <= (others => '1');
                        when b"1110" => 
                            pcidatout(31 downto 8) <= (others => '1');
                            pcidatout(7 downto 0) <= wb_dat_is(15 downto 8);
                        when b"1101" => 
                            pcidatout(31 downto 16) <= (others => '1');
                            pcidatout(15 downto 8) <= wb_dat_is(7 downto 0);
                            pcidatout(7 downto 0) <= (others => '1');
                        when b"1011" => 
                            pcidatout(31 downto 24) <= (others => '1');
                            pcidatout(23 downto 16) <= wb_dat_is(15 downto 8);
                            pcidatout(15 downto 0) <= (others => '1');
                        when b"0111" => 
                            pcidatout(31 downto 24) <= wb_dat_is(7 downto 0);
                            pcidatout(23 downto 0) <= (others => '1');
                        when others    => 
                            pcidatout(15 downto 0) <= wb_dat_is(15 downto 0);
                            pcidatout(31 downto 16) <= (others => '1');
                    end case;
                else
                    pcidatout(31 downto 0) <= rg_dat_i(31 downto 0);
                end if;

        end process PCIWBMUX;

    end generate;

    --+-----------------------------------------+
    --| PCI(Little endian) <-> WB(Little endian)|
    --| WB bus 16Bits                            |
    --+-----------------------------------------+
    dat16l: if (WBSIZE = 16 and WBENDIAN = "LITTLE") generate
        pcidatout(31 downto 16) <= wb_dat_is when ( wbrgdMX = '1' ) else rg_dat_i(31 downto 16);
        pcidatout(15 downto 0)  <= wb_dat_is when ( wbrgdMX = '1' ) else rg_dat_i(15 downto 0);
        wb_dat_o(15 downto 0)   <= pcidatin(31 downto 16) when ( wbdMX(1) = '1' ) else pcidatin(15 downto 0);
    end generate;

    --+-----------------------------------------+
    --| PCI(Little endian) <-> WB(Little endian)|
    --| WB bus 8Bits                            |
    --+-----------------------------------------+
    dat8l: if (WBSIZE = 8 and WBENDIAN = "LITTLE") generate
        --pcidatout(31 downto 24) <= wb_dat_is(7 downto 0);
        --pcidatout(23 downto 16) <= wb_dat_is(7 downto 0);
        --pcidatout(15 downto 8)  <= wb_dat_is(7 downto 0);
        --pcidatout(7 downto 0)   <= wb_dat_is(7 downto 0);
        pcidatout(31 downto 24) <= wb_dat_is(7 downto 0) when ( wbrgdMX = '1' ) else rg_dat_i(31 downto 24);
        pcidatout(23 downto 16) <= wb_dat_is(7 downto 0) when ( wbrgdMX = '1' ) else rg_dat_i(23 downto 16);
        pcidatout(15 downto 8)  <= wb_dat_is(7 downto 0) when ( wbrgdMX = '1' ) else rg_dat_i(15 downto 8);
        pcidatout(7 downto 0)   <= wb_dat_is(7 downto 0) when ( wbrgdMX = '1' ) else rg_dat_i(7 downto 0);
        with wbdMX select
            wb_dat_o(7 downto 0) <= pcidatin(7 downto 0)   when "00",
                                    pcidatin(15 downto 8)  when "01",
                                    pcidatin(23 downto 16) when "10",
                                    pcidatin(31 downto 24) when "11",
                                    (others => '0')        when others;
    end generate;
   
    --+-------------------------------------------------------------------------+
    --|  PCI data in/out
    --+-------------------------------------------------------------------------+
    pcidatin <= d_in;
    d_out <= pcidatout;

end rtl;
