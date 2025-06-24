library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity tb_FinalProject is
  -- Testbench não possui portas
end tb_FinalProject;

architecture TB of tb_FinalProject is

  constant CLOCK_PERIOD : time := 20 ns;  -- Período de clock (ex: 20ns = 50 MHz)

  -- Componentes do sistema sob teste (Sender e Receiver)
  component Sender 
    Port(clk: in std_logic; reset: in std_logic; tx_out: out std_logic; done: out std_logic);
  end component;
  component Receiver 
    Port(clk: in std_logic; reset: in std_logic; rx_in: in std_logic;
         done: out std_logic; data_out: out std_logic_vector(15 downto 0);
         data_out_valid: out std_logic);
  end component;

  -- Sinais para conectar o Sender e Receiver
  signal clk      : std_logic := '0';
  signal reset    : std_logic := '0';
  signal tx_line  : std_logic;  -- linha serial que conecta Sender (tx_out) ao Receiver (rx_in)
  signal done_tx  : std_logic;
  signal done_rx  : std_logic;
  signal rx_data_out       : std_logic_vector(15 downto 0);
  signal rx_data_out_valid : std_logic;

  -- Arquivo de texto para salvar os dados de saída filtrados
  file output_file : text open write_mode is "ram_output.txt";

begin

  -- Instancia o Sender e o Receiver, conectando a linha UART entre eles
  UUT_Sender: Sender 
    port map(
      clk    => clk,
      reset  => reset,
      tx_out => tx_line,
      done   => done_tx
    );
  UUT_Receiver: Receiver 
    port map(
      clk       => clk,
      reset     => reset,
      rx_in     => tx_line,
      done      => done_rx,
      data_out  => rx_data_out,
      data_out_valid => rx_data_out_valid
    );

  -- Geração do clock de 50 MHz
  clk_process: process
  begin
    clk <= '0';
    wait for CLOCK_PERIOD/2;
    clk <= '1';
    wait for CLOCK_PERIOD/2;
  end process;

  -- Processo de estímulo: aplica reset e espera a conclusão
  stim_process: process
  begin
    -- Aplica reset inicial
    reset <= '1';
    wait for 50 ns;
    reset <= '0';  -- libera o reset após 50 ns

    -- Aguarda até o Receiver indicar conclusão (done_rx = '1')
    wait until done_rx = '1';
    -- Pequeno atraso para garantir que último dado seja processado
    wait for 100 ns;
    report "Simulation completed, all samples processed." severity note;
    wait;  -- finaliza simulação
  end process;

  -- Processo monitor: captura cada saída filtrada e escreve no arquivo de texto
  output_monitor: process
    variable out_line : line;
    variable int_val  : integer;
  begin
    for i in 0 to 63 loop   -- espera as 64 amostras de saída
      wait until rx_data_out_valid = '1';
      -- Converte o valor de 16 bits (com sinal) para inteiro
      int_val := to_integer(signed(rx_data_out));
      -- Escreve o valor inteiro no arquivo de saída
      write(out_line, int_val, RIGHT, 0);
      writeline(output_file, out_line);
      -- Espera o pulso de valid baixar antes de buscar próximo (evita duplicatas)
      wait until rx_data_out_valid = '0';
    end loop;
    file_close(output_file);
    wait;
  end process;

end architecture;
