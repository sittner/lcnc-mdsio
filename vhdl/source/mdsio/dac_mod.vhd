library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity DAC_MOD is
  generic (
    -- IO-REQ: 3 DWORD
    WB_CONF_OFFSET: std_logic_vector(15 downto 2) := "00000000000000";
    WB_CONF_DATA:   std_logic_vector(15 downto 0) := "0000000000000011";
    WB_ADDR_OFFSET: std_logic_vector(15 downto 2) := "00000000000000"
  );
  port (
    OUT_EN: in std_logic;
    SCLK_EDGE: in std_logic;
    SCLK_STATE: in std_logic;

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

architecture rtl of DAC_MOD is

  constant CMD_WriteA:        std_logic_vector(7 downto 0) := "00000000";
  constant CMD_WriteB_LoadAB: std_logic_vector(7 downto 0) := "00110100";

  signal wb_data_mux : std_logic_vector(31 downto 0);

  signal shift_cnt: std_logic_vector(4 downto 0);
  signal bitcnt_sync: std_logic;
  signal bitcnt_top: std_logic;

  signal dac1_data: std_logic_vector(15 downto 0);
  signal dac2_data: std_logic_vector(15 downto 0);
  signal dac2_reg: std_logic_vector(15 downto 0);
  signal dac3_data: std_logic_vector(15 downto 0);
  signal dac4_data: std_logic_vector(15 downto 0);
  signal dac4_reg: std_logic_vector(15 downto 0);
  signal dac5_data: std_logic_vector(15 downto 0);
  signal dac6_data: std_logic_vector(15 downto 0);
  signal dac6_reg: std_logic_vector(15 downto 0);

  signal ssync: std_logic;
  signal sclk: std_logic;

  signal select_ab: std_logic;
  signal dac12_shift: std_logic_vector(23 downto 0);
  signal dac34_shift: std_logic_vector(23 downto 0);
  signal dac56_shift: std_logic_vector(23 downto 0);
begin

  ----------------------------------------------------------
  --- bus logic
  ----------------------------------------------------------
  P_WB_RD : process(WB_ADDR)
  begin
    case WB_ADDR is
      when WB_CONF_OFFSET =>
        wb_data_mux(15 downto 0) <= WB_CONF_DATA;
        wb_data_mux(31 downto 16) <= WB_ADDR_OFFSET & "00";
      when WB_ADDR_OFFSET =>
        wb_data_mux(15 downto 0)  <= dac1_data;
        wb_data_mux(31 downto 16) <= dac2_data;
      when WB_ADDR_OFFSET + 1 =>
        wb_data_mux(15 downto 0)  <= dac3_data;
        wb_data_mux(31 downto 16) <= dac4_data;
      when WB_ADDR_OFFSET + 2 =>
        wb_data_mux(15 downto 0)  <= dac5_data;
        wb_data_mux(31 downto 16) <= dac6_data;
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
      dac1_data <= (others => '0');
      dac2_data <= (others => '0');
      dac3_data <= (others => '0');
      dac4_data <= (others => '0');
      dac5_data <= (others => '0');
      dac6_data <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if WB_STB_WR = '1' then
        case WB_ADDR is
          when WB_ADDR_OFFSET =>
            dac1_data <= WB_DATA_IN(15 downto 0);
            dac2_data <= WB_DATA_IN(31 downto 16);
          when WB_ADDR_OFFSET + 1 =>
            dac3_data <= WB_DATA_IN(15 downto 0);
            dac4_data <= WB_DATA_IN(31 downto 16);
          when WB_ADDR_OFFSET + 2 =>
            dac5_data <= WB_DATA_IN(15 downto 0);
            dac6_data <= WB_DATA_IN(31 downto 16);
          when others =>
        end case;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- serial clock
  ----------------------------------------------------------
  p_sclk: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      ssync <= '0';
      sclk  <= '0';
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' then
        ssync <= '0';
        sclk  <= '0';
        if SCLK_STATE = '0' then
          if bitcnt_sync = '1' then
            ssync <= '1';
          else
            sclk  <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- shift counter
  ----------------------------------------------------------
  p_bitcnt_cnt: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      shift_cnt <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '1' then
        if bitcnt_top = '1' then
          shift_cnt <= (others => '0');
        else
          shift_cnt <= shift_cnt + 1;
        end if;
      end if;
    end if;
  end process;
  bitcnt_sync <= '1' when shift_cnt = 23 else '0'; 
  bitcnt_top  <= '1' when shift_cnt = 24 else '0'; 

  ----------------------------------------------------------
  --- output shift
  ----------------------------------------------------------
  p_so_out_shift: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      dac12_shift <= (others => '0');
      dac34_shift <= (others => '0');
      dac56_shift <= (others => '0');
      dac2_reg <= (others => '0');
      dac4_reg <= (others => '0');
      dac6_reg <= (others => '0');
      select_ab <= '0';
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '0' then
        if bitcnt_top = '1' then
          if select_ab = '0' then
            dac12_shift <= CMD_WriteA & dac1_data;
            dac34_shift <= CMD_WriteA & dac3_data;
            dac56_shift <= CMD_WriteA & dac5_data;
            dac2_reg <= dac2_data;
            dac4_reg <= dac4_data;
            dac6_reg <= dac6_data;
          else
            dac12_shift <= CMD_WriteB_LoadAB & dac2_reg;
            dac34_shift <= CMD_WriteB_LoadAB & dac4_reg;
            dac56_shift <= CMD_WriteB_LoadAB & dac6_reg;
          end if;
          select_ab <= not select_ab;
        else
          dac12_shift <= dac12_shift(22 downto 0) & "1";
          dac34_shift <= dac34_shift(22 downto 0) & "1";
          dac56_shift <= dac56_shift(22 downto 0) & "1";
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- output mapping
  ----------------------------------------------------------
  SV(3)  <= '0';
  SV(4)  <= '0';
  SV(5)  <= not ssync;
  SV(6)  <= not sclk;
  SV(7)  <= not dac56_shift(23);
  SV(8)  <= not dac34_shift(23);
  SV(9)  <= not dac12_shift(23);
  SV(10) <= OUT_EN;

end;
