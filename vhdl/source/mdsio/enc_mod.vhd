library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity ENC_MOD is
  generic (
    -- IO-REQ: 7 DWORD
    WB_CONF_OFFSET: std_logic_vector(15 downto 2) := "00000000000000";
    WB_CONF_DATA:   std_logic_vector(15 downto 0) := "0000000000000100";
    WB_ADDR_OFFSET: std_logic_vector(15 downto 2) := "00000000000000"
  );
  port (
    WB_CLK: in std_logic;
    WB_RST: in std_logic;
    WB_ADDR: in std_logic_vector(15 downto 2);
    WB_DATA_OUT: out std_logic_vector(31 downto 0);
    WB_STB_RD: in std_logic;

    SV : inout std_logic_vector(10 downto 3)
  );
end;

architecture rtl of ENC_MOD is
  signal wb_data_mux : std_logic_vector(31 downto 0);

  signal capture: std_logic;
  signal timestamp: std_logic_vector(31 downto 0);

  signal cnt_reg_a: std_logic_vector(31 downto 0);
  signal ts_reg_a: std_logic_vector(31 downto 0);
  signal idx_reg_a: std_logic_vector(31 downto 0);
  signal cnt_reg_b: std_logic_vector(31 downto 0);
  signal ts_reg_b: std_logic_vector(31 downto 0);
  signal idx_reg_b: std_logic_vector(31 downto 0);

begin

  ----------------------------------------------------------
  --- bus logic
  ----------------------------------------------------------
  P_WB_RD : process(WB_ADDR, WB_STB_RD, timestamp, cnt_reg_a, idx_reg_a, cnt_reg_b, idx_reg_b)
  begin
    capture <= '0';
    case WB_ADDR is
      when WB_CONF_OFFSET =>
        wb_data_mux(15 downto 0) <= WB_CONF_DATA;
        wb_data_mux(31 downto 16) <= WB_ADDR_OFFSET & "00";
      when WB_ADDR_OFFSET =>
        capture <= WB_STB_RD;
        wb_data_mux <= timestamp;
      when WB_ADDR_OFFSET + 1 =>
        wb_data_mux <= cnt_reg_a;
      when WB_ADDR_OFFSET + 2 =>
        wb_data_mux <= ts_reg_a;
      when WB_ADDR_OFFSET + 3 =>
        wb_data_mux <= idx_reg_a;
      when WB_ADDR_OFFSET + 4 =>
        wb_data_mux <= cnt_reg_b;
      when WB_ADDR_OFFSET + 5 =>
        wb_data_mux <= ts_reg_b;
      when WB_ADDR_OFFSET + 6 =>
        wb_data_mux <= idx_reg_b;
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

  ----------------------------------------------------------
  --- timestamp generator
  ----------------------------------------------------------
  timestamp_proc: process(WB_RST, WB_CLK)
  begin
    if WB_RST = '1' then
      timestamp <= (others => '0');
    elsif rising_edge(WB_CLK) then
      timestamp <= timestamp + 1;
    end if;
  end process;

  ----------------------------------------------------------
  --- encoder instances
  ----------------------------------------------------------
  U_ENC_A: entity work.ENC_CHAN
    port map (
      RESET => WB_RST,
      CLK => WB_CLK,
      CAPTURE => capture,

      TIMESTAMP => timestamp,

      CNT_REG => cnt_reg_a,
      TS_REG => ts_reg_a,
      IDX_REG => idx_reg_a,

      ENC_A => not SV(10),
      ENC_B => not SV(8),
      ENC_I => not SV(6)
    );

  U_ENC_B: entity work.ENC_CHAN
    port map (
      RESET => WB_RST,
      CLK => WB_CLK,
      CAPTURE => capture,

      TIMESTAMP => timestamp,

      CNT_REG => cnt_reg_b,
      TS_REG => ts_reg_b,
      IDX_REG => idx_reg_b,

      ENC_A => not SV(9),
      ENC_B => not SV(7),
      ENC_I => not SV(5)
    );

  -- hold unused pins to GND
  SV(4 downto 3) <= (others => '0');

end;
