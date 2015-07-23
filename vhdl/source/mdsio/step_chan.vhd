library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity STEP_CHAN is
  port (
    RESET: in std_logic;
    CLK: in std_logic;

    pos_capt: in std_logic;
    pos_hi: out std_logic_vector(31 downto 0);
    pos_lo: out std_logic_vector(31 downto 0);

    targetvel: in std_logic_vector(31 downto 0);
    deltalim: in std_logic_vector(31 downto 0);
    step_len: in std_logic_vector(31 downto 0);
    dir_hold_dly: in std_logic_vector(31 downto 0);
    dir_setup_dly: in std_logic_vector(31 downto 0);

    OUT_EN: in std_logic;
    IDLE: out std_logic;

    STP_OUT: out std_logic;
    STP_DIR: out std_logic
  );
end;

architecture rtl of STEP_CHAN is

  signal vel: std_logic_vector(47 downto 0);
  signal vel_target: std_logic_vector(47 downto 0);
  signal vel_delta_lim_pos: std_logic_vector(47 downto 0);
  signal vel_delta_lim_neg: std_logic_vector(47 downto 0);
  signal vel_delta: std_logic_vector(47 downto 0);

  signal timer_step_len: std_logic_vector(31 downto 0);
  signal timer_step_len_run: std_logic;
  signal timer_dir_hold_dly: std_logic_vector(31 downto 0);
  signal timer_dir_hold_dly_run: std_logic;
  signal timer_dir_setup_dly: std_logic_vector(31 downto 0);
  signal timer_dir_setup_dly_run: std_logic;

  signal direction: std_logic;
  signal direction_old: std_logic;

  signal capture: std_logic;
  signal accu: std_logic_vector(63 downto 0);
  signal accu_inc: std_logic_vector(63 downto 0);
  signal accu_reg: std_logic_vector(31 downto 0);
  signal stepflag: std_logic;

begin
  -- set position output
  pos_hi <= accu(63 downto 32);

  capture_proc: process(RESET, CLK)
  begin
    if RESET = '1' then
        pos_lo <= (others => '0');
    elsif rising_edge(CLK) then
      if pos_capt = '1' then
        pos_lo <= accu(31 downto 0);
      end if;
    end if;
  end process;

  -- check for running timers
  timer_step_len_run      <= '1' when timer_step_len /= 0 else '0';
  timer_dir_hold_dly_run  <= '1' when timer_dir_hold_dly /= 0 else '0';
  timer_dir_setup_dly_run <= '1' when timer_dir_setup_dly /= 0 else '0';
  
  -- calc velocity delta limit
  vel_target <= targetvel & "0000000000000000" when OUT_EN = '1' else (others => '0');
  vel_delta_lim_pos <= "0000000000000000" & deltalim;
  vel_delta_lim_neg <= 0 - vel_delta_lim_pos;
  vel_delta <= vel_target - vel;

  -- get command direction
  direction <= vel(47);

  -- expand vel to akku size with respect to sign
  accu_inc(63 downto 32) <= (others => vel(47));
  accu_inc(31 downto 0)  <= vel(47 downto 16);

  stepgen_proc: process(CLK)
  begin
    if RESET = '1' then
        vel <= (others => '0');
        timer_step_len <= (others => '0');
        timer_dir_hold_dly <= (others => '0');
        timer_dir_setup_dly <= (others => '0');
        accu <= (others => '0');
        stepflag <= '0';
        STP_DIR <= '0';
    elsif rising_edge(CLK) then
      -- update velocity
      if signed(vel_delta) < signed(vel_delta_lim_neg) then
        vel <= vel + vel_delta_lim_neg;
      elsif signed(vel_delta) > signed(vel_delta_lim_pos) then
        vel <= vel + vel_delta_lim_pos;
      else
        vel <= vel + vel_delta;
      end if;

      -- update timers
      if timer_step_len_run = '1' then
        timer_step_len <= timer_step_len - 1;
      elsif timer_dir_hold_dly_run = '1' then
        timer_dir_hold_dly <= timer_dir_hold_dly - 1;
      elsif timer_dir_setup_dly_run = '1' then
        timer_dir_setup_dly <= timer_dir_setup_dly - 1;
      end if;

      -- check for direction change
      direction_old <= direction;
      if direction_old /= direction then
        timer_dir_hold_dly <= dir_hold_dly;
        timer_dir_setup_dly <= dir_setup_dly;

      else
        if timer_dir_hold_dly_run = '0' then
          -- update motor direction
          STP_DIR <= direction;

          -- dds
          if timer_dir_setup_dly_run = '0' then
            accu <= accu + accu_inc;
            stepflag <= accu(32);
            if stepflag /= accu(32) then
              timer_step_len <= step_len;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- generate step pulse
  STP_OUT <= timer_step_len_run;

  -- set idle output
  IDLE <= '1' when vel = 0 else '0';

end;
