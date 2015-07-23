library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity STEP_MOD is
  generic (
    -- IO-REQ: 19 DWORD
    WB_CONF_OFFSET: std_logic_vector(15 downto 2) := "00000000000000";
    WB_CONF_DATA:   std_logic_vector(15 downto 0) := "0000000000000101";
    WB_ADDR_OFFSET: std_logic_vector(15 downto 2) := "00000000000000"
  );
  port (
    OUT_EN: in std_logic;
    IDLE: out std_logic;

    WB_CLK: in std_logic;
    WB_RST: in std_logic;
    WB_ADDR: in std_logic_vector(15 downto 2);
    WB_DATA_OUT: out std_logic_vector(31 downto 0);
    WB_DATA_IN: in std_logic_vector(31 downto 0);
    WB_STB_RD: in std_logic;
    WB_STB_WR: in std_logic;

    SV : inout std_logic_vector(10 downto 3)
  );
end;

architecture rtl of STEP_MOD is

  signal wb_data_mux : std_logic_vector(31 downto 0);

  signal step_len: std_logic_vector(31 downto 0);
  signal dir_hold_dly: std_logic_vector(31 downto 0);
  signal dir_setup_dly: std_logic_vector(31 downto 0);

  signal targetvel_a: std_logic_vector(31 downto 0);
  signal deltalim_a: std_logic_vector(31 downto 0);
  signal pos_capt_a: std_logic;
  signal pos_hi_a: std_logic_vector(31 downto 0);
  signal pos_lo_a: std_logic_vector(31 downto 0);
  signal idle_a: std_logic;

  signal targetvel_b: std_logic_vector(31 downto 0);
  signal deltalim_b: std_logic_vector(31 downto 0);
  signal pos_capt_b: std_logic;
  signal pos_hi_b: std_logic_vector(31 downto 0);
  signal pos_lo_b: std_logic_vector(31 downto 0);
  signal idle_b: std_logic;

  signal targetvel_c: std_logic_vector(31 downto 0);
  signal deltalim_c: std_logic_vector(31 downto 0);
  signal pos_capt_c: std_logic;
  signal pos_hi_c: std_logic_vector(31 downto 0);
  signal pos_lo_c: std_logic_vector(31 downto 0);
  signal idle_c: std_logic;

  signal targetvel_d: std_logic_vector(31 downto 0);
  signal deltalim_d: std_logic_vector(31 downto 0);
  signal pos_capt_d: std_logic;
  signal pos_hi_d: std_logic_vector(31 downto 0);
  signal pos_lo_d: std_logic_vector(31 downto 0);
  signal idle_d: std_logic;

