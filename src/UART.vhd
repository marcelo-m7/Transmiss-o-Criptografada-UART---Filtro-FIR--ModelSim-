library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART is
  generic(
    BIT_TICKS : integer := 16               -- ciclos de clk por bit
  );
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    ------------------------------------------------------------------
    -- Transmissor
    ------------------------------------------------------------------
    data_in    : in  std_logic_vector(7 downto 0);
    tx_start   : in  std_logic;
    tx_out     : out std_logic;
    busy       : out std_logic;
    ------------------------------------------------------------------
    -- Recetor
    ------------------------------------------------------------------
    rx_in      : in  std_logic;
    data_out   : out std_logic_vector(7 downto 0);
    data_valid : out std_logic
  );
end entity;

architecture Behavioral of UART is
  --------------------------------------------------------------------
  -- Transmissor (10 bits: start + 8 data + stop)
  --------------------------------------------------------------------
  signal tx_shift_reg : std_logic_vector(9 downto 0) := (others=>'1');
  signal tx_bit_count : integer range 0 to 10 := 0;
  signal tx_tick_count: integer range 0 to BIT_TICKS-1 := 0;
  signal tx_active    : std_logic := '0';

  --------------------------------------------------------------------
  -- Recetor
  --------------------------------------------------------------------
  signal rx_shift_reg : std_logic_vector(7 downto 0) := (others=>'0');
  signal rx_bit_count : integer range 0 to 10 := 0;  -- ← 0..10 seguro
  signal rx_tick_count: integer range 0 to BIT_TICKS-1 := 0;
  signal rx_active    : std_logic := '0';
begin
  busy   <= tx_active;
  tx_out <= tx_shift_reg(0);

  process(clk)
  begin
    if rising_edge(clk) then
      --------------------------------------------------------------
      -- RESET global
      --------------------------------------------------------------
      if reset = '1' then
        -- TX
        tx_shift_reg  <= (others=>'1');
        tx_bit_count  <= 0;
        tx_tick_count <= 0;
        tx_active     <= '0';
        -- RX
        rx_shift_reg  <= (others=>'0');
        rx_bit_count  <= 0;
        rx_tick_count <= 0;
        rx_active     <= '0';
        data_out      <= (others=>'0');
        data_valid    <= '0';

      --------------------------------------------------------------
      -- Funcionamento normal
      --------------------------------------------------------------
      else
        ----------------------------------------------------------------
        -- Transmissor
        ----------------------------------------------------------------
        if tx_active = '0' then
          if tx_start = '1' then
            tx_shift_reg  <= '0' & data_in & '1';
            tx_bit_count  <= 0;
            tx_tick_count <= 0;
            tx_active     <= '1';
          end if;
        else
          if tx_tick_count < BIT_TICKS-1 then
            tx_tick_count <= tx_tick_count + 1;
          else
            tx_tick_count <= 0;
            if tx_bit_count < 9 then
              tx_bit_count <= tx_bit_count + 1;
              tx_shift_reg <= '1' & tx_shift_reg(9 downto 1);
            else
              tx_active    <= '0';   -- fim da transmissão
            end if;
          end if;
        end if;

        ----------------------------------------------------------------
        -- Recetor
        ----------------------------------------------------------------
        data_valid <= '0';            -- reset do pulso
        if rx_active = '0' then
          if rx_in = '0' then         -- start detectado
            rx_active     <= '1';
            rx_tick_count <= 0;
            rx_bit_count  <= 0;
          end if;
        else
          if rx_tick_count < BIT_TICKS-1 then
            rx_tick_count <= rx_tick_count + 1;
          else
            rx_tick_count <= 0;
            rx_bit_count  <= rx_bit_count + 1;
            case rx_bit_count is
              when 0|1|2|3|4|5|6|7 =>           -- 8 dados
                rx_shift_reg <= rx_in & rx_shift_reg(7 downto 1);
              when 8 =>                          -- bit de stop
                null;                            -- opcional: checar rx_in='1'
              when 9 =>                          -- byte completo
                data_out      <= rx_shift_reg;
                data_valid    <= '1';
                rx_active     <= '0';            -- regressa ao idle
                rx_bit_count  <= 0;              -- PREVINE valor 10
              when others =>
                null;
            end case;
          end if;
        end if;
      end if;
    end if;
  end process;
end Behavioral;
