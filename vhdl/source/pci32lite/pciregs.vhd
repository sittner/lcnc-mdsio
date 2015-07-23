--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  File:            pciregs.vhd                                                                      |
--|                                                                                                    |
--|  Project:        pci32tLite                                                                        |
--|                                                                                                    |
--|  Description:     PCI    Registers                                                                    |
--|                                                                                                     |
--|    +-----------------------------------------------------------------------+                        |
--|    |    PCI CONFIGURATION SPACE REGISTERS                                    |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                    |
--| +-------------------------------------------------------------------+                              |
--| |   REGISTER     |     adr(7..2)    |    offset    | Byte Enable    | Size    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  VENDORID        |  000000 (r)     |     00    |        0/1        |    2    |                             |
--| +-------------------------------------------------------------------+                           |
--| |  DERVICEID    |  000000 (r)    |       02    |        2/3        |   2    |                            |
--| +-------------------------------------------------------------------+                            |
--| |  CMD            |  000001 (r/w)    |       04    |       0/1        |    2    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  ST            |  000001 (r/w*)|       06    |       2/3        |   2    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  REVISIONID    |  000010 (r)    |       08    |        0        |    1    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  CLASSCODE    |  000010 (r)    |       09    |      1/2/3        |   3    |                             |
--| +-------------------------------------------------------------------+                           |
--| |  HEADERTYPE    |  000011 (r)    |       0E    |        2        |    1    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  BAR0            |  000100 (r/w)    |       10    |     0/1/2/3    |    4    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  SUBSYSTEMID    |  001011 (r)     |     2C    |        0/1        |    2    |                             |
--| +-------------------------------------------------------------------+                           |
--| |  SUBSYSTEMVID    |  001011 (r)    |       2E    |        0/1        |   2    |                            |
--| +-------------------------------------------------------------------+                            |
--| |  INTLINE      |  001111 (r/w)    |       3C    |        0        |    1    |                            |
--| +-------------------------------------------------------------------+                           |
--| |  INTPIN        |  001111 (r)    |       3D    |        1        |    1    |                            |
--| +-------------------------------------------------------------------+                           |
--|  (w*) Reseteable                                                                                |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | VENDORID (r) Vendor ID register                |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Identifies manufacturer of device.                                      |                        |
--| | VENDORIDr : vendorID (generic)                                        |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | DEVICEID (r) Device ID register                  |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Identifies the device.                                                |                        |
--| | DEVICEIDr : deviceID (generic)                                        |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | CMD (r/w) CoMmanD register                     |                                                |
--|    +-----------------------------------------------+------------------------------+                |
--|    |    0    |    0   |   0    |    0   |   0    |    0    |     0     | SERRENb  | (15-8)            |
--|    +------------------------------------------------------------------------------+                |
--|    |    0    | PERRENb|   0     |     0     |     0       |    0    |MEMSPACEENb|IOSPACEENb|  (7-0)         |
--|    +------------------------------------------------------------------------------+                |
--|    | SERRENb : System ERRor ENable (1 = Enabled)                            |                        |
--|    | PERRENb : Parity ERRor ENable (1 = Enabled)                            |                        |
--|    | MEMSPACEENb : MEMory SPACE ENable (1 = Enabled)                        |                        |
--|    | IOSPACEENb : IO SPACE ENable (1 = Enabled)                            |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | ST (r/w*) STatus register                        |                                                |
--|    +-----------------------------------------------+-------------------------+                        |
--|    | PERRDTb | SERRSIb|   --   |   --   |TABORTSIb| DEVSELTIMb(1..0)|   --   | (15-8)                |
--|    +-------------------------------------------------------------------------+                        |
--|    |    --   |   --   |   --    |    --     |     --       |   --   |   --   |   --   |  (7-0)                 |
--|    +-------------------------------------------------------------------------+                        |
--|    | PERRDTb : Parity ERRor DeTected                                         |                        |
--|    | SERRSIb : System ERRor SIgnaled                                        |                        |
--|    | TABORTSIb : Target ABORT SIgnaled                                        |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | REVISIONID (r) Revision ID register            |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Identifies a device revision.                                              |                        |
--|    +-----------------------------------------------------------------------+                        |
--|    +-----------------------------------------------+                                                |
--|    | CLASSCODE (r) CLASS CODE register                |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Identifies the generic funtion of the device.                              |                        |
--|    +-----------------------------------------------------------------------+                        |
--|    +-----------------------------------------------+                                                |
--|    | HEADERTYPE (r) Header Type register            |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Identifies the layout of the second part of the predefined header.    |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | BAR0 (r/w) Base AddRess 0 register               |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    |                  BAR032MBb(6..0)                             |   --   | (31-24)                |
--|    +-----------------------------------------------------------------------+                        |
--|    | BAR032MBb : Base Address 32MBytes decode space (7 bits)                |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | SUBSYSTEMVID (r) SUBSYSTEM Vendor ID register    |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Identifies vendor of add-in board or subsystem.                          |                        |
--| | SUBSYSTEMVIDr : subsystemvID (generic)                                |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | SUBSYSTEMID (r) SUBSYSTEM ID register            |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Vendor specific.                                                         |                        |
--| | SUBSYTEMIDr : subsytemID (generic)                                    |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | INTLINE (r/w) INTerrupt LINE register            |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    |                          INTLINEr(7..0)                               | (7..0)                |
--|    +-----------------------------------------------------------------------+                        |
--|    | Interrupt Line routing information                                       |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
--|    +-----------------------------------------------+                                                |
--|    | INTPIN (r) INTerrupt PIN register                |                                                |
--|    +-----------------------------------------------+-----------------------+                        |
--|    | Tells which interrupt pin the device uses: 01=INTA                    |                        |
--|    +-----------------------------------------------------------------------+                        |
--|                                                                                                   |
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

