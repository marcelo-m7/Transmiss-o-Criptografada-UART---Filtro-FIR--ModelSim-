library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Encryptor is
  Port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    data_in   : in  std_logic_vector(7 downto 0);
    start     : in  std_logic;
    data_out  : out std_logic_vector(7 downto 0);
    out_valid : out std_logic
  );
end Encryptor;

architecture Behavioral of Encryptor is
  signal lfsr_reg : std_logic_vector(7 downto 0) := x"B5"; -- LFSR de 8 bits (semente = 0xB5)
begin
  process(clk)
    variable new_bit : std_logic;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- Reinicia LFSR com a chave inicial fixa
        lfsr_reg <= x"B5";
        data_out <= (others => '0');
        out_valid <= '0';
      else
        if start = '1' then
          -- Gera o próximo bit pseudo-aleatório (feedback LFSR):
          -- (Exemplo: polinômio x^8 + x^6 + x^5 + x^4 + 1)
          new_bit := lfsr_reg(7) XOR lfsr_reg(5) XOR lfsr_reg(4) XOR lfsr_reg(3);
          -- Gera byte keystream atual (usar o próprio valor atual do LFSR como chave de 8 bits)
          -- Realiza XOR do dado de entrada com o keystream para cifrar
          data_out <= data_in XOR lfsr_reg;
          out_valid <= '1';  -- indica que data_out é válido neste ciclo
          -- Atualiza LFSR (desloca para direita e insere new_bit no bit mais significativo)
          lfsr_reg <= new_bit & lfsr_reg(7 downto 1);
        else
          out_valid <= '0';  -- mantém baixo quando não em operação
        end if;
      end if;
    end if;
  end process;
end Behavioral;
