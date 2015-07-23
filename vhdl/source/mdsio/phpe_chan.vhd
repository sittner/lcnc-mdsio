library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity PHPE_CHAN is
  port (
    RESET: in std_logic;
    CLK100: in std_logic;
    WB_CLK: in std_logic;

    TRAMS: in std_logic;
    AREA: in std_logic;

    pe_scan_cnt_top: in std_logic;
    pe_scan_ovs_top: in std_logic;
    pe_scan_ovs: in std_logic;
    pe_trars_cnt_bot: in std_logic;

    pe_disch_int: in std_logic;
    pe_take_int: in std_logic;

    pe_sin: in signed(15 downto 0);
    pe_cos: in signed(15 downto 0);

    pe_pos_capt: in std_logic;
    pe_pos_cnt: out std_logic_vector(31 downto 0);
    pe_pos_sin: out std_logic_vector(31 downto 0);
    pe_pos_cos: out std_logic_vector(31 downto 0);

    pe_area_pol: in std_logic;
    pe_area_flag: out std_logic;
    pe_area_state: out std_logic;

    pe_area_cnt: out std_logic_vector(31 downto 0);
    pe_area_sin: out std_logic_vector(31 downto 0);
    pe_area_cos: out std_logic_vector(31 downto 0)
  );
end;

architecture rtl of PHPE_CHAN is

  signal pe_trams_sync : std_logic_vector(1 downto 0);
  signal pe_area_sync : std_logic_vector(1 downto 0);

  signal pe_int_cnt : std_logic_vector(15 downto 0);
  signal pe_int_reg : std_logic_vector(15 downto 0);

  signal pe_take_reg : std_logic_vector(15 downto 0);

  signal pe_ipol_reg : std_logic_vector(15 downto 0);
  signal pe_ipol_step : std_logic_vector(16 downto 0);

  signal pe_enc_cnt: std_logic_vector(31 downto 0);
  signal pe_sin_prod : signed(33 downto 0);
  signal pe_cos_prod : signed(33 downto 0);
  signal pe_sin_accu : signed(33 downto 0);
  signal pe_cos_accu : signed(33 downto 0);
  signal pe_sin_reg : std_logic_vector(31 downto 0);
  signal pe_cos_reg : std_logic_vector(31 downto 0);

  signal pe_area_int: std_logic;
  signal pe_area_dly: std_logic;
  signal pe_area_done: std_logic;
  signal pe_area_cnt_reg: std_logic_vector(31 downto 0);
  signal pe_area_sin_reg: std_logic_vector(31 downto 0);
  signal pe_area_cos_reg: std_logic_vector(31 downto 0);