entity pciregs is
generic (

    vendorID : std_logic_vector(15 downto 0);
    deviceID : std_logic_vector(15 downto 0);
    revisionID : std_logic_vector(7 downto 0);
    subsystemID : std_logic_vector(15 downto 0);
    subsystemvID : std_logic_vector(15 downto 0);
    classcodeID : std_logic_vector(23 downto 0);
    BARS         : string := "1BARMEM"

);
port (

       -- General 
    clk_i           : in std_logic;
       rst_i           : in std_logic;
    --  
    adr_i            : in std_logic_vector(5 downto 0);
    cbe_i            : in std_logic_vector(3 downto 0);
    dat_i            : in std_logic_vector(31 downto 0);
    dat_o            : out std_logic_vector(31 downto 0);
    --
    wrcfg_i               : in std_logic;
    rdcfg_i           : in std_logic;
    perr_i              : in std_logic;
    serr_i              : in std_logic;
    tabort_i          : in std_logic;
    --
    bar0_o            : out std_logic_vector(31 downto 9);
    perrEN_o        : out std_logic;
    serrEN_o        : out std_logic;
    memEN_o            : out std_logic;
    ioEN_o            : out std_logic
        
);   
end pciregs;


architecture rtl of pciregs is


--+-----------------------------------------------------------------------------+
--|                                    COMPONENTS                                    |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    CONSTANTS                                      |
--+-----------------------------------------------------------------------------+

    --constant CLASSCODEr        : std_logic_vector(23 downto 0) := X"068000";   -- Bridge-OtherBridgeDevice
    constant CLASSCODEr        : std_logic_vector(23 downto 0) := classcodeID;   
    constant REVISIONIDr    : std_logic_vector(7 downto 0)  := revisionID;    -- PR00=80,PR1=81...
    constant HEADERTYPEr    : std_logic_vector(7 downto 0)  := X"00";        
    constant DEVSELTIMb        : std_logic_vector(1 downto 0)  := b"01";        -- DEVSEL TIMing (bits) medium speed
    constant VENDORIDr        : std_logic_vector(15 downto 0) := vendorID;    
    constant DEVICEIDr        : std_logic_vector(15 downto 0) := deviceID;    
    constant SUBSYSTEMIDr    : std_logic_vector(15 downto 0) := subsystemID;    
    constant SUBSYSTEMVIDr    : std_logic_vector(15 downto 0) := subsystemvID;    
    constant INTPINr        : std_logic_vector(7 downto 0)    := X"01";        -- INTA#


--+-----------------------------------------------------------------------------+
--|                                    SIGNALS                                       |
--+-----------------------------------------------------------------------------+

    signal dataout        : std_logic_vector(31 downto 0);
    signal tabortPFS    : std_logic;
    signal serrPFS        : std_logic;
    signal perrPFS        : std_logic;
    signal adrSTCMD        : std_logic;
    signal adrBAR0        : std_logic;
    signal adrINT        : std_logic;
    signal we0CMD        : std_logic;
    signal we1CMD        : std_logic;
    signal we3ST        : std_logic;
    signal we3BAR0        : std_logic;
    signal we0INT        : std_logic;
    signal we1INT        : std_logic;
    signal st11SEN        : std_logic;
    signal st11REN        : std_logic;
    signal st14SEN        : std_logic;
    signal st14REN        : std_logic;
    signal st15SEN        : std_logic;
    signal st15REN        : std_logic;


    --+---------------------------------------------------------+
    --|  CONFIGURATION SPACE REGISTERS                            |
    --+---------------------------------------------------------+

    -- INTERRUPT LINE register 
      signal INTLINEr        : std_logic_vector(7 downto 0);
    -- COMMAND register bits
    signal MEMSPACEENb    : std_logic;                        -- Memory SPACE ENable (bit)
    signal IOSPACEENb    : std_logic;                        -- IO SPACE ENable (bit)
    signal PERRENb        : std_logic;                        -- Parity ERRor ENable (bit)
    signal SERRENb        : std_logic;                        -- SERR ENable (bit)
    -- STATUS register bits
    --signal DEVSELTIMb    : std_logic_vector(1 downto 0);        -- DEVSEL TIMing (bits)
    signal TABORTSIb    : std_logic;                        -- TarGet ABORT SIgnaling (bit)
    signal SERRSIb        : std_logic;                        -- System ERRor SIgnaling (bit)
    signal PERRDTb        : std_logic;                        -- Parity ERRor DeTected (bit)
    -- BAR0 register bits
    signal BAR0b        : std_logic_vector(31 downto 0);

    
