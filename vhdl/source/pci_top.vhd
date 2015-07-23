library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity pci_top is
  generic (
    BARS     : string  := "1BARMEM";
    WBSIZE   : integer := 32;
    WBENDIAN : string  := "LITTLE"
  );
  port (
    -- onboard clock
    onboard_clock : in std_logic;

    -- PCI Target 32 bits
    pclk          : in std_logic;
    rst_n         : in std_logic;
    ad            : inout std_logic_vector(31 downto 0);
    cbe_n         : in std_logic_vector(3 downto 0);
    par           : inout std_logic;  
    frame_n       : in std_logic;
    irdy_n        : in std_logic;
    trdy_n        : inout std_logic;
    devsel_n      : inout std_logic;
    stop_n        : inout std_logic;
    idsel         : in std_logic;
    perr_n        : inout std_logic;
    serr_n        : inout std_logic;
    inta_n        : out std_logic;
    req_n         : out std_logic;
    gnt_n         : in std_logic;

    -- JTAG drive
--    tdi           : in std_logic;
--    tms           : out std_logic;
--    tck           : out std_logic;
--    tdo           : out std_logic;

    -- CAN Transceivers
    can1_tx       : out std_logic;
    can1_rx       : in std_logic;
    can2_tx       : out std_logic;
    can2_rx       : in std_logic;

    -- 2x40 Connector
    LED_CONF : out std_logic;
    LED_RUN  : out std_logic;
    SV1      : inout std_logic_vector(10 downto 3);
    SV2      : inout std_logic_vector(10 downto 3);
    SV3      : inout std_logic_vector(10 downto 3);
    SV4      : inout std_logic_vector(10 downto 3);
    SV5      : inout std_logic_vector(10 downto 3);
    SV6      : inout std_logic_vector(10 downto 3);
    SV7      : inout std_logic_vector(10 downto 3);
    SV8      : inout std_logic_vector(10 downto 3);
    SV9      : inout std_logic_vector(10 downto 3)

  );
end pci_top;

architecture rtl of pci_top is

  signal clk32ib        : std_logic;
  signal clk32ob        : std_logic;
  signal clk32          : std_logic;
  signal clk8ob         : std_logic;
  signal clk8           : std_logic;
  signal clk100ob       : std_logic;
  signal clk100         : std_logic;
  signal dcm_locked     : std_logic;

  signal sclk_cnt       : std_logic_vector(4 downto 0);
  signal sclk_edge      : std_logic;
  signal sclk_state     : std_logic;

  signal wb_clk         : std_logic;
  signal wb_rst         : std_logic;
  signal wb_adr         : std_logic_vector(24 downto 0);
  signal wb_datrd       : std_logic_vector(WBSIZE-1 downto 0);
  signal wb_datwr       : std_logic_vector(WBSIZE-1 downto 0);
  signal wb_sel         : std_logic_vector(((WBSIZE/8)-1) downto 0);
  signal wb_we          : std_logic;
  signal wb_stb         : std_logic;
  signal wb_cyc         : std_logic;
  signal wb_ack         : std_logic;
  signal wb_irq         : std_logic;

  signal pci_ad_out     : std_logic_vector(31 downto 0);
  signal pci_ad_oe      : std_logic;
  signal pci_par_out    : std_logic;
  signal pci_par_oe     : std_logic;
  signal pci_trdy_out   : std_logic;
  signal pci_devsel_out : std_logic;
  signal pci_stop_out   : std_logic;
  signal pci_targ_oe    : std_logic;
  signal pci_perr_drv   : std_logic;
  signal pci_serr_drv   : std_logic;
  signal pci_inta_drv   : std_logic;
  signal pci_req_drv    : std_logic;

  signal mds_cs         : std_logic;
  signal mds_stb        : std_logic;
  signal mds_stb_wr     : std_logic;
  signal mds_stb_rd     : std_logic;
  signal mds_ack        : std_logic;
  signal mds_oe         : std_logic;
  signal mds_run        : std_logic;
  signal mds_addr       : std_logic_vector(15 downto 2);
  signal mds_datrd      : std_logic_vector(31 downto 0);
  signal mds_datrd1     : std_logic_vector(31 downto 0);
  signal mds_datrd2     : std_logic_vector(31 downto 0);
  signal mds_datrd3     : std_logic_vector(31 downto 0);
  signal mds_datrd4     : std_logic_vector(31 downto 0);
  signal mds_datrd5     : std_logic_vector(31 downto 0);
  signal mds_datrd6     : std_logic_vector(31 downto 0);
  signal mds_datrd7     : std_logic_vector(31 downto 0);
  signal mds_datrd8     : std_logic_vector(31 downto 0);

