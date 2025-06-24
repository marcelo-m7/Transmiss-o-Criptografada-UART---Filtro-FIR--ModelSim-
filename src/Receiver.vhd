library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Receiver is
  port (
    clk            : in std_logic;
    reset          : in std_logic;
    rx_in          : in std_logic;
    done           : out std_logic;
    data_out       : out std_logic_vector(15 downto 0);
    data_out_valid : out std_logic
  );
end entity;

architecture Behavioral of Receiver is
  ---------------------------------------------------------------------------
  constant N_SAMPLES : integer := 64;
  ---------------------------------------------------------------------------
  component Decryptor
    port ( clk, reset : in  std_logic;
           data_in    : in  std_logic_vector(7 downto 0);
           start      : in  std_logic;
           data_out   : out std_logic_vector(7 downto 0);
           out_valid  : out std_logic );
  end component;

  component FIR_Filter_21tap
    generic( DATA_WIDTH : integer := 16 );
    port ( clk     : in  std_logic;
           reset_n : in  std_logic;
           data_in : in  std_logic_vector(DATA_WIDTH-1 downto 0);
           data_out: out std_logic_vector(DATA_WIDTH-1 downto 0) );
  end component;

  component UART
    port ( clk, reset : in  std_logic;
           data_in    : in  std_logic_vector(7 downto 0);
           tx_start   : in  std_logic;
           tx_out     : out std_logic;
           busy       : out std_logic;
           rx_in      : in  std_logic;
           data_out   : out std_logic_vector(7 downto 0);
           data_valid : out std_logic );
  end component;

  ---------------------------------------------------------------------------
  -- Sinais internos
  ---------------------------------------------------------------------------
  signal rx_data_byte   : std_logic_vector(7 downto 0);
  signal rx_data_valid  : std_logic;
  signal dec_start_sig  : std_logic := '0';
  signal dec_out_byte   : std_logic_vector(7 downto 0);
  signal dec_out_valid  : std_logic;
  signal filter_in_reg  : std_logic_vector(15 downto 0) := (others=>'0');
  signal filter_out_sig : std_logic_vector(15 downto 0);

  signal reset_n_s      : std_logic;  -- reset ativo-baixo para o filtro

  type ram_type  is array(0 to N_SAMPLES-1) of std_logic_vector(15 downto 0);
  signal out_ram   : ram_type := (others=>(others=>'0'));
  signal write_addr: integer range 0 to N_SAMPLES-1 := 0;

  type state_type is (WAIT_BYTE1, DEC_BYTE1, WAIT_BYTE2,
                      DEC_BYTE2, FILTER_PROC, DONE_STATE);
  signal state_reg : state_type := WAIT_BYTE1;
begin
  reset_n_s <= not reset;

  ---------------------------------------------------------------------------
  -- Instâncias
  ---------------------------------------------------------------------------
  UartRx : UART
    port map ( clk=>clk, reset=>reset,
               data_in=>(others=>'0'), tx_start=>'0',
               tx_out=>open, busy=>open,
               rx_in=>rx_in,
               data_out=>rx_data_byte, data_valid=>rx_data_valid );

  Dec : Decryptor
    port map ( clk=>clk, reset=>reset,
               data_in=>rx_data_byte, start=>dec_start_sig,
               data_out=>dec_out_byte, out_valid=>dec_out_valid );

  Filter : FIR_Filter_21tap
    generic map ( DATA_WIDTH => 16 )
    port map ( clk=>clk, reset_n=>reset_n_s,
               data_in=>filter_in_reg, data_out=>filter_out_sig );

  ---------------------------------------------------------------------------
  -- FSM de receção/decifragem/filtragem
  ---------------------------------------------------------------------------
  process(clk, reset)
    variable plain_low, plain_high : std_logic_vector(7 downto 0);
    variable sample_count          : integer := 0;
    variable state_var             : state_type;
  begin
    if reset='1' then
      state_var      := WAIT_BYTE1;
      dec_start_sig  <= '0';
      done           <= '0';
      data_out_valid <= '0';
      data_out       <= (others=>'0');
      write_addr     <= 0;
      filter_in_reg  <= (others=>'0');

    elsif rising_edge(clk) then
      state_var := state_reg;

      case state_var is
        ---------------------------------------------------------------------
        when WAIT_BYTE1 =>
          data_out_valid <= '0';
          if rx_data_valid='1' then
            plain_low     := rx_data_byte;
            dec_start_sig <= '1';
            state_var     := DEC_BYTE1;
          end if;

        when DEC_BYTE1 =>
          dec_start_sig <= '0';
          if dec_out_valid='1' then
            plain_low := dec_out_byte;
          end if;
          state_var := WAIT_BYTE2;

        when WAIT_BYTE2 =>
          if rx_data_valid='1' then
            plain_high    := rx_data_byte;
            dec_start_sig <= '1';
            state_var     := DEC_BYTE2;
          end if;

        when DEC_BYTE2 =>
          dec_start_sig <= '0';
          if dec_out_valid='1' then
            plain_high := dec_out_byte;
          end if;
          filter_in_reg <= plain_high & plain_low; -- 16-bit para o FIR
          state_var     := FILTER_PROC;

        when FILTER_PROC =>
          out_ram(write_addr) <= filter_out_sig; -- opcional / debug
          data_out            <= filter_out_sig;
          data_out_valid      <= '1';
          if sample_count = N_SAMPLES-1 then
            done <= '1';
            state_var := DONE_STATE;
          else
            sample_count := sample_count + 1;
            write_addr   <= write_addr + 1;
            state_var    := WAIT_BYTE1;
          end if;

        when DONE_STATE =>
          data_out_valid <= '0';
          state_var      := DONE_STATE;
      end case;

      state_reg <= state_var;
    end if;
  end process;
end Behavioral;