begin

    --+-----------------------------------------+
    --| BAR0 32MBytes Memory Space              |
    --+-----------------------------------------+
    barmem_g: if (BARS="1BARMEM") generate
        BAR0b(24 downto 0) <= (others => '0');
    end generate;

    --+-----------------------------------------+
    --| BAR0 512Bytes Io Space                  |
    --+-----------------------------------------+
    bario_g: if (BARS="1BARIO") generate
        BAR0b(31 downto 16) <= (others => '0');
        BAR0b(8 downto 1) <= (others => '0');
        BAR0b(0) <= '1';
    end generate;

    --+-------------------------------------------------------------------------+
    --|  Component instances                                                    |
    --+-------------------------------------------------------------------------+

    u1: entity work.pfs port map ( clk => clk_i, rst => rst_i, a => tabort_i, y => tabortPFS );
    u2: entity work.pfs port map ( clk => clk_i, rst => rst_i, a => serr_i,   y => serrPFS );
    u3: entity work.pfs port map ( clk => clk_i, rst => rst_i, a => perr_i,   y => perrPFS );
     

    --+-------------------------------------------------------------------------+
    --|  Registers Address Decoder                                                |
    --+-------------------------------------------------------------------------+

    adrSTCMD <= '1' when ( adr_i(5 downto 0) = b"000001" ) else '0';
    adrBAR0  <= '1' when ( adr_i(5 downto 0) = b"000100" ) else '0';
    adrINT   <= '1' when ( adr_i(5 downto 0) = b"001111" ) else '0';


    --+-------------------------------------------------------------------------+
    --|                       WRITE ENABLE REGISTERS                            |
    --+-------------------------------------------------------------------------+

    --+-----------------------------------------+
    --|  Write Enable Registers                    |
    --+-----------------------------------------+
        
    we0CMD  <= adrSTCMD and wrcfg_i and (not cbe_i(0));
    we1CMD  <= adrSTCMD and wrcfg_i and (not cbe_i(1));
    --we2ST    <= adrSTCMD and wrcfg_i and (not cbe_i(2));
    we3ST   <= adrSTCMD and wrcfg_i and (not cbe_i(3));
    --we2BAR0 <= adrBAR0  and wrcfg_i and (not cbe_i(2));
    we3BAR0 <= adrBAR0  and wrcfg_i and (not cbe_i(3));
    we0INT  <= adrINT   and wrcfg_i and (not cbe_i(0));
    --we1INT    <= adrINT   and wrcfg_i and (not cbe_i(1));

    --+-----------------------------------------+
    --|  Set Enable & Reset Enable bits            |
    --+-----------------------------------------+
    st11SEN    <= tabortPFS; 
    st11REN    <= we3ST and dat_i(27);
    st14SEN    <= serrPFS; 
    st14REN    <= we3ST and dat_i(30);
    st15SEN    <= perrPFS; 
    st15REN    <= we3ST and dat_i(31);


    --+-------------------------------------------------------------------------+
    --|                              WRITE REGISTERS                                |
    --+-------------------------------------------------------------------------+

    --+---------------------------------------------------------+
    --|  COMMAND REGISTER Write                                    |
    --+---------------------------------------------------------+

    REGCMDWR: process( clk_i, rst_i, we0CMD, we1CMD, dat_i )
    begin
        if( rst_i = '1' ) then
            IOSPACEENb  <= '0';
            MEMSPACEENb <= '0';
            PERRENb     <= '0';
            SERRENb     <= '0';            
        elsif( rising_edge( clk_i ) ) then

            -- Byte 0
            if( we0CMD = '1' ) then
                IOSPACEENb  <= dat_i(0);
                MEMSPACEENb <= dat_i(1);
                PERRENb     <= dat_i(6);                
            end if;
            
            -- Byte 1
            if( we1CMD = '1' ) then
                SERRENb     <= dat_i(8);                
            end if;

        end if;

    end process REGCMDWR;


    --+---------------------------------------------------------+
    --|  STATUS REGISTER WRITE (Reset only)                        |
    --+---------------------------------------------------------+

    REGSTWR: process( clk_i, rst_i, st11SEN, st11REN, st14SEN, st14REN, st15SEN, st15REN )
    begin

        if( rst_i = '1' ) then
            TABORTSIb    <= '0';
            SERRSIb        <= '0';
            PERRDTb        <= '0';
        elsif( rising_edge( clk_i ) ) then

            -- TarGet ABORT SIgnaling bit
            if( st11SEN = '1' ) then
                TABORTSIb    <= '1';
            elsif ( st11REN = '1' ) then
                TABORTSIb    <= '0';            
            end if;

            -- System ERRor SIgnaling bit
            if( st14SEN = '1' ) then
                SERRSIb    <= '1';
            elsif ( st14REN = '1' ) then
                SERRSIb    <= '0';            
            end if;

            -- Parity ERRor DEtected bit
            if( st15SEN = '1' ) then
                PERRDTb    <= '1';
            elsif ( st15REN = '1' ) then
                PERRDTb    <= '0';            
            end if;
            
        end if;

    end process REGSTWR;


    --+---------------------------------------------------------+
    --|  INTERRUPT REGISTER Write                                |
    --+---------------------------------------------------------+

    REGINTWR: process( clk_i, rst_i, we0INT, dat_i )
    begin

        if( rst_i = '1' ) then
            INTLINEr <= ( others => '0' );
        elsif( rising_edge( clk_i ) ) then
            -- Byte 0
            if( we0INT = '1' ) then
                INTLINEr <= dat_i(7 downto 0);
            end if;
        end if;
    end process REGINTWR;


    --+---------------------------------------------------------+
    --|  BAR0 32MBytes MEM address space (bits 31-25)            |
    --+---------------------------------------------------------+
    rbarmem_g: if (BARS="1BARMEM") generate
    RBAR0MEMWR: process( clk_i, rst_i, we3BAR0, dat_i )
    begin
        if( rst_i = '1' ) then
            BAR0b(31 downto 25) <= ( others => '0' );
        elsif( rising_edge( clk_i ) ) then
            -- Byte 3
            if( we3BAR0 = '1' ) then
                BAR0b(31 downto 25) <= dat_i(31 downto 25);
            end if;    
        end if;
    end process RBAR0MEMWR;
    end generate;

    --+---------------------------------------------------------+
    --|  BAR0 512Bytes IO address space (bits 15-9)                |
    --+---------------------------------------------------------+
    rbario_g: if (BARS="1BARIO") generate
    RBAR0IOWR: process( clk_i, rst_i, we3BAR0, dat_i )
    begin
        if( rst_i = '1' ) then
            BAR0b(15 downto 9) <= ( others => '0' );
        elsif( rising_edge( clk_i ) ) then
            -- Byte 3
            if( we3BAR0 = '1' ) then
                BAR0b(15 downto 9) <= dat_i(15 downto 9);
            end if;    
        end if;
    end process RBAR0IOWR;
    end generate;



    --+-------------------------------------------------------------------------+
    --|  Registers MUX    (READ)                                                    |
    --+-------------------------------------------------------------------------+
    RRMUX: process( adr_i, PERRDTb, SERRSIb, TABORTSIb, SERRENb, PERRENb, MEMSPACEENb, IOSPACEENb, BAR0b, 
                    INTLINEr, rdcfg_i )
    begin

        if ( rdcfg_i = '1' ) then
        
            case adr_i is

                when b"000000" => 
                    dataout <= DEVICEIDr & VENDORIDr;
                when b"000001" => 
                    dataout <= PERRDTb & SERRSIb & b"00" & TABORTSIb & DEVSELTIMb & b"000000000" &
                               b"0000000" & SERRENb & b"0" & PERRENb & b"0000" & MEMSPACEENb & IOSPACEENb;
                when b"000010" => 
                    dataout <= CLASSCODEr & REVISIONIDr;
                when b"000100" => 
                    dataout <= BAR0b;
                when b"001011" => 
                    dataout <= SUBSYSTEMIDr & SUBSYSTEMVIDr;
                when b"001111" => 
                    dataout <= b"0000000000000000" & INTPINr & INTLINEr;
                when others    => 
                    dataout <= ( others => '0' );

            end case;
    
        else
        
            dataout <= ( others => '0' );
            
        end if;

    end process RRMUX;

    dat_o <= dataout;
    
    
    --+-------------------------------------------------------------------------+
    --|  BAR0 & COMMAND REGS bits outputs                                        |
    --+-------------------------------------------------------------------------+
    
    bar0_o         <= BAR0b(31 downto 9);
    perrEN_o    <= PERRENb;
    serrEN_o    <= SERRENb;        
    memEN_o        <= MEMSPACEENb;
    ioEN_o        <= IOSPACEENb;

    
end rtl;