begin
  ----------------------------------------------------------
  --- bus logic
  ----------------------------------------------------------
  P_WB_RD : process(WB_ADDR)
  begin
    pos_capt_a <= '0';
    pos_capt_b <= '0';
    pos_capt_c <= '0';
    pos_capt_d <= '0';
    case WB_ADDR is
      when WB_CONF_OFFSET =>
        wb_data_mux(15 downto 0) <= WB_CONF_DATA;
        wb_data_mux(31 downto 16) <= WB_ADDR_OFFSET & "00";
      when WB_ADDR_OFFSET =>
        wb_data_mux <= step_len;
      when WB_ADDR_OFFSET + 1 =>
        wb_data_mux <= dir_hold_dly;
      when WB_ADDR_OFFSET + 2 =>
        wb_data_mux <= dir_setup_dly;
      when WB_ADDR_OFFSET + 3 =>
        wb_data_mux <= targetvel_a;
      when WB_ADDR_OFFSET + 4 =>
        wb_data_mux <= deltalim_a;
      when WB_ADDR_OFFSET + 5 =>
        pos_capt_a <= WB_STB_RD;
        wb_data_mux <= pos_hi_a;
      when WB_ADDR_OFFSET + 6 =>
        wb_data_mux <= pos_lo_a;
      when WB_ADDR_OFFSET + 7 =>
        wb_data_mux <= targetvel_b;
      when WB_ADDR_OFFSET + 8 =>
        wb_data_mux <= deltalim_b;
      when WB_ADDR_OFFSET + 9 =>
        pos_capt_b <= WB_STB_RD;
        wb_data_mux <= pos_hi_b;
      when WB_ADDR_OFFSET + 10 =>
        wb_data_mux <= pos_lo_b;
      when WB_ADDR_OFFSET + 11 =>
        wb_data_mux <= targetvel_c;
      when WB_ADDR_OFFSET + 12 =>
        wb_data_mux <= deltalim_c;
      when WB_ADDR_OFFSET + 13 =>
        pos_capt_c <= WB_STB_RD;
        wb_data_mux <= pos_hi_c;
      when WB_ADDR_OFFSET + 14 =>
        wb_data_mux <= pos_lo_c;
      when WB_ADDR_OFFSET + 15 =>
        wb_data_mux <= targetvel_d;
      when WB_ADDR_OFFSET + 16 =>
        wb_data_mux <= deltalim_d;
      when WB_ADDR_OFFSET + 17 =>
        pos_capt_d <= WB_STB_RD;
        wb_data_mux <= pos_hi_d;
      when WB_ADDR_OFFSET + 18 =>
        wb_data_mux <= pos_lo_d;
      when others => 
        wb_data_mux <= (others => '0');
    end case;
  end process;

  P_WB_RD_REG : process(WB_RST, WB_CLK)
  begin
    if WB_RST = '1' then
      WB_DATA_OUT <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if WB_STB_RD = '1' then
        WB_DATA_OUT <= wb_data_mux;
      end if;
    end if;
  end process;

  P_PE_REG_WR : process(WB_RST, WB_CLK)
  begin
    if WB_RST = '1' then
      step_len <= (others => '0');
      dir_hold_dly <= (others => '0');
      dir_setup_dly <= (others => '0');
      targetvel_a <= (others => '0');
      deltalim_a <= (others => '0');
      targetvel_b <= (others => '0');
      deltalim_b <= (others => '0');
      targetvel_c <= (others => '0');
      deltalim_c <= (others => '0');
      targetvel_d <= (others => '0');
      deltalim_d <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if WB_STB_WR = '1' then
        case WB_ADDR is
          when WB_ADDR_OFFSET =>
            step_len <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 1 =>
            dir_hold_dly <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 2 =>
            dir_setup_dly <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 3 =>
            targetvel_a <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 4 =>
            deltalim_a <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 7 =>
            targetvel_b <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 8 =>
            deltalim_b <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 11 =>
            targetvel_c <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 12 =>
            deltalim_c <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 15 =>
            targetvel_d <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 16 =>
            deltalim_d <= WB_DATA_IN;
          when others =>
        end case;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- stepgen instances
  ----------------------------------------------------------

  IDLE <= idle_a and idle_b and idle_c and idle_d;

  U_STEP_A: entity work.STEP_CHAN
    port map (
      RESET => WB_RST,
      CLK => WB_CLK,

      pos_capt => pos_capt_a,
      pos_hi => pos_hi_a,
      pos_lo => pos_lo_a,

      targetvel => targetvel_a,
      deltalim => deltalim_a,
      step_len => step_len,
      dir_hold_dly => dir_hold_dly,
      dir_setup_dly => dir_setup_dly,

      OUT_EN => OUT_EN,
      IDLE => idle_a,

      STP_OUT => SV(10),
      STP_DIR => SV(9)
    );
 
  U_STEP_B: entity work.STEP_CHAN
    port map (
      RESET => WB_RST,
      CLK => WB_CLK,

      pos_capt => pos_capt_b,
      pos_hi => pos_hi_b,
      pos_lo => pos_lo_b,

      targetvel => targetvel_b,
      deltalim => deltalim_b,
      step_len => step_len,
      dir_hold_dly => dir_hold_dly,
      dir_setup_dly => dir_setup_dly,

      OUT_EN => OUT_EN,
      IDLE => idle_b,

      STP_OUT => SV(8),
      STP_DIR => SV(7)
    );
 
  U_STEP_C: entity work.STEP_CHAN
    port map (
      RESET => WB_RST,
      CLK => WB_CLK,

      pos_capt => pos_capt_c,
      pos_hi => pos_hi_c,
      pos_lo => pos_lo_c,

      targetvel => targetvel_c,
      deltalim => deltalim_c,
      step_len => step_len,
      dir_hold_dly => dir_hold_dly,
      dir_setup_dly => dir_setup_dly,

      OUT_EN => OUT_EN,
      IDLE => idle_c,

      STP_OUT => SV(6),
      STP_DIR => SV(5)
    );
 
  U_STEP_D: entity work.STEP_CHAN
    port map (
      RESET => WB_RST,
      CLK => WB_CLK,

      pos_capt => pos_capt_d,
      pos_hi => pos_hi_d,
      pos_lo => pos_lo_d,

      targetvel => targetvel_d,
      deltalim => deltalim_d,
      step_len => step_len,
      dir_hold_dly => dir_hold_dly,
      dir_setup_dly => dir_setup_dly,

      OUT_EN => OUT_EN,
      IDLE => idle_d,

      STP_OUT => SV(4),
      STP_DIR => SV(3)
    );

end;
