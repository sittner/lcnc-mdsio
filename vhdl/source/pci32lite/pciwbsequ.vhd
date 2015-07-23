--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  Fileo:            pciwbsequ.vhd                                                                      |
--|                                                                                                    |
--|  Project:        pci32tLite                                                                        |
--|                                                                                                    |
--|  Description:     FSM controling pci to whisbone transactions.                                    |
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

entity pciwbsequ is
generic (
    BARS         : string := "1BARMEM";
    WBSIZE         : integer := 16;
    WBENDIAN     : string := "BIG"
);
port (
       -- General 
    clk_i           : in std_logic;
       rst_i           : in std_logic;
    -- pci 
    cmd_i            : in std_logic_vector(3 downto 0);
    cbe_i            : in std_logic_vector(3 downto 0);
    frame_i             : in std_logic;
    irdy_i            : in std_logic;
    devsel_o        : out std_logic;
    trdy_o            : out std_logic;
    stop_o            : out std_logic;
    targ_oe           : out std_logic;
    -- control
    adrcfg_i        : in std_logic;
    adrmem_i         : in std_logic;
    pciadrLD_o           : out std_logic;
    pcidOE_o           : out std_logic;
    parOE_o            : out std_logic;
    wbdatLD_o       : out std_logic;
    wrcfg_o         : out std_logic;
    rdcfg_o         : out std_logic;
    -- whisbone
    wb_sel_o        : out std_logic_vector(((WBSIZE/8)-1) downto 0);
    wb_we_o            : out std_logic;
    wb_stb_o        : out std_logic;    
    wb_cyc_o        : out std_logic;
    wb_ack_i        : in std_logic;
    wb_rty_i         : in std_logic;
    wb_err_i        : in std_logic    
    
);   
end pciwbsequ;


architecture rtl of pciwbsequ is


--+-----------------------------------------------------------------------------+
--|                                    COMPONENTS                                    |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    CONSTANTS                                      |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    SIGNALS                                       |
--+-----------------------------------------------------------------------------+

    type PciFSM is ( PCIIDLE, B_BUSY, S_DATA1, S_DATA2, BACKOFF, TURN_ARL, TURN_ARE );
      signal pst_pci         : PciFSM;
      signal nxt_pci         : PciFSM;

      signal bbusy        : std_logic;
      signal idle            : std_logic;
      signal sdata1        : std_logic;
      signal sdata2        : std_logic;
    signal sdata1NX        : std_logic;
    signal sdata2NX        : std_logic;
    signal turnarlNX    : std_logic;
    signal turnarl        : std_logic;
      signal devselNX_n    : std_logic;
      signal trdyNX_n        : std_logic;
      signal stopNx_n        : std_logic;
      signal devsel        : std_logic;
      signal trdy            : std_logic;
      signal stop            : std_logic;
      signal adrpci        : std_logic;
      signal acking        : std_logic;
      signal retrying        : std_logic;
      signal rdcfg        : std_logic;
    signal targOE        : std_logic;
    signal pcidOE        : std_logic;
    signal pcidOE_s        : std_logic;

