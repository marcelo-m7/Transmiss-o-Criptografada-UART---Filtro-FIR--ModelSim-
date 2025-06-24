library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Sender is               -- <<< “end Sender;” no fim
  port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    tx_out : out std_logic;
    done   : out std_logic
  );
end Sender;

architecture Behavioral of Sender is
  ---------------------------------------------------------------------------
  -- ROM - 64 amostras de 16 bits inicializadas no código
  ---------------------------------------------------------------------------
  constant N_SAMPLES : integer := 64;
  type rom_array is array (0 to N_SAMPLES-1) of std_logic_vector(15 downto 0);
  constant ROM_DATA : rom_array := (
    0  => x"0000",  1 => x"13C7",  2 => x"259E",  3 => x"33C7",
    4  => x"3CDE",  5 => x"4000",  6 => x"3CDE",  7 => x"33C7",
    8  => x"259E",  9 => x"13C7", 10 => x"0000", 11 => x"EC39",
    12 => x"DA62", 13 => x"CC39", 14 => x"C322", 15 => x"C000",
    16 => x"C322", 17 => x"CC39", 18 => x"DA62", 19 => x"EC39",
    20 => x"0000", 21 => x"13C7", 22 => x"259E", 23 => x"33C7",
    24 => x"3CDE", 25 => x"4000", 26 => x"3CDE", 27 => x"33C7",
    28 => x"259E", 29 => x"13C7", 30 => x"0000", 31 => x"EC39",
    32 => x"DA62", 33 => x"CC39", 34 => x"C322", 35 => x"C000",
    36 => x"C322", 37 => x"CC39", 38 => x"DA62", 39 => x"EC39",
    40 => x"0000", 41 => x"13C7", 42 => x"259E", 43 => x"33C7",
    44 => x"3CDE", 45 => x"4000", 46 => x"3CDE", 47 => x"33C7",
    48 => x"259E", 49 => x"13C7", 50 => x"0000", 51 => x"EC39",
    52 => x"DA62", 53 => x"CC39", 54 => x"C322", 55 => x"C000",
    56 => x"C322", 57 => x"CC39", 58 => x"DA62", 59 => x"EC39",
    60 => x"0000", 61 => x"13C7", 62 => x"259E", 63 => x"33C7"
  );
  signal ROM_mem        : rom_array := ROM_DATA;

  -- Índice e amostra corrente como SINAIS (não variáveis)
  signal index          : integer range 0 to N_SAMPLES-1 := 0;
  signal current_sample : std_logic_vector(15 downto 0) := (others=>'0');

  ---------------------------------------------------------------------------
  -- Interface com Encryptor e UART
  ---------------------------------------------------------------------------
  type state_type is (IDLE,SEND_LOW,ENC_LOW,TX_LOW,
                      SEND_HIGH,ENC_HIGH,TX_HIGH,DONE_STATE);
  signal state_reg : state_type := IDLE;

  signal uart_data_in, enc_out : std_logic_vector(7 downto 0);
  signal tx_start_sig, enc_start_sig, uart_busy : std_logic;

  component Encryptor
    port ( clk, reset : in  std_logic;
           data_in    : in  std_logic_vector(7 downto 0);
           start      : in  std_logic;
           data_out   : out std_logic_vector(7 downto 0);
           out_valid  : out std_logic );
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
begin
  ---------------------------------------------------------------------------
  -- Instâncias
  ---------------------------------------------------------------------------
  UartTx : UART
    port map ( clk => clk, reset => reset,
               data_in => uart_data_in, tx_start => tx_start_sig,
               tx_out  => tx_out, busy => uart_busy,
               rx_in   => '1',     -- linha RX ociosa
               data_out => open, data_valid => open );

  Enc : Encryptor
    port map ( clk=>clk, reset=>reset,
               data_in=>uart_data_in, start=>enc_start_sig,
               data_out=>enc_out, out_valid=>open );

  ---------------------------------------------------------------------------
  -- FSM do Sender
  ---------------------------------------------------------------------------
  process(clk, reset)
  begin
    if reset='1' then
      state_reg      <= IDLE;
      index          <= 0;
      current_sample <= (others=>'0');
      tx_start_sig   <= '0';
      enc_start_sig  <= '0';
      done           <= '0';
      uart_data_in   <= (others=>'0');

    elsif rising_edge(clk) then
      case state_reg is
        when IDLE =>
          index          <= 0;
          current_sample <= ROM_mem(0);
          done           <= '0';
          state_reg      <= SEND_LOW;

        when SEND_LOW =>
          uart_data_in   <= current_sample(7 downto 0);
          enc_start_sig  <= '1';
          state_reg      <= ENC_LOW;

        when ENC_LOW =>
          enc_start_sig  <= '0';
          uart_data_in   <= enc_out;
          tx_start_sig   <= '1';
          state_reg      <= TX_LOW;

        when TX_LOW =>
          tx_start_sig <= '0';
          if uart_busy = '0' then
            uart_data_in  <= current_sample(15 downto 8);
            enc_start_sig <= '1';
            state_reg     <= SEND_HIGH;
          end if;

        when SEND_HIGH =>
          enc_start_sig <= '1';
          state_reg     <= ENC_HIGH;

        when ENC_HIGH =>
          enc_start_sig  <= '0';
          uart_data_in   <= enc_out;
          tx_start_sig   <= '1';
          state_reg      <= TX_HIGH;

        when TX_HIGH =>
          tx_start_sig <= '0';
          if uart_busy='0' then
            if index = N_SAMPLES-1 then
              done      <= '1';
              state_reg <= DONE_STATE;
            else
              index          <= index + 1;
              current_sample <= ROM_mem(index + 1);
              state_reg      <= SEND_LOW;
            end if;
          end if;

        when DONE_STATE =>
          state_reg <= DONE_STATE;
      end case;
    end if;
  end process;
end Behavioral;
