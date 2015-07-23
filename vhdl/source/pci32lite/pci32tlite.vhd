--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  File:            pci32tLite.vhd                                                                      |
--|                                                                                                    |
--|  Components:    pcidec.vhd                                                                        |
--|                    pciwbsequ.vhd                                                                   |
--|                    pcidmux.vhd                                                                       |
--|                    pciregs.vhd                                                                       |
--|                    pcipargen.vhd                                                                      |
--|                    ona.vhd                                                                              |
--|                                                                                                    |
--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  Revision history :                                                                                |
--|  Date           Version    Author    Description                                                        |
--|  2005-05-13   R00A00    PAU        First alfa revision                                                |
--|                                                                                                    |
--|  2006-11-27      R01        PAU        * BUG fast back-to-back transactions                            |
--|                                    * TIMEOUT: Target termination with RETRY                        |
--|     2007-09-19   R02        PAU        * "intb" and "serr" signals not defined as TRI. They have to be |
--|                                    defined Opendrain in the FPGA (externally to the IP Core).        |
--|                                    * Small changes due to onalib.vhd improvement.                    |
--|                                    * Removed TIMEOUT. Added wb_rty_i for Target termination with     |
--|                                    RETRY.                                                            |
--|                                    * Support Burst Cicles.                                            |
--|                                    * Add Whisbone data bus configuration generics: WBSIZE and         |
--|                                    WBENDIAN.                                                        |
--|                                    * Add wb_adr_o(1..0) signals.                                    |
--|                                    * wb_dat_i,wb_dat_o,wb_sel_o size depends on WBSIZE.            |
--|                                    * Advice: Change WB <-> PCI databus routing for "BIG"/16 WB     |
--|                                    configuration and DWORD PCI transactions (DWORD is not            |
--|                                    recomended when WB 16 configuration).                            |
--|     2008-06-16   R03        PAU        * Add "1BARIO" configuration option for BARS generic.            |
--|                                    * fix bug with WBENDIAN generic in pciwbsequ.                    |
--|                                    * Change PCI Burts to WB traslation behavior.                    |
--|                                    * Add "classcode" generic.                                        |
--|                                    * Change BAR0 reset state to "0".                                |
--|                                    * Fix pcidmux bug for LITTLE/8 configuration.                    |
--|                                                                                                    |
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
entity pci32tLite is
generic (
    vendorID      : std_logic_vector(15 downto 0) := x"4150";
    deviceID      : std_logic_vector(15 downto 0) := x"0001";
    revisionID      : std_logic_vector(7 downto 0)  := x"90";
    subsystemID  : std_logic_vector(15 downto 0) := x"0000";
       subsystemvID : std_logic_vector(15 downto 0) := x"1172";
    classcodeID  : std_logic_vector(23 downto 0) := x"068000";
    -- BAR&WB_CFG (dont delete)
    BARS        : string := "1BARMEM";
    WBSIZE        : integer := 16;
    WBENDIAN    : string := "BIG"
);
port (
    -- General 
    clk33       : in std_logic;
    rst            : in std_logic;
    
    -- PCI target 32bits
    ad_in       : in std_logic_vector(31 downto 0);
    ad_out      : out std_logic_vector(31 downto 0);
    ad_oe       : out std_logic;
    cbe         : in std_logic_vector(3 downto 0);
    par_in      : in std_logic;  
    par_out     : out std_logic;  
    par_oe      : out std_logic;  
    frame       : in std_logic;
    irdy        : in std_logic;
    trdy_out    : out std_logic;
    devsel_out  : out std_logic;
    stop_out    : out std_logic;
    targ_oe     : out std_logic;
    idsel       : in std_logic;
    perr_drv    : out std_logic;
    serr_drv    : out std_logic;
    inta_drv    : out std_logic;
    req_drv     : out std_logic;
    gnt         : in std_logic;
      
    -- Master whisbone
    wb_adr_o     : out std_logic_vector(24 downto 0);     
    wb_dat_i     : in std_logic_vector(WBSIZE-1 downto 0);
    wb_dat_o     : out std_logic_vector(WBSIZE-1 downto 0);
    wb_sel_o     : out std_logic_vector(((WBSIZE/8)-1) downto 0);
    wb_we_o      : out std_logic;
    wb_stb_o     : out std_logic;
    wb_cyc_o     : out std_logic;
    wb_ack_i     : in std_logic;
    wb_rty_i     : in std_logic;
    wb_err_i     : in std_logic;
    wb_int_i     : in std_logic

);
end pci32tLite;


--+-----------------------------------------------------------------------------+
--|                                    ARCHITECTURE                                |
--+-----------------------------------------------------------------------------+

architecture rtl of pci32tLite is

--+-----------------------------------------------------------------------------+
--|                                    CONSTANTS                                      |
--+-----------------------------------------------------------------------------+
--+-----------------------------------------------------------------------------+
--|                                    SIGNALS                                       |
--+-----------------------------------------------------------------------------+

    signal bar0            : std_logic_vector(31 downto 9);
    signal memEN        : std_logic;
    signal ioEN            : std_logic;
    signal pciadrLD        : std_logic;
    signal adrcfg        : std_logic;
    signal adrmem        : std_logic;
    signal adr            : std_logic_vector(24 downto 0);
    signal cmd            : std_logic_vector(3 downto 0);
    signal pcidOE        : std_logic;
    signal wbdatLD        : std_logic;
    signal wrcfg        : std_logic;
    signal rdcfg        : std_logic;
    signal pcidatread    : std_logic_vector(31 downto 0);
    signal pcidatwrite    : std_logic_vector(31 downto 0);
    signal pcidatout    : std_logic_vector(31 downto 0);    
    signal parerr        : std_logic;
    signal syserr        : std_logic;
    signal tabort        : std_logic;
    signal perrEN        : std_logic;
    signal serrEN        : std_logic;
            
