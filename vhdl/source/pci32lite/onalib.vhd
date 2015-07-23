--+-------------------------------------------------------------------------------------------------+
--|                                                                                                    |
--|  Fileo:            onalib.vhd                                                                          |    
--|                                                                                                    |
--|  Project:        onalib                                                                            |
--|                                                                                                    |
--|  Description:     Libreria de componentes en VHDL.                                                   |
--|                                                                                                    |
--+-------------------------------------------------------------------------------------------------+
--|                   Component                         |                    Descripcion                        |
--+-------------------------------------------------------------------------------------------------+
--|    sync(clk, d, q)                                | Sincronizacion de una señal a traves de un FF.    |
--|                                                | Sin reset.                                        |
--+-------------------------------------------------------------------------------------------------+
--|    sync2(clk, d, q)                            | Doble Sincronizacion de una señal a traves de dos |
--|                                                | FF. Sin reset.                                    |
--+-------------------------------------------------------------------------------------------------+
--|    sync2h(clk, rst, d, q)                        | Doble Sincronizacion de una señal a traves de dos |
--|                                                | FF. Con reset e inicializacion a '1'.                |
--+-------------------------------------------------------------------------------------------------+
--|    sync2l(clk, rst, d, q)                        | Doble Sincronizacion de una señal a traves de dos |
--|                                                | FF. Con reset e inicializacion a '0'.                |
--+-------------------------------------------------------------------------------------------------+
--|    syncrsld(clk, rst, ld, d, q)                | Sincronizacion de una señal a traves de un FF     |
--|                                                | con reset y load.                                    |
--+-------------------------------------------------------------------------------------------------+
--|    syncv(size)(clock, d, q)                    | Sincronizacion de un vector (generic)             |
--|                                                | con reset y load.                                    |
--+-------------------------------------------------------------------------------------------------+
--|    decoder3to8(i, o)                            | Decoder 3 to 8                                       |
--+-------------------------------------------------------------------------------------------------+
--|    pfs(clk, a, y)                                | Pulso a '1' en Flanco de Subida                    |
--+-------------------------------------------------------------------------------------------------+
--|    pfb(clk, a, y)                                | Pulso a '1' en Flanco de bajada                    |
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
--|                                ENTITY & ARCHITECTURE                            |
--+-----------------------------------------------------------------------------+


--+-----------------------------------------+
--|  sync                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity sync is
port (

    clk           : in std_logic;
    d           : in std_logic;
       q           : out std_logic

);   
end sync;

architecture rtl of sync is
begin

    SYNCP: process( clk, d )
    begin
    
        if ( rising_edge(clk) ) then
            q <= d;
        end if;
        
    end process SYNCP;

end rtl;

--+-----------------------------------------+
--|  synch                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity synch is
port (

    clk           : in std_logic;
    rst           : in std_logic;
    d           : in std_logic;
       q           : out std_logic

);   
end synch;

architecture rtl of synch is
begin

    SYNCHP: process( clk, rst, d )
    begin
        if (rst = '1') then
            q     <= '1';
        elsif ( rising_edge(clk) ) then
            q <= d;
        end if;
        
    end process SYNCHP;

end rtl;

--+-----------------------------------------+
--|  syncl                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity syncl is
port (

    clk           : in std_logic;
    rst           : in std_logic;
    d           : in std_logic;
       q           : out std_logic

);   
end syncl;

architecture rtl of syncl is
begin

    SYNCLP: process( clk, rst, d )
    begin
        if (rst = '1') then
            q     <= '0';
        elsif ( rising_edge(clk) ) then
            q <= d;
        end if;
        
    end process SYNCLP;

end rtl;


--+-----------------------------------------+
--|  sync2                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity sync2 is
    port (

        clk           : in std_logic;
        d           : in std_logic;
        q           : out std_logic

    );   
end sync2;

architecture rtl of sync2 is
    signal tmp:    std_logic;
begin

    SYNC2P: process ( clk, d, tmp)
    begin    
    
        if ( rising_edge(clk) ) then 
            tmp <= d; 
            q <= tmp;
        end if;
        
    end process SYNC2P;
    
end rtl;

--+-----------------------------------------+
--|  sync2h                                    |
--+-----------------------------------------+
-- sync2 con inicializacion a '1' con el reset
library ieee;
use ieee.std_logic_1164.all;

entity sync2h is
    port (

        clk           : in std_logic;
        rst           : in std_logic;
        d           : in std_logic;
        q           : out std_logic

    );   
end sync2h;

architecture rtl of sync2h is
    signal tmp:    std_logic;