begin
    
    
    --+-------------------------------------------------------------------------+
    --|  PCI-Whisbone Sequencer                                                    |
    --+-------------------------------------------------------------------------+
    
    --+-------------------------------------------------------------+
    --|  FSM PCI-Whisbone                                            |
    --+-------------------------------------------------------------+    
    PCIFSM_CLOCKED: process( rst_i, clk_i, nxt_pci )
    begin    
        if( rst_i = '1' ) then
            pst_pci <= PCIIDLE;
          elsif( rising_edge(clk_i) ) then
            pst_pci <= nxt_pci; 
        end if;  
    end process PCIFSM_CLOCKED;


      PCIFSM_COMB: process( pst_pci, frame_i, irdy_i, adrcfg_i, adrpci, acking, retrying )
    begin
        
        devselNX_n     <= '1';
        trdyNX_n     <= '1';    
        stopNX_n     <= '1';    

        case pst_pci is

            when PCIIDLE =>
                   if ( frame_i = '0' ) then    
                    nxt_pci <= B_BUSY;     
                else
                    nxt_pci <= PCIIDLE;
                end if;        
                
            when B_BUSY =>
                if ( adrpci = '0' ) then
                    nxt_pci <= TURN_ARE;
                else
                    nxt_pci    <= S_DATA1;
                    devselNX_n <= '0'; 
                end if;

            when S_DATA1 =>
                   if (acking = '1') then    
                    if (frame_i = '0') then
                        stopNX_n     <= '0';    
                    end if;
                    nxt_pci     <= S_DATA2;
                    devselNX_n     <= '0';                     
                    trdyNX_n     <= '0';    
                elsif (retrying = '1') then
                    nxt_pci     <= BACKOFF;
                    devselNX_n     <= '0';                     
                    stopNX_n     <= '0';    
                else
                    nxt_pci    <= S_DATA1;
                    devselNX_n <= '0';                     
                end if;        
                                
            when S_DATA2 => 
                    nxt_pci <= TURN_ARL;
                
            when BACKOFF => 
                if ( frame_i = '1' and irdy_i = '0' ) then
                    nxt_pci <= TURN_ARL;
                else
                    nxt_pci     <= BACKOFF;
                    devselNX_n     <= '0';                     
                    stopNX_n     <= '0';    
                end if;
            
            when TURN_ARL =>
                if (frame_i = '0') then
                    nxt_pci <= B_BUSY;
                else
                    nxt_pci <= PCIIDLE;
                end if;                

            when TURN_ARE =>
                if (frame_i = '0') then
                    nxt_pci <= TURN_ARE;
                else
                    nxt_pci <= PCIIDLE;
                end if;                

        end case;
        
    end process PCIFSM_COMB;    


    --+-------------------------------------------------------------+
    --|  FSM control signals                                        |
    --+-------------------------------------------------------------+

    adrpci  <= adrmem_i or adrcfg_i;
    acking  <= '1' when ( wb_ack_i = '1' or wb_err_i = '1' ) or ( adrcfg_i = '1' and  irdy_i = '0')
                   else '0'; 
    retrying <= '1' when ( wb_rty_i = '1' )  else '0'; 


    --+-------------------------------------------------------------+
    --|  FSM derived Control signals                                |
    --+-------------------------------------------------------------+
    idle         <= '1' when ( pst_pci = PCIIDLE ) else '0';
    bbusy        <= '1' when ( pst_pci = B_BUSY  ) else '0';
    sdata1         <= '1' when ( pst_pci = S_DATA1 ) else '0';
    sdata2         <= '1' when ( pst_pci = S_DATA2 ) else '0';
    --turnar         <= '1' when ( pst_pci = TURN_AR ) else '0';
    turnarl     <= '1' when ( pst_pci = TURN_ARL ) else '0';
    sdata1NX     <= '1' when ( nxt_pci = S_DATA1 ) else '0';    
    sdata2NX     <= '1' when ( nxt_pci = S_DATA2 ) else '0';
    --turnarNX     <= '1' when ( nxt_pci = TURN_AR ) else '0';
    turnarlNX     <= '1' when ( nxt_pci = TURN_ARL ) else '0';


    --+-------------------------------------------------------------+
    --|  PCI Data Output Enable                                        |
    --+-------------------------------------------------------------+
 
    PCIDOE_P: process( rst_i, clk_i, cmd_i(0), sdata1NX, turnarlNX )
    begin

        if ( rst_i = '1' ) then 
            pcidOE <= '0';
          elsif ( rising_edge(clk_i) ) then 

            if ( sdata1NX = '1' and cmd_i(0) = '0' ) then
                pcidOE <= '1';
            elsif ( turnarlNX = '1' ) then
                pcidOE <= '0';
            end if;            
            
        end if;

    end process PCIDOE_P;

    pcidOE_o <= pcidOE;


    --+-------------------------------------------------------------+
    --|  PAR Output Enable                                            |
    --|  PCI Read data phase                                        |
    --|  PAR is valid 1 cicle after data is valid                    |
    --+-------------------------------------------------------------+
    uu1: entity work.syncl port map ( clk => clk_i, rst => rst_i, d => pcidOE, q => pcidOE_s );
    parOE_o <= pcidOE_s;


    --+-------------------------------------------------------------+
    --|  Target s/t/s signals OE control                            |
    --+-------------------------------------------------------------+

    TARGOE_P: process( rst_i, clk_i, sdata1NX, turnarl )
    begin

        if ( rst_i = '1' ) then 
            targOE <= '0';
          elsif ( rising_edge(clk_i) ) then 

            if ( sdata1NX = '1' ) then
                targOE <= '1';
            elsif ( turnarl = '1' ) then
                targOE <= '0';
            end if;            
            
        end if;

    end process TARGOE_P;
        

    --+-------------------------------------------------------------------------+
    --|  WHISBONE outs                                                            |
    --+-------------------------------------------------------------------------+

    cyc_p: process(rst_i, clk_i, adrmem_i, bbusy, acking, retrying, frame_i)
    begin
        if ( rst_i = '1' ) then 
            wb_cyc_o <= '0';
          elsif ( rising_edge(clk_i) ) then 
            if (adrmem_i = '1' and bbusy = '1' ) then
                wb_cyc_o <= '1';
            elsif ((acking = '1' or retrying = '1') and frame_i = '1') then
                wb_cyc_o <= '0';
            end if;            
        end if;
    end process cyc_p;

    wb_stb_o <= '1' when ( adrmem_i = '1' and sdata1 = '1' and irdy_i = '0' ) else '0';
    wb_we_o <= cmd_i(0);

    --+-----------------------------------------+
    --| wb_sel_o generation depending on WBSIZE    |
    --|  and WBENDIAN "generics" configuration    |
    --+-----------------------------------------+
    sel32: if (WBSIZE = 32) generate
        wb_sel_o(3) <= not cbe_i(3);
        wb_sel_o(2) <= not cbe_i(2);
        wb_sel_o(1) <= not cbe_i(1);
        wb_sel_o(0) <= not cbe_i(0);
    end generate;    

    sel16b: if (WBSIZE = 16 and WBENDIAN = "BIG") generate
        wb_sel_o(1) <= (not cbe_i(0)) or (not cbe_i(2));
        wb_sel_o(0) <= (not cbe_i(1)) or (not cbe_i(3));    
    end generate;

    sel16l: if (WBSIZE = 16 and WBENDIAN = "LITTLE") generate
        wb_sel_o(1) <= (not cbe_i(1)) or (not cbe_i(3));
        wb_sel_o(0) <= (not cbe_i(0)) or (not cbe_i(2));    
    end generate;

    sel8: if (WBSIZE = 8) generate
        wb_sel_o(0) <= not (cbe_i(0) and cbe_i(1) and cbe_i(2) and cbe_i(3));
    end generate;    


    --+-------------------------------------------------------------------------+
    --|  Syncronized PCI outs                                                    |
    --+-------------------------------------------------------------------------+
    
    PCISIG: process( rst_i, clk_i, devselNX_n, trdyNX_n, stopNX_n)
    begin
        if( rst_i = '1' ) then 
            devsel         <= '1';
            trdy         <= '1';
            stop         <= '1';
        elsif( rising_edge(clk_i) ) then 
            devsel         <= devselNX_n;
            trdy         <= trdyNX_n;
            stop         <= stopNX_n;    
        end if;        
    end process PCISIG;

    targ_oe  <= targOE;
    devsel_o <= devsel;
    trdy_o   <= trdy;
    stop_o   <= stop;


    --+-------------------------------------------------------------------------+
    --|  Other outs                                                                |
    --+-------------------------------------------------------------------------+

    --  rd/wr Configuration Space Registers
    wrcfg_o <= '1' when ( adrcfg_i = '1' and cmd_i(0) = '1' and sdata2 = '1' ) else '0';
    rdcfg <= '1' when ( adrcfg_i = '1' and cmd_i(0) = '0' and ( sdata1 = '1' or sdata2 = '1' ) ) else '0';
    rdcfg_o <= rdcfg;
    
    -- LoaD enable signals
    --pciadrLD_o <= '1' when(frame_i = '0' and idle = '1') else '0';
    -- added turnarl to support Fast Back to Back
    pciadrLD_o <= '1' when(frame_i = '0' and (idle = '1' or turnarl = '1')) else '0';
    wbdatLD_o  <= wb_ack_i;

end rtl;
