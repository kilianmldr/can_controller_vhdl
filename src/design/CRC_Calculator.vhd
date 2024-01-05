----------------------------------------------------------------------------------
-- Engineer: Tim Buddemeier
-- 
-- Create Date: 17.12.2023
-- Module Name: CRC_Calculator - Behavioral

-- Description: Calculates the CRC value of given input.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CRC_Calculator is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
          start_calc : in STD_LOGIC;
          input_data : in STD_LOGIC_VECTOR(82 downto 0);
          crc_out : out STD_LOGIC_VECTOR(14 downto 0);
          calc_done : out STD_LOGIC
         );
end CRC_Calculator;

architecture Behavioral of CRC_Calculator is

signal crc_out_sig : STD_LOGIC_VECTOR(14 downto 0) := (others => '0');
signal calc_done_sig : STD_LOGIC := '0';

type states is (IDLE, CALC, DONE);
signal state : states := IDLE;

constant generator_polynomial : STD_LOGIC_VECTOR(15 downto 0) := "1100010110011001";
signal data_with_zeros : STD_LOGIC_VECTOR(97 downto 0) := (others => '0');
signal crc_temp : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
signal counter : integer := 97;

begin

calc_crc_proc : process(clk, reset)
begin
    if (reset = '0') then
        crc_out_sig <= (others => '0');
        calc_done_sig <= '0';
        state <= IDLE;
        data_with_zeros <= (others => '0');
        crc_temp <= (others => '0');
        counter <= 97;
    elsif (rising_edge(clk)) then
        case state is
            when IDLE =>
                crc_out_sig <= (others => '0');
                calc_done_sig <= '0';
                state <= IDLE;
                data_with_zeros <= (others => '0');
                crc_temp <= (others => '0');
                counter <= 97;
                
                if(start_calc = '1') then
                    data_with_zeros(97 downto 15) <= input_data;
                    data_with_zeros(14 downto 0) <= (others => '0');
                    crc_temp <= data_with_zeros(97 downto 82);
                
                    state <= CALC;
                else
                    state <= IDLE;
                end if;
                
            when CALC =>
                if (crc_temp(15) = '0') then
                    if (counter = 14) then
                        state <= DONE;
                    else
                        crc_temp <= crc_temp(14 downto 0) & data_with_zeros(counter - 15);
                        state <= CALC;
                        counter <= counter - 1;
                    end if;
                else
                    crc_temp <= crc_temp XOR generator_polynomial;
                    state <= CALC; 
                end if;

            when DONE =>
                crc_out_sig <= crc_temp(14 downto 0);
                calc_done_sig <= '1';

                state <= IDLE;

            when others =>
                null;
        end case;
    end if;
end process;

crc_out <= crc_out_sig;
calc_done <= calc_done_sig;

end Behavioral;