begin

  ----------------------------------------------------------
  -- Clock & Reset
  ----------------------------------------------------------

  wb_rst <= (not rst_n) or (not dcm_locked);
  U_CLKPCI_IBUFG : IBUFG port map ( I => pclk, O => wb_clk);
  U_CLK32_IBUFG : IBUFG port map ( I => onboard_clock, O => clk32ib);

  U_DCM : DCM
    generic map(
      CLKDV_DIVIDE => 4.0,
      CLKFX_DIVIDE => 8,
      CLKFX_MULTIPLY => 25,
      CLKIN_PERIOD => 31.250,
      FACTORY_JF => x"8080"
    )
    port map (
      CLKFB    => clk32,
      CLKIN    => clk32ib,
      DSSEN    => '0',
      PSCLK    => '0',
      PSEN     => '0',
      PSINCDEC => '0',
      RST      => not rst_n,
      CLKDV    => clk8ob,
      CLK0     => clk32ob,
      CLKFX    => clk100ob,
      LOCKED   => dcm_locked
    );

  U_CLK32_BUFG : BUFG port map ( I => clk32ob, O => clk32);
  U_CLK8_BUFG : BUFG port map ( I => clk8ob, O => clk8);
  U_CLK100_BUFG : BUFG port map ( I => clk100ob, O => clk100);

  p_sclk: process(wb_rst, wb_clk)
  begin
    if (wb_rst = '1') then
      sclk_cnt <= (others => '0');
    elsif rising_edge(wb_clk) then
      sclk_cnt <= sclk_cnt + 1;
    end if;
  end process;
  sclk_edge  <= '1' when sclk_cnt(3 downto 0) = 0 else '0';
  sclk_state <= sclk_cnt(4);

  ----------------------------------------------------------
  -- PCI <--> Whisbone Bridge
  ----------------------------------------------------------

  -- PCI Interface
  U_PCI: entity work.pci32tLite 
    generic map (
      vendorID     => x"4150",
      deviceID     => x"0007",
      revisionID   => x"00",
      subsystemID  => x"0202",
      subsystemvID => x"1172",
      classcodeID  => x"068000",  
      BARS         => BARS,
      WBSIZE       => WBSIZE,
      WBENDIAN     => WBENDIAN
    )
    port map (
      --General 
      clk33        => wb_clk,      
      rst          => wb_rst,           
      -- PCI target 32bits
      ad_in        => ad,  
      ad_out       => pci_ad_out,  
      ad_oe        => pci_ad_oe,  
      cbe          => cbe_n,
      par_in       => par,    
      par_out      => pci_par_out,
      par_oe       => pci_par_oe,
      frame        => frame_n,
      irdy         => irdy_n,
      trdy_out     => pci_trdy_out,
      devsel_out   => pci_devsel_out,
      stop_out     => pci_stop_out,
      targ_oe      => pci_targ_oe,
      idsel        => idsel,
      perr_drv     => pci_perr_drv,
      serr_drv     => pci_serr_drv,
      inta_drv     => pci_inta_drv,
      req_drv      => pci_req_drv,
      gnt          => gnt_n,
      -- Master whisbone
      wb_adr_o     => wb_adr,    
      wb_dat_i     => wb_datrd,
      wb_dat_o     => wb_datwr,
      wb_sel_o     => wb_sel, 
      wb_we_o      => wb_we, 
      wb_stb_o     => wb_stb, 
      wb_cyc_o     => wb_cyc, 
      wb_ack_i     => wb_ack, 
      wb_rty_i     => '0', 
      wb_err_i     => '0',
      wb_int_i     => wb_irq
    );

  -- pci open drain / tristate
  ad       <= pci_ad_out when pci_ad_oe = '1' else (others => 'Z');
  par      <= pci_par_out when pci_par_oe = '1' else 'Z';
  trdy_n   <= pci_trdy_out when pci_targ_oe = '1' else 'Z';
  devsel_n <= pci_devsel_out when pci_targ_oe = '1' else 'Z';
  stop_n   <= pci_stop_out  when pci_targ_oe = '1' else 'Z';
  perr_n   <= '0' when pci_perr_drv = '1' else 'Z';
  serr_n   <= '0' when pci_serr_drv = '1' else 'Z';
  inta_n   <= '0' when pci_inta_drv = '1' else 'Z';
  req_n    <= '0' when pci_req_drv  = '1' else 'Z';

  -- irq handling
  wb_irq <= '0';

  -- whichbone ack
  wb_ack <= mds_ack;

  ----------------------------------------------------------
  -- mdsio whisbone adapter
  ----------------------------------------------------------

  mds_cs     <= '1' when ((wb_stb = '1') and (wb_cyc = '1')) else '0';
  mds_stb    <= '1' when mds_cs = '1' and wb_ack = '0' else '0'; 
  mds_stb_rd <= '1' when mds_stb = '1' and wb_we = '0' else '0';
  mds_stb_wr <= '1' when mds_stb = '1' and wb_we = '1' else '0';

  P_MDS_WB_ACK : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      mds_ack <= '0';
    elsif rising_edge(wb_clk) then
      mds_ack <= mds_cs;
    end if;
  end process;

  wb_datrd <= mds_datrd;
  mds_addr <= wb_adr(15 downto 2);

  ----------------------------------------------------------
  -- mdsio instances
  ----------------------------------------------------------

  U_DIO_MOD0: entity work.DIO_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000000",
      WB_ADDR_OFFSET => "00000000001001"
    )
    port map (
      OUT_EN      => mds_oe,
      SCLK_EDGE   => sclk_edge,
      SCLK_STATE  => sclk_state,

      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd1,
      WB_DATA_IN  => wb_datwr,
      WB_STB_RD   => mds_stb_rd,
      WB_STB_WR   => mds_stb_wr,

      SV          => SV1
    );

  U_DAC_MOD0: entity work.DAC_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000001",
      WB_ADDR_OFFSET => "00000000001011"
    )
    port map (
      OUT_EN      => mds_oe,
      SCLK_EDGE   => sclk_edge,
      SCLK_STATE  => sclk_state,

      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd2,
      WB_DATA_IN  => wb_datwr,
      WB_STB_RD   => mds_stb_rd,
      WB_STB_WR   => mds_stb_wr,

      SV          => SV2
    );

  U_PHPE_MOD0: entity work.PHPE_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000010",
      WB_ADDR_OFFSET => "00000000001110"
    )
    port map (
      CLK100      => clk100,

      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd3,
      WB_DATA_IN  => wb_datwr,
      WB_STB_RD   => mds_stb_rd,
      WB_STB_WR   => mds_stb_wr,

      SV          => SV3
    );

  U_PHPE_MOD1: entity work.PHPE_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000011",
      WB_ADDR_OFFSET => "00000000011101"
    )
    port map (
      CLK100      => clk100,

      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd4,
      WB_DATA_IN  => wb_datwr,
      WB_STB_RD   => mds_stb_rd,
      WB_STB_WR   => mds_stb_wr,

      SV          => SV4
    );

  U_ENC_MOD0: entity work.ENC_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000100",
      WB_ADDR_OFFSET => "00000000101100"
    )
    port map (
      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd5,
      WB_STB_RD   => mds_stb_rd,

      SV          => SV5
    );

  U_ENC_MOD1: entity work.ENC_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000101",
      WB_ADDR_OFFSET => "00000000110011"
    )
    port map (
      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd6,
      WB_STB_RD   => mds_stb_rd,

      SV          => SV6
    );

  U_STEP_MOD0: entity work.STEP_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000110",
      WB_ADDR_OFFSET => "00000000111010"
    )
    port map (
      OUT_EN      => mds_oe,

      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd7,
      WB_DATA_IN  => wb_datwr,
      WB_STB_RD   => mds_stb_rd,
      WB_STB_WR   => mds_stb_wr,

      SV          => SV7
    );

  U_WDT_MOD0: entity work.WDT_MOD
    generic map (
      WB_CONF_OFFSET => "00000000000111",
      WB_ADDR_OFFSET => "00000001001110"
    )
    port map (
      WB_CLK      => wb_clk,
      WB_RST      => wb_rst,
      WB_ADDR     => mds_addr,
      WB_DATA_OUT => mds_datrd8,
      WB_DATA_IN  => wb_datwr,
      WB_STB_RD   => mds_stb_rd,
      WB_STB_WR   => mds_stb_wr,

      RUN         => mds_run,
      OUT_EN      => mds_oe
    );

  mds_datrd <= mds_datrd1 or mds_datrd2 or mds_datrd3 or mds_datrd4 or mds_datrd5 or mds_datrd6 or mds_datrd7 or mds_datrd8;

  ----------------------------------------------------------
  -- Debug Stuff
  ----------------------------------------------------------

  can1_tx <= '0';
  can2_tx <= '0';

  SV8 <= (others => '0');
  SV9 <= (others => '0');

  LED_CONF <= '1';
  LED_RUN  <= mds_run;


end rtl;