begin
    -- ASSERT
    assert (BARS = "1BARMEM" or BARS = "1BARIO")
         report "ERROR : Bad BAR configuration"
         severity Failure;
    assert ((WBSIZE = 32 and WBENDIAN = "LITTLE") or (WBSIZE = 16) or (WBSIZE = 8 and WBENDIAN = "LITTLE"))
         report "ERROR : Bad WBSIZE/WBENDIAN configuration"
         severity Failure;

    --+-------------------------------------------------------------------------+
    --|  Component instances                                                    |
    --+-------------------------------------------------------------------------+

    --+-----------------------------------------+
    --|  PCI decoder                            |
    --+-----------------------------------------+
    u1: entity work.pcidec 
    generic map (
        BARS         => BARS
    )
    port map (

        clk_i       => clk33,
           rst_i          => rst,
        --
        ad_i        => ad_in,
        cbe_i        => cbe,
        idsel_i        => idsel,
        bar0_i      => bar0,
        memEN_i        => memEN,
        ioEN_i        => ioEN,
        pciadrLD_i    => pciadrLD,    
        adrcfg_o    => adrcfg,
        adrmem_o    => adrmem,
        adr_o        => adr,
        cmd_o        => cmd    
    );


    --+-----------------------------------------+
    --|  PCI-WB Sequencer                        |
    --+-----------------------------------------+
    u2: entity work.pciwbsequ 
    generic map (
        BARS         => BARS,
        WBSIZE         => WBSIZE,
        WBENDIAN     => WBENDIAN
    )
    port map (
           -- General 
        clk_i         => clk33,         
           rst_i       => rst,
        -- pci 
        cmd_i        => cmd,
        cbe_i        => cbe,
        frame_i        => frame,
        irdy_i      => irdy,    
        devsel_o    => devsel_out,
        trdy_o      => trdy_out,     
        stop_o      => stop_out,
        targ_oe     => targ_oe,     
        -- control
        adrcfg_i    => adrcfg,
        adrmem_i     => adrmem,
        pciadrLD_o    => pciadrLD,
        pcidOE_o    => pcidOE,
        parOE_o        => par_oe,    
        wbdatLD_o   => wbdatLD,
        wrcfg_o     => wrcfg,
        rdcfg_o     => rdcfg,
        -- whisbone
        wb_sel_o    => wb_sel_o(((WBSIZE/8)-1) downto 0),
        wb_we_o        => wb_we_o,
        wb_stb_o    => wb_stb_o,
        wb_cyc_o    => wb_cyc_o,
        wb_ack_i    => wb_ack_i,
        wb_rty_i    => wb_rty_i,
        wb_err_i    => wb_err_i        
    );
   

    --+-----------------------------------------+
    --|  PCI-wb datamultiplexer                    |
    --+-----------------------------------------+
    u3: entity work.pcidmux
    generic map (
        BARS         => BARS,
        WBSIZE         => WBSIZE,
        WBENDIAN     => WBENDIAN
    )
    port map (
        clk_i       => clk33,
           rst_i          => rst,
        --
        d_in        => ad_in,    
        d_out       => pcidatout,    
        wbdatLD_i    => wbdatLD,
        rdcfg_i        => rdcfg,
        cbe_i        => cbe,
        wb_dat_i    => wb_dat_i((WBSIZE-1) downto 0),
        wb_dat_o    => wb_dat_o((WBSIZE-1) downto 0),
        rg_dat_i    => pcidatread,
        rg_dat_o    => pcidatwrite        
    );
    ad_out <= pcidatout;
    ad_oe  <= pcidOE;


    --+-----------------------------------------+
    --|  PCI registers                            |
    --+-----------------------------------------+
    u4: entity work.pciregs
    generic map (
        vendorID         => vendorID,
        deviceID         => deviceID,
        revisionID         => revisionID,
        subsystemID     => subsystemID,
        subsystemvID     => subsystemvID,
        classcodeID     => classcodeID,
        BARS            => BARS
    )
    port map (
        clk_i       => clk33,
           rst_i          => rst,
        --
        adr_i        => adr(7 downto 2),
        cbe_i        => cbe,
        dat_i        => pcidatwrite,
        dat_o        => pcidatread,
           wrcfg_i     => wrcfg,
           rdcfg_i     => rdcfg,
           perr_i      => parerr,
           serr_i      => syserr,
           tabort_i    => tabort,
        bar0_o        => bar0,
        perrEN_o    => perrEN,
        serrEN_o    => serrEN,
        memEN_o        => memEN,
         ioEN_o        => ioEN
            
    );
    
    --+-----------------------------------------+
    --|  PCI Parity Gnerator                    |
    --+-----------------------------------------+
    u5: entity work.pcipargen
    port map (
        clk_i       => clk33,
        pcidatout_i    => pcidatout,    
        cbe_i        => cbe,
        par_o        => par_out
    );

    --+-----------------------------------------+
    --|  Whisbone Address bus                    |
    --+-----------------------------------------+
    wb_adr_o <= adr;

    --+-----------------------------------------+
    --|  unimplemented                            |
    --+-----------------------------------------+
    parerr     <= '0';
    syserr     <= '0';
    tabort     <= '0';

    --+-----------------------------------------+
    --|  unused outputs                            |
    --+-----------------------------------------+
    perr_drv <= '0';
    serr_drv <= '0';
    req_drv  <= '0';
    
    --+-----------------------------------------+
    --|  Interrupt                                |
    --+-----------------------------------------+
    inta_drv <= wb_int_i;

end rtl;