begin

    SYNC2HP: process ( clk, rst, d, tmp)
    begin    
    
        if (rst = '1') then
            tmp <= '1';
            q     <= '1';
        elsif ( rising_edge(clk) ) then 
            tmp <= d; 
            q <= tmp;
        end if;
        
    end process SYNC2HP;
    
end rtl;

--+-----------------------------------------+
--|  sync2l                                    |
--+-----------------------------------------+
-- sync2 con inicializacion a '0' con el reset
library ieee;
use ieee.std_logic_1164.all;

entity sync2l is
    port (

        clk           : in std_logic;
        rst           : in std_logic;
        d           : in std_logic;
        q           : out std_logic

    );   
end sync2l;

architecture rtl of sync2l is
    signal tmp:    std_logic;
begin

    SYNC2LP: process ( clk, rst, d, tmp)
    begin    
    
        if (rst = '1') then
            tmp <= '0';
            q     <= '0';
        elsif ( rising_edge(clk) ) then 
            tmp <= d; 
            q <= tmp;
        end if;
        
    end process SYNC2LP;
    
end rtl;



--+-----------------------------------------+
--|  syncv                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity syncv is
generic ( size: integer := 8 );
port (

    clk           : in std_logic;
    d           : in std_logic_vector(size-1 downto 0);
       q           : out std_logic_vector(size-1 downto 0)

);   
end syncv;

architecture rtl of syncv is
begin

    SYNCVP: process( clk, d )
    begin
    
        if ( rising_edge(clk) ) then
            q <= d;
        end if;
        
    end process SYNCVP;

end rtl;

--+-----------------------------------------+
--|  syncv2h                                |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity syncv2h is
generic ( size: integer := 8 );
port (

    clk           : in std_logic;
    rst           : in std_logic;
    d           : in std_logic_vector(size-1 downto 0);
       q           : out std_logic_vector(size-1 downto 0)

);   
end syncv2h;

architecture rtl of syncv2h is
    signal tmp:    std_logic_vector(size-1 downto 0);
begin

    SYNCV2HP: process( clk, d, rst )
    begin
    
        if (rst = '1') then
            tmp <= (others => '1');
            q     <= (others => '1');
        elsif ( rising_edge(clk) ) then
            tmp <= d;
            q <= tmp;
        end if;
        
    end process SYNCV2HP;

end rtl;


--+-----------------------------------------+
--|  decoder3to8                            |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity decoder3to8 is
port (

    i           : in std_logic_vector(2 downto 0);
       o           : out std_logic_vector(7 downto 0)

);   
end decoder3to8;

architecture rtl of decoder3to8 is
begin

    DECOD3TO8P: process( i )
    begin
    
        if    ( i = "111" ) then o <= "01111111";
        elsif ( i = "110" ) then o <= "10111111";
        elsif ( i = "101" ) then o <= "11011111";
        elsif ( i = "100" ) then o <= "11101111";
        elsif ( i = "011" ) then o <= "11110111";
        elsif ( i = "010" ) then o <= "11111011";
        elsif ( i = "001" ) then o <= "11111101";
        elsif ( i = "000" ) then o <= "11111110";    
        else
            o <= "11111111";    
        end if;
        
    end process DECOD3TO8P;

end rtl;


--+-----------------------------------------+
--|  pfs                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity pfs is
port (

    clk           : in std_logic;
    rst           : in std_logic;
    a           : in std_logic;
       y           : out std_logic

);   
end pfs;

architecture rtl of pfs is

    signal a_s    : std_logic;
    signal a_s2    : std_logic;
    
begin

    PFSP: process( clk, rst, a )
    begin
        
        if ( rst = '1' ) then
            a_s  <= '0';
            a_s2 <= '1';
        elsif ( rising_edge(clk) ) then
            a_s  <= a;
            a_s2 <= a_s;
        end if;
        
    end process PFSP;

    y <= a_s and (not a_s2);
    
end rtl;

--+-----------------------------------------+
--|  pfb                                    |
--+-----------------------------------------+

library ieee;
use ieee.std_logic_1164.all;

entity pfb is
port (

    clk           : in std_logic;
    rst           : in std_logic;
    a           : in std_logic;
       y           : out std_logic

);   
end pfb;

architecture rtl of pfb is

    signal a_s    : std_logic;
    signal a_s2    : std_logic;
    
begin

    PFBP: process( clk, rst, a )
    begin
    
        if ( rst = '1' ) then
            a_s  <= '1';
            a_s2 <= '0';
        elsif ( rising_edge(clk) ) then
            a_s  <= a;
            a_s2 <= a_s;
        end if;
        
    end process PFBP;

    y <= (not a_s) and a_s2;

end rtl;

