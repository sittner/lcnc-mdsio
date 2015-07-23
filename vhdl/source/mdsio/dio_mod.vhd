library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity DIO_MOD is
  generic (
    -- IO-REQ: 2 DWORD
    WB_CONF_OFFSET: std_logic_vector(15 downto 2) := "00000000000000";
    WB_CONF_DATA:   std_logic_vector(15 downto 0) := "0000000000000010";
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

architecture rtl of DIO_MOD is

  constant OUT_TEST_PATTERN: std_logic_vector(7 downto 0) := "10110010";
  constant IN_TEST_PATTERN:  std_logic_vector(7 downto 0) := "10101100";

  signal wb_data_mux : std_logic_vector(31 downto 0);

  signal shift_cnt: std_logic_vector(5 downto 0);
  signal bitcnt_sync: std_logic;
  signal bitcnt_top: std_logic;

  signal ssync: std_logic;
  signal sclk: std_logic;

  signal output_fault: std_logic;
  signal output_fault_in: std_logic;
  signal output_fault_sync: std_logic_vector(1 downto 0);
  signal output_fault_dly: std_logic_vector(9 downto 0) := (others => '1');

  signal si_out: std_logic;
  signal so_out: std_logic;
  signal so_out_data: std_logic_vector(39 downto 0);
  signal so_out_shift: std_logic_vector(47 downto 0);
  signal si_out_shift: std_logic_vector(7 downto 0);
  signal out_data_error: std_logic;

  signal si_in: std_logic;
  signal so_in: std_logic;
  signal so_in_shift: std_logic_vector(7 downto 0);
  signal si_in_shift: std_logic_vector(47 downto 0);
  signal si_in_data: std_logic_vector(39 downto 0);
  signal in_data_error: std_logic;

  signal output_fault_reg: std_logic;
  signal out_data_error_reg: std_logic;
  signal in_data_error_reg: std_logic;

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
        wb_data_mux <= si_in_data(31 downto 0);
      when WB_ADDR_OFFSET + 1 =>
        wb_data_mux <= (others => '0');
        wb_data_mux(7 downto 0) <= si_in_data(39 downto 32);
        wb_data_mux(16) <= output_fault_reg;
        wb_data_mux(17) <= out_data_error_reg;
        wb_data_mux(18) <= in_data_error_reg;
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
      so_out_data <= (others => '0');
      output_fault_reg <= '0';
      out_data_error_reg <= '0';
      in_data_error_reg <= '0';
    elsif rising_edge(WB_CLK) then
      -- reset error flags when  output is disabled
      if OUT_EN = '0' then
        so_out_data <= (others => '0');
        output_fault_reg <= '0';
        out_data_error_reg <= '0';
        in_data_error_reg <= '0';
      end if; 

      -- set error flags on error
      if output_fault = '1' then
        output_fault_reg <= '1';
      end if;
      if out_data_error = '1' then
        out_data_error_reg <= '1';
      end if;
      if in_data_error = '1' then
        in_data_error_reg <= '1';
      end if;

      if WB_STB_WR = '1' then
        case WB_ADDR is
          when WB_ADDR_OFFSET =>
            so_out_data(31 downto 0) <= WB_DATA_IN;
          when WB_ADDR_OFFSET + 1 =>
            so_out_data(39 downto 32) <= WB_DATA_IN(7 downto 0);
            if WB_DATA_IN(16) = '1' then
              output_fault_reg <= '0';
            end if;
            if WB_DATA_IN(17) = '1' then
              out_data_error_reg <= '0';
            end if;
            if WB_DATA_IN(18) = '1' then
              in_data_error_reg <= '0';
            end if;      
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
      sclk  <= '1';
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' then
        ssync <= '0';
        sclk  <= '1';
        if SCLK_STATE = '1' then
          if bitcnt_sync = '1' then
            ssync <= '1';
          else
            sclk  <= '0';
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
  bitcnt_sync <= '1' when shift_cnt = 47 else '0'; 
  bitcnt_top  <= '1' when shift_cnt = 48 else '0'; 

  ----------------------------------------------------------
  --- output shift registers
  ----------------------------------------------------------
  p_so_out_shift: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      so_out_shift <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '0' then
        if bitcnt_top = '1' then
          so_out_shift <= OUT_TEST_PATTERN & so_out_data;
        else
          so_out_shift <= so_out_shift(46 downto 0) & "1";
        end if;
      end if;
    end if;
  end process;
  so_out <= so_out_shift(47);

  p_si_out_shift: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      si_out_shift <= (others => '0');
      out_data_error <= '0';
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '0' then
        if bitcnt_sync = '1' then
          if si_out_shift /= OUT_TEST_PATTERN then
            out_data_error <= '1';
          else
            out_data_error <= '0';
          end if;
          si_out_shift <= (others => '0');
        else
          si_out_shift <= si_out_shift(6 downto 0) & si_out;
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- input shift registers
  ----------------------------------------------------------
  p_so_in_shift: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      so_in_shift <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '0' then
        if bitcnt_top = '1' then
          so_in_shift <= IN_TEST_PATTERN;
        else
          so_in_shift <= so_in_shift(6 downto 0) & "0";
        end if;
      end if;
    end if;
  end process;
  so_in <= so_in_shift(7);

  p_si_in_shift: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      si_in_data  <= (others => '0');
      si_in_shift <= (others => '0');
      in_data_error <= '0';
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '0' then
        if bitcnt_sync = '1' then
          if si_in_shift(7 downto 0) /= IN_TEST_PATTERN then
            in_data_error <= '1';
          else
            in_data_error <= '0';
            si_in_data <= si_in_shift(47 downto 8);
          end if;
          si_in_shift <= (others => '0');
        else
          si_in_shift <= si_in_shift(46 downto 0) & si_in;
        end if;
      end if;
    end if;
  end process;


  ----------------------------------------------------------
  --- output fault delay
  ----------------------------------------------------------
  p_output_fault_sync: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      output_fault_sync <= (others => '0');
    elsif rising_edge(WB_CLK) then
      output_fault_sync <= output_fault_in & output_fault_sync(1);
    end if;
  end process;

  p_output_fault_dly: process(WB_CLK, WB_RST)
  begin
    if (WB_RST = '1') then
      output_fault_dly <= (others => '1');
    elsif rising_edge(WB_CLK) then
      if SCLK_EDGE = '1' and SCLK_STATE = '0' then
        if output_fault_sync(0) = '1' then
          if output_fault = '0' then
            output_fault_dly <= output_fault_dly - 1;
          end if;
        else
          output_fault_dly <= (others => '1');
        end if;
      end if;
    end if;
  end process;

  output_fault <= '1' when output_fault_dly = 0 else '0';

  ----------------------------------------------------------
  --- output mapping
  ----------------------------------------------------------
  output_fault_in <= not SV(3);
  si_in  <= SV(5);
  si_out <= not SV(6);
  SV(4)  <= OUT_EN;
  SV(7)  <= ssync;
  SV(8)  <= sclk;
  SV(9)  <= so_in;
  SV(10) <= not so_out;

end;
