library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Decryptor is
  Port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    data_in   : in  std_logic_vector(7 downto 0);
    start     : in  std_logic;
    data_out  : out std_logic_vector(7 downto 0);
    out_valid : out std_logic
  );
end Decryptor;

architecture Behavioral of Decryptor is
  -- Utiliza o mesmo LFSR e chave do Encryptor para gerar o keystream
  signal lfsr_reg : std_logic_vector(7 downto 0) := x"B5";  -- mesma semente 0xB5
begin
  process(clk)
    variable new_bit : std_logic;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        lfsr_reg <= x"B5";
        data_out <= (others => '0');
        out_valid <= '0';
      else
        if start = '1' then
          -- Mesmo polinômio do LFSR do Encryptor
          new_bit := lfsr_reg(7) XOR lfsr_reg(5) XOR lfsr_reg(4) XOR lfsr_reg(3);
          -- Descriptografa: XOR do dado de entrada cifrado com o keystream atual
          data_out <= data_in XOR lfsr_reg;
          out_valid <= '1';
          -- Avança o LFSR para o próximo estado
          lfsr_reg <= new_bit & lfsr_reg(7 downto 1);
        else
          out_valid <= '0';
        end if;
      end if;
    end if;
  end process;
end Behavioral;
