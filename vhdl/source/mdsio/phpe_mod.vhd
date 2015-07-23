library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity PHPE_MOD is
  generic (
    -- IO-REQ: 15 DWORD
    WB_CONF_OFFSET: std_logic_vector(15 downto 2) := "00000000000000";
    WB_CONF_DATA:   std_logic_vector(15 downto 0) := "0000000000000110";
    WB_ADDR_OFFSET: std_logic_vector(15 downto 2) := "00000000000000"
  );
  port (
    CLK100: in std_logic;

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

architecture rtl of PHPE_MOD is
  signal wb_data_mux : std_logic_vector(31 downto 0);

  signal pe_reg_top   : std_logic_vector(15 downto 0);
  signal pe_reg_scan  : std_logic_vector(15 downto 0);
  signal pe_reg_disch : std_logic_vector(15 downto 0);
  signal pe_reg_take  : std_logic_vector(15 downto 0);

  signal pe_pos_capt_a : std_logic;
  signal pe_pos_cnt_a : std_logic_vector(31 downto 0);
  signal pe_pos_sin_a : std_logic_vector(31 downto 0);
  signal pe_pos_cos_a : std_logic_vector(31 downto 0);
  signal pe_area_cnt_a : std_logic_vector(31 downto 0);
  signal pe_area_sin_a : std_logic_vector(31 downto 0);
  signal pe_area_cos_a : std_logic_vector(31 downto 0);
  signal pe_area_pol_a : std_logic;
  signal pe_area_flag_a : std_logic;
  signal pe_area_state_a : std_logic;

  signal pe_pos_capt_b : std_logic;
  signal pe_pos_cnt_b : std_logic_vector(31 downto 0);
  signal pe_pos_sin_b : std_logic_vector(31 downto 0);
  signal pe_pos_cos_b : std_logic_vector(31 downto 0);
  signal pe_area_cnt_b : std_logic_vector(31 downto 0);
  signal pe_area_sin_b : std_logic_vector(31 downto 0);
  signal pe_area_cos_b : std_logic_vector(31 downto 0);
  signal pe_area_pol_b : std_logic;
  signal pe_area_flag_b : std_logic;
  signal pe_area_state_b : std_logic;

  signal pe_scan_cnt  : std_logic_vector(15 downto 0);
  signal pe_scan_cnt_ena : std_logic;
  signal pe_scan_cnt_top : std_logic;
  signal pe_scan_cnt_disch : std_logic;
  signal pe_scan_cnt_take : std_logic;
  signal pe_scan_cnt_scan : std_logic;
  signal pe_scan_ovs_top : std_logic;
  signal pe_scan_ovs : std_logic;

  signal pe_trars_cnt : std_logic_vector(4 downto 0);
  signal pe_trars_cnt_bot : std_logic;
  signal pe_trars_cnt_top : std_logic;

  signal pe_scan : std_logic;
  signal pe_disch : std_logic;
  signal pe_disch_sync : std_logic_vector(2 downto 0);
  signal pe_disch_int : std_logic;
  signal pe_disch_ack : std_logic;
  signal pe_disch_ack_sync : std_logic_vector(1 downto 0);
  signal pe_disch_ack_int : std_logic;
  signal pe_take : std_logic;
  signal pe_take_sync : std_logic_vector(2 downto 0);
  signal pe_take_int : std_logic;
  signal pe_take_ack : std_logic;
  signal pe_take_ack_sync : std_logic_vector(1 downto 0);
  signal pe_take_ack_int : std_logic;
  signal pe_trars : std_logic;

  signal pe_sin : signed(15 downto 0);
  signal pe_cos : signed(15 downto 0);

begin
  ----------------------------------------------------------
  --- bus logic
  ----------------------------------------------------------
  P_WB_RD : process(WB_ADDR, WB_STB_RD, pe_reg_top, pe_reg_scan, pe_reg_disch, pe_reg_take,
    pe_pos_cnt_a, pe_pos_sin_a, pe_pos_cos_a, pe_area_cnt_a, pe_area_sin_a, pe_area_cos_a, pe_area_pol_a, pe_area_flag_a, pe_area_state_a,
    pe_pos_cnt_b, pe_pos_sin_b, pe_pos_cos_b, pe_area_cnt_b, pe_area_sin_b, pe_area_cos_b, pe_area_pol_b, pe_area_flag_b, pe_area_state_b)
  begin
    pe_pos_capt_a <= '0';
    pe_pos_capt_b <= '0';
    case WB_ADDR is
      when WB_CONF_OFFSET =>
        wb_data_mux(15 downto 0) <= WB_CONF_DATA;
        wb_data_mux(31 downto 16) <= WB_ADDR_OFFSET & "00";
      when WB_ADDR_OFFSET =>
        wb_data_mux     <= (others => '0');
        wb_data_mux(0)  <= pe_area_pol_a;
        wb_data_mux(1)  <= pe_area_state_a;
        wb_data_mux(2)  <= pe_area_flag_a;
        wb_data_mux(8)  <= pe_area_pol_b;
        wb_data_mux(9)  <= pe_area_state_b;
        wb_data_mux(10) <= pe_area_flag_b;
      when WB_ADDR_OFFSET + 1 =>
        wb_data_mux(15 downto 0)  <= pe_reg_top;
        wb_data_mux(31 downto 16) <= pe_reg_scan;
      when WB_ADDR_OFFSET + 2 =>
        wb_data_mux(15 downto 0)  <= pe_reg_disch;
        wb_data_mux(31 downto 16) <= pe_reg_take;
      when WB_ADDR_OFFSET + 3 =>
        pe_pos_capt_a <= WB_STB_RD;
        wb_data_mux <= pe_pos_cnt_a;
      when WB_ADDR_OFFSET + 4 =>
        wb_data_mux <= pe_pos_sin_a;
      when WB_ADDR_OFFSET + 5 =>
        wb_data_mux <= pe_pos_cos_a;
      when WB_ADDR_OFFSET + 6 =>
        wb_data_mux <= pe_area_cnt_a;
      when WB_ADDR_OFFSET + 7 =>
        wb_data_mux <= pe_area_sin_a;
      when WB_ADDR_OFFSET + 8 =>
        wb_data_mux <= pe_area_cos_a;
      when WB_ADDR_OFFSET + 9 =>
        pe_pos_capt_b <= WB_STB_RD;
        wb_data_mux <= pe_pos_cnt_b;
      when WB_ADDR_OFFSET + 10 =>
        wb_data_mux <= pe_pos_sin_b;
      when WB_ADDR_OFFSET + 11 =>
        wb_data_mux <= pe_pos_cos_b;
      when WB_ADDR_OFFSET + 12 =>
        wb_data_mux <= pe_area_cnt_b;
      when WB_ADDR_OFFSET + 13 =>
        wb_data_mux <= pe_area_sin_b;
      when WB_ADDR_OFFSET + 14 =>
        wb_data_mux <= pe_area_cos_b;
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
      pe_reg_top <= (others => '0');
      pe_reg_scan <= (others => '0');
      pe_reg_disch <= (others => '0');
      pe_reg_take <= (others => '0');
      pe_area_pol_a   <= '0';
      pe_area_pol_b   <= '0';
    elsif rising_edge(WB_CLK) then
      if WB_STB_WR = '1' then
        case WB_ADDR is
          when WB_ADDR_OFFSET =>
            pe_area_pol_a   <= WB_DATA_IN(0);
            pe_area_pol_b   <= WB_DATA_IN(8);
          when WB_ADDR_OFFSET + 1 =>
            pe_reg_top <= WB_DATA_IN(15 downto 0);
            pe_reg_scan <= WB_DATA_IN(31 downto 16);
          when WB_ADDR_OFFSET + 2 =>
            pe_reg_disch <= WB_DATA_IN(15 downto 0);
            pe_reg_take <= WB_DATA_IN(31 downto 16);
          when others =>
        end case;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- cycle counter
  ----------------------------------------------------------
  P_PE_SCAN_CNT : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      pe_scan_cnt <= (others => '0');
    elsif rising_edge(wb_clk) then
      if pe_scan_cnt_top = '1' then
        pe_scan_cnt <= (others => '0');
      else
        pe_scan_cnt <= pe_scan_cnt + 1;
      end if; 
    end if;
  end process;

  pe_scan_cnt_ena <= '1' when pe_reg_top /= 0 else '0';
  pe_scan_cnt_top <= '1' when pe_scan_cnt = pe_reg_top else '0';
  pe_scan_cnt_disch <= '1' when pe_scan_cnt = pe_reg_disch else '0';
  pe_scan_cnt_take <= '1' when pe_scan_cnt = pe_reg_take else '0';
  pe_scan_cnt_scan <= '1' when pe_scan_cnt = pe_reg_scan else '0';

  pe_scan_ovs_top <= '1' when pe_scan_cnt = ("0" & pe_reg_top(15 downto 1)) else '0';
  pe_scan_ovs <= pe_scan_cnt_top or pe_scan_ovs_top;

  P_PE_TRARS_CNT : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      pe_trars_cnt <= (others => '0');
    elsif rising_edge(wb_clk) then
      if pe_scan_cnt_ena = '0' then
        pe_trars_cnt <= (others => '0');
      elsif pe_scan_ovs = '1' then
        if pe_trars_cnt_top = '1' then
          if pe_scan_cnt_top = '1' then
            pe_trars_cnt <= (others => '0');
          end if;
        else
          pe_trars_cnt <= pe_trars_cnt + 1;
        end if;
      end if; 
    end if;
  end process;

  pe_trars_cnt_bot <= '1' when pe_trars_cnt = "00000" else '0';
  pe_trars_cnt_top <= '1' when pe_trars_cnt = "10011" else '0';
  pe_trars <= pe_trars_cnt(4);

  ----------------------------------------------------------
  --- pulse generator
  ----------------------------------------------------------
  P_PE_DISCH : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      pe_disch <= '0';
    elsif rising_edge(wb_clk) then
      if pe_scan_cnt_disch = '1' then
        pe_disch <= '1';
      elsif pe_disch_ack = '1' then
        pe_disch <= '0';
      end if;
    end if;
  end process;

  P_PE_TAKE : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      pe_take <= '0';
    elsif rising_edge(wb_clk) then
      if pe_scan_cnt_take = '1' then
        pe_take <= '1';
      elsif pe_take_ack = '1' then
        pe_take <= '0';
      end if;
    end if;
  end process;

  P_PE_SCAN : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      pe_scan <= '0';
    elsif rising_edge(wb_clk) then
      if pe_scan_cnt_scan = '1' then
        pe_scan <= '1';
      end if;
      if pe_scan_cnt_top = '1' then
        pe_scan <= '0';
      end if; 
    end if;
  end process;

  ----------------------------------------------------------
  --- whichbone <-> pulse with count syncer
  ----------------------------------------------------------
  P_PE_SYNC_WB : process(wb_rst, wb_clk)
  begin
    if wb_rst = '1' then
      pe_disch_ack_sync <= (others => '0');
      pe_take_ack_sync <= (others => '0');
    elsif rising_edge(wb_clk) then
      pe_disch_ack_sync <= pe_disch_ack_int & pe_disch_ack_sync(1);
      pe_take_ack_sync <= pe_take_ack_int & pe_take_ack_sync(1);
    end if;
  end process;

  pe_disch_ack <= pe_disch_ack_sync(0);
  pe_take_ack <= pe_take_ack_sync(0);


  P_PE_SYNC_INT : process(wb_rst, clk100)
  begin
    if wb_rst = '1' then
      pe_disch_sync <= (others => '0');
      pe_take_sync <= (others => '0');
    elsif rising_edge(clk100) then
      pe_disch_sync <= pe_disch & pe_disch_sync(2 downto 1);
      pe_take_sync <= pe_take & pe_take_sync(2 downto 1);
    end if;
  end process;

  pe_disch_int <= '1' when pe_disch_sync(1 downto 0) = "10" else '0';
  pe_disch_ack_int <= pe_disch_sync(0);
  pe_take_int <= '1' when pe_take_sync(1 downto 0) = "10" else '0';
  pe_take_ack_int <= pe_take_sync(0);

  ----------------------------------------------------------
  --- sincos generator
  ----------------------------------------------------------
  P_PE_SIN_COS : process(pe_trars_cnt)
  begin
    case pe_trars_cnt is
      when "00000" =>
        pe_sin <= conv_signed(     0, pe_sin'length);
        pe_cos <= conv_signed( 32767, pe_cos'length);
      when "00001" =>
        pe_sin <= conv_signed( 10126, pe_sin'length);
        pe_cos <= conv_signed( 31163, pe_cos'length);
      when "00010" =>
        pe_sin <= conv_signed( 19260, pe_sin'length);
        pe_cos <= conv_signed( 26509, pe_cos'length);
      when "00011" =>
        pe_sin <= conv_signed( 26509, pe_sin'length);
        pe_cos <= conv_signed( 19260, pe_cos'length);
      when "00100" =>
        pe_sin <= conv_signed( 31163, pe_sin'length);
        pe_cos <= conv_signed( 10126, pe_cos'length);
      when "00101" =>
        pe_sin <= conv_signed( 32767, pe_sin'length);
        pe_cos <= conv_signed(     0, pe_cos'length);
      when "00110" =>
        pe_sin <= conv_signed( 31163, pe_sin'length);
        pe_cos <= conv_signed(-10126, pe_cos'length);
      when "00111" =>
        pe_sin <= conv_signed( 26509, pe_sin'length);
        pe_cos <= conv_signed(-19260, pe_cos'length);
      when "01000" =>
        pe_sin <= conv_signed( 19260, pe_sin'length);
        pe_cos <= conv_signed(-26509, pe_cos'length);
      when "01001" =>
        pe_sin <= conv_signed( 10126, pe_sin'length);
        pe_cos <= conv_signed(-31163, pe_cos'length);
      when "01010" =>
        pe_sin <= conv_signed(     0, pe_sin'length);
        pe_cos <= conv_signed(-32767, pe_cos'length);
      when "01011" =>
        pe_sin <= conv_signed(-10126, pe_sin'length);
        pe_cos <= conv_signed(-31163, pe_cos'length);
      when "01100" =>
        pe_sin <= conv_signed(-19260, pe_sin'length);
        pe_cos <= conv_signed(-26509, pe_cos'length);
      when "01101" =>
        pe_sin <= conv_signed(-26509, pe_sin'length);
        pe_cos <= conv_signed(-19260, pe_cos'length);
      when "01110" =>
        pe_sin <= conv_signed(-31163, pe_sin'length);
        pe_cos <= conv_signed(-10126, pe_cos'length);
      when "01111" =>
        pe_sin <= conv_signed(-32767, pe_sin'length);
        pe_cos <= conv_signed(     0, pe_cos'length);
      when "10000" =>
        pe_sin <= conv_signed(-31163, pe_sin'length);
        pe_cos <= conv_signed( 10126, pe_cos'length);
      when "10001" =>
        pe_sin <= conv_signed(-26509, pe_sin'length);
        pe_cos <= conv_signed( 19260, pe_cos'length);
      when "10010" =>
        pe_sin <= conv_signed(-19260, pe_sin'length);
        pe_cos <= conv_signed( 26509, pe_cos'length);
      when others =>
        pe_sin <= conv_signed(-10126, pe_sin'length);
        pe_cos <= conv_signed( 31163, pe_cos'length);
    end case;
  end process;

  ----------------------------------------------------------
  --- channel instances
  ----------------------------------------------------------
  U_PECHAN_A: entity work.PHPE_CHAN
    port map (
      RESET => WB_RST,
      CLK100 => CLK100,
      WB_CLK => WB_CLK,

      TRAMS => not SV(8),
      AREA => not SV(10),

      pe_scan_cnt_top => pe_scan_cnt_top,
      pe_scan_ovs_top => pe_scan_ovs_top,
      pe_scan_ovs => pe_scan_ovs,
      pe_trars_cnt_bot => pe_trars_cnt_bot,

      pe_disch_int => pe_disch_int,
      pe_take_int => pe_take_int,

      pe_sin => pe_sin,
      pe_cos => pe_cos,

      pe_pos_capt => pe_pos_capt_a,
      pe_pos_cnt => pe_pos_cnt_a,
      pe_pos_sin => pe_pos_sin_a,
      pe_pos_cos => pe_pos_cos_a,

      pe_area_pol => pe_area_pol_a,
      pe_area_flag => pe_area_flag_a,
      pe_area_state => pe_area_state_a,

      pe_area_cnt => pe_area_cnt_a,
      pe_area_sin => pe_area_sin_a,
      pe_area_cos => pe_area_cos_a
    );

  U_PECHAN_B: entity work.PHPE_CHAN
    port map (
      RESET => WB_RST,
      CLK100 => CLK100,
      WB_CLK => WB_CLK,

      TRAMS => not SV(7),
      AREA => not SV(9),

      pe_scan_cnt_top => pe_scan_cnt_top,
      pe_scan_ovs_top => pe_scan_ovs_top,
      pe_scan_ovs => pe_scan_ovs,
      pe_trars_cnt_bot => pe_trars_cnt_bot,

      pe_disch_int => pe_disch_int,
      pe_take_int => pe_take_int,

      pe_sin => pe_sin,
      pe_cos => pe_cos,

      pe_pos_capt => pe_pos_capt_b,
      pe_pos_cnt => pe_pos_cnt_b,
      pe_pos_sin => pe_pos_sin_b,
      pe_pos_cos => pe_pos_cos_b,

      pe_area_pol => pe_area_pol_b,
      pe_area_flag => pe_area_flag_b,
      pe_area_state => pe_area_state_b,

      pe_area_cnt => pe_area_cnt_b,
      pe_area_sin => pe_area_sin_b,
      pe_area_cos => pe_area_cos_b
    );

  ----------------------------------------------------------
  --- output mapping
  ----------------------------------------------------------
  SV(3) <= '0';
  SV(4) <= '0';
  SV(5) <= pe_scan_cnt_ena and (not pe_scan);
  SV(6) <= pe_scan_cnt_ena and (not pe_trars);

end;