begin

  ----------------------------------------------------------
  --- input syncer
  ----------------------------------------------------------
  P_PE_TRAMS_SYNC : process(RESET, CLK100)
  begin
    if RESET = '1' then
      pe_trams_sync <= (others => '0');
    elsif rising_edge(CLK100) then
      pe_trams_sync <= TRAMS & pe_trams_sync(1);
    end if;
  end process;

  pe_area_int <= AREA xor pe_area_pol;
  P_PE_AREA_SYNC : process(RESET, WB_CLK)
  begin
    if RESET = '1' then
      pe_area_sync <= (others => '0');
    elsif rising_edge(WB_CLK) then
      pe_area_sync <= pe_area_int & pe_area_sync(1);
    end if;
  end process;


  ----------------------------------------------------------
  --- pulse width messure
  ----------------------------------------------------------
  P_PE_INT : process(RESET, CLK100)
  begin
    if RESET = '1' then
      pe_int_cnt <= (others => '0');
      pe_int_reg <= (others => '0');
    elsif rising_edge(CLK100) then
      if pe_disch_int = '1' then
        pe_int_cnt <= (others => '0');
      elsif pe_take_int = '1' then
        pe_int_reg <= pe_int_cnt;
      elsif pe_trams_sync(0) = '1' then
        pe_int_cnt <= pe_int_cnt + 1;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- whisbone clock syncer
  ----------------------------------------------------------
  P_PE_SYNC_WB : process(RESET, WB_CLK)
  begin
    if RESET = '1' then
      pe_take_reg <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if pe_scan_cnt_top = '1' then
        pe_take_reg <= pe_int_reg;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- oversampling interpolator
  ----------------------------------------------------------
  P_PE_IPOL : process(RESET, WB_CLK)
  begin
    if RESET = '1' then
      pe_ipol_reg <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if pe_scan_cnt_top = '1' then
        pe_ipol_reg <= pe_take_reg;
      elsif pe_scan_ovs_top = '1' then
        pe_ipol_reg <= pe_ipol_step(16 downto 1);
      end if;
    end if;
  end process;

  pe_ipol_step <= pe_take_reg + pe_ipol_reg;

  ----------------------------------------------------------
  --- sincos correlator
  ----------------------------------------------------------
  P_PE_CORREL : process(RESET, WB_CLK)
  begin
    if RESET = '1' then
      pe_enc_cnt <= (others => '0');
      pe_sin_reg <= (others => '0');
      pe_cos_reg <= (others => '0');
      pe_sin_accu <= (others => '0');
      pe_cos_accu <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if pe_scan_ovs = '1' then
        if pe_trars_cnt_bot = '1' then
          pe_sin_reg <= std_logic_vector(pe_sin_accu(31 downto 0));
          pe_cos_reg <= std_logic_vector(pe_cos_accu(31 downto 0));
          if pe_cos_accu(31) = '1' then
            if pe_sin_reg(31) = '0' and pe_sin_accu(31) = '1' then
              pe_enc_cnt <= pe_enc_cnt + 1;
            end if;
            if pe_sin_reg(31) = '1' and pe_sin_accu(31) = '0' then
              pe_enc_cnt <= pe_enc_cnt - 1;
            end if;
          end if;
          pe_sin_accu <= pe_sin_prod;
          pe_cos_accu <= pe_cos_prod;
        else
          pe_sin_accu <= pe_sin_accu + pe_sin_prod;
          pe_cos_accu <= pe_cos_accu + pe_cos_prod;
        end if;
      end if;
    end if;
  end process;

  pe_sin_prod <= unsigned(pe_ipol_reg) * pe_sin;
  pe_cos_prod <= unsigned(pe_ipol_reg) * pe_cos;

  pe_pos_cnt <= pe_enc_cnt;

  P_PE_POS_CAPT : process(RESET, WB_CLK)
  begin
    if RESET = '1' then
      pe_pos_sin <= (others => '0');
      pe_pos_cos <= (others => '0');
      pe_area_cnt <= (others => '0');
      pe_area_sin <= (others => '0');
      pe_area_cos <= (others => '0');
    elsif rising_edge(WB_CLK) then
      if pe_pos_capt = '1' then
        pe_pos_sin <= pe_sin_reg;
        pe_pos_cos <= pe_cos_reg;
        pe_area_flag <= pe_area_done;
        pe_area_cnt <= pe_area_cnt_reg;
        pe_area_sin <= pe_area_sin_reg;
        pe_area_cos <= pe_area_cos_reg;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  --- area edge detector
  ----------------------------------------------------------
  P_PE_AREA : process(RESET, WB_CLK)
  begin
    if RESET = '1' then
      pe_area_dly <= '0';
      pe_area_done <= '0';
      pe_area_cnt_reg <= (others => '0');
      pe_area_sin_reg <= (others => '0');
      pe_area_cos_reg <= (others => '0');
    elsif rising_edge(WB_CLK) then
      pe_area_dly <= pe_area_sync(0);
      if pe_pos_capt = '1' then
        pe_area_done <= '0';
      elsif pe_area_done = '0' and pe_area_dly = '0' and pe_area_sync(0) = '1' then
        pe_area_done <= '1';
        pe_area_cnt_reg <= pe_enc_cnt;
        pe_area_sin_reg <= pe_sin_reg;
        pe_area_cos_reg <= pe_cos_reg;
      end if;
    end if;
  end process;

  pe_area_state <= pe_area_sync(0);

end;

