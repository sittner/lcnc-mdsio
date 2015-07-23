library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity ENC_CHAN is
  port (
    RESET: in std_logic;
    CLK: in std_logic;
    CAPTURE: in std_logic;

    TIMESTAMP: in std_logic_vector(31 downto 0);

    CNT_REG: out std_logic_vector(31 downto 0);
    TS_REG: out std_logic_vector(31 downto 0);
    IDX_REG: out std_logic_vector(31 downto 0);

    ENC_A: in std_logic;
    ENC_B: in std_logic;
    ENC_I: in std_logic
  );
end;

architecture rtl of ENC_CHAN is

  signal enc_in: std_logic_vector(1 downto 0);
  signal enc_q: std_logic_vector(1 downto 0);
  signal enc_dly: std_logic;

  signal enc_idx_in: std_logic_vector(2 downto 0);

  signal enc_cnt: std_logic_vector(30 downto 0);
  signal enc_cnt_flag: std_logic;
  signal enc_ts: std_logic_vector(31 downto 0);
  
  signal enc_idx: std_logic_vector(30 downto 0);
  signal enc_idx_flag: std_logic;

begin
  capture_proc: process(RESET, CLK)
  begin
    if RESET = '1' then
      CNT_REG <= (others => '0');
      TS_REG <= (others => '0');
      IDX_REG <= (others => '0');
    elsif rising_edge(CLK) then
      if CAPTURE = '1' then
        CNT_REG <= enc_cnt_flag & enc_cnt;
        TS_REG <= enc_ts;
        IDX_REG <= enc_idx_flag & enc_idx;
      end if;
    end if;
  end process;

  enc_filter_proc: process(RESET, CLK)
  begin
    if RESET = '1' then
      enc_in <= (others => '0');
      enc_q <= (others => '0');
      enc_idx_in <= (others => '0');
    elsif rising_edge(CLK) then
      enc_in <= ENC_A & ENC_B;
      case enc_in is
        when "00"   => enc_q <= enc_q(1) & '0';
        when "01"   => enc_q <= '0' & enc_q(0);
        when "10"   => enc_q <= '1' & enc_q(0);
        when others => enc_q <= enc_q(1) & '1';
      end case;
      enc_idx_in <= enc_idx_in(1 downto 0) & ENC_I;
    end if;
  end process;

  enc_cnt_proc: process(RESET, CLK)
  begin
    if RESET = '1' then
      enc_cnt <= (others => '0');
      enc_idx <= (others => '0');
      enc_cnt_flag <= '0';
      enc_idx_flag <= '0';
    elsif rising_edge(CLK) then
      if CAPTURE = '1' then
        enc_cnt_flag <= '0';
        enc_idx_flag <= '0';
      end if;

      enc_dly <= enc_q(0);
      if enc_q(0) = '1' and enc_dly = '0' then
        if enc_q(1) = '0' then
          enc_cnt <= enc_cnt + 1;
          enc_cnt_flag <= '1';
          enc_ts <= TIMESTAMP;
        else
          enc_cnt <= enc_cnt - 1;
          enc_cnt_flag <= '1';
          enc_ts <= TIMESTAMP;
        end if;
      end if;

      if enc_idx_in = "011" and enc_idx_flag = '0' then
        enc_idx <= enc_cnt;
        enc_idx_flag <= '1';
      end if;
    end if;
  end process;

end;
