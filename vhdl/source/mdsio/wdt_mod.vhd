library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity WDT_MOD is
  generic (
    -- IO-REQ: 1 DWORD
    WB_CONF_OFFSET: std_logic_vector(15 downto 2) := "00000000000000";
    WB_CONF_DATA:   std_logic_vector(15 downto 0) := "0000000000000001";
    WB_ADDR_OFFSET: std_logic_vector(15 downto 2) := "00000000000000"
  );
  port (
    WB_CLK: in std_logic;
    WB_RST: in std_logic;
    WB_ADDR: in std_logic_vector(15 downto 2);
    WB_DATA_OUT: out std_logic_vector(31 downto 0);
    WB_DATA_IN: in std_logic_vector(31 downto 0);
    WB_STB_RD: in std_logic;
    WB_STB_WR: in std_logic;

    RUN: out std_logic;
    OUT_EN: out std_logic
  );
end;

architecture rtl of WDT_MOD is
  constant RAND_SEED: std_logic_vector(15 downto 0) := "1111111111111000";

  signal wb_data_mux : std_logic_vector(31 downto 0);

  signal rand: std_logic_vector(15 downto 0) := RAND_SEED;
  signal rand_ok: std_logic;
  signal out_en_reg: std_logic;

  signal timer: std_logic_vector(19 downto 0);
  signal timeout: std_logic;

  signal cycle_cnt: std_logic_vector(3 downto 0) := (others => '1');
  signal cycle_ok: std_logic;

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
        wb_data_mux <= (others => '0');
        wb_data_mux(15 downto 0) <= rand;
        wb_data_mux(16) <= out_en_reg;
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
      out_en_reg <= '0';
      rand <= RAND_SEED;
      rand_ok <= '0';
    elsif rising_edge(WB_CLK) then
      rand_ok <= '0';
      if WB_STB_WR = '1' then
        case WB_ADDR is
          when WB_ADDR_OFFSET =>
            out_en_reg <= WB_DATA_IN(16);
            if (WB_DATA_IN(15 downto 0) = rand) then
              rand_ok <= '1';
            end if;
            rand <= rand(14 downto 0) & (rand(15) xor rand(10));
          when others =>
        end case;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- watchdog
  ----------------------------------------------------------

  -- Timeout
  P_WDT: process(WB_RST, WB_CLK)
  begin
    if WB_RST = '1' then
      timer <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if rand_ok = '1' then
        timer <= (others => '1');
      elsif timeout = '0' then
        timer <= timer - 1;
      end if;
    end if;
  end process;
  timeout <= '1' when timer = 0 else '0';

  -- initial cycle counter
  P_CYCLE_CNT: process(WB_RST, WB_CLK)
  begin
    if WB_RST = '1' then
      cycle_cnt <= (others => '1');
    elsif rising_edge(WB_CLK) then
      if timeout = '1' then
        cycle_cnt <= (others => '1');
      elsif rand_ok = '1' and cycle_ok = '0' then
        cycle_cnt <= cycle_cnt - 1;
      end if;
    end if;
  end process;
  cycle_ok <= '1' when cycle_cnt = 0 else '0';

  -- set outputs
  RUN <= cycle_ok;
  OUT_EN <= out_en_reg and cycle_ok;

end;

