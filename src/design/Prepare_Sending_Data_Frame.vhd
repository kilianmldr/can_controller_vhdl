----------------------------------------------------------------------------------  
-- Engineer: Tim Buddemeier
-- 
-- Create Date: 12.12.2023
-- Module Name: Prepare_Sending_Data_Frame - Behavioral

-- Description: Sets up the Data frame with input from Software Handler.
--              Data frame is then sent to Execute_Sending component.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Prepare_Sending_Data_Frame is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
          send_message : in STD_LOGIC;
          id : in STD_LOGIC_VECTOR(10 downto 0); -- only 11 bit identifier are supported in this implementation
          dlc : in STD_LOGIC_VECTOR(3 downto 0);
          data : in STD_LOGIC_VECTOR(63 downto 0);
          data_frame : out STD_LOGIC_VECTOR(107 downto 0);
          execute_sending : out STD_LOGIC;
          message_sent : out STD_LOGIC;
          number_bits : out integer
          );
end Prepare_Sending_Data_Frame;

architecture Behavioral of Prepare_Sending_Data_Frame is

component CRC_Calculator is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
          start_calc : in STD_LOGIC;
          input_data : in STD_LOGIC_VECTOR(82 downto 0);
          crc_out : out STD_LOGIC_VECTOR(14 downto 0);
          calc_done : out STD_LOGIC
          );
end component;

signal start_calc_sig : STD_LOGIC := '0';
signal input_data_sig : STD_LOGIC_VECTOR(82 downto 0) := (others => '0');
signal crc_out_sig : STD_LOGIC_VECTOR(14 downto 0) := (others => '0');
signal calc_done_sig : STD_LOGIC := '0';

signal data_frame_sig : STD_LOGIC_VECTOR(107 downto 0) := (others => '0');
signal execute_sending_sig : STD_LOGIC := '0';
signal message_sent_sig : STD_LOGIC := '0';
signal number_bits_sig : integer := 0;

type states is (IDLE, CALC_CRC, WAIT_FOR_CRC, SEND);
signal state : states := IDLE;

begin

crc_calc : CRC_Calculator
    port map (clk => clk,
              reset => reset,
              start_calc => start_calc_sig,
              input_data => input_data_sig,
              crc_out => crc_out_sig,
              calc_done => calc_done_sig
              );

prep_data_frame_proc : process(clk, reset)
begin
    if (reset = '0') then
        state <= IDLE;
        
        data_frame_sig <= (others => '0');
        execute_sending_sig <= '0';
        message_sent_sig <= '0';
        number_bits_sig  <= 0;
        start_calc_sig <= '0';
        input_data_sig <= (others => '0');
    elsif (rising_edge(clk)) then
        case state is
            when IDLE =>
                if (send_message = '1') then 
                    state <= CALC_CRC;
                                
                    data_frame_sig(107) <= '0';                                                                                       -- SOF
                    data_frame_sig(106 downto 96) <= id;                                                                              -- ID
                    data_frame_sig(95 downto 93) <= (others => '0');                                                                  -- RTR, IDE, r0
                    data_frame_sig(92 downto 89) <= dlc;                                                                              -- DLC
                    data_frame_sig(88 downto 89 - to_integer(unsigned(dlc) * 8)) <= data(to_integer(unsigned(dlc)) * 8 - 1 downto 0); -- Data
                    data_frame_sig(73 - to_integer(unsigned(dlc)) * 8 downto 64 - to_integer(unsigned(dlc)) * 8) <= (others => '1');  -- CRC Delimiter, ACK, ACK Delimiter, EOF
		    number_bits_sig  <= 43 + to_integer(unsigned(dlc)) * 8;           
                else
                    state <= state;
                    
                    data_frame_sig <= (others => '0');
                    execute_sending_sig <= '0';
                    message_sent_sig <= '0';
                    number_bits_sig  <= 0;
                    start_calc_sig <= '0';
                    input_data_sig <= (others => '0');
                end if;
            
            when CALC_CRC =>
                state <= WAIT_FOR_CRC;

                start_calc_sig <= '1';
                input_data_sig(18 + to_integer(unsigned(dlc)) * 8 downto 0) <= data_frame_sig(107 downto 89 - to_integer(unsigned(dlc) * 8));   
                               
            when WAIT_FOR_CRC =>                
                if(calc_done_sig = '1') then
                    state <= SEND;
                    data_frame_sig(88 - to_integer(unsigned(dlc)) * 8 downto 74 - to_integer(unsigned(dlc)) * 8) <= crc_out_sig;      -- CRC
                else
                    state <= WAIT_FOR_CRC;
                end if;
                start_calc_sig <= '0';
         
            when SEND =>
                state <= IDLE;
                            
                execute_sending_sig <= '1'; 
                message_sent_sig <= '1';
                
            when others =>
                null;  
        end case;
    else
        null;
    end if;
end process;

data_frame <= data_frame_sig;
execute_sending <= execute_sending_sig;
message_sent <= message_sent_sig;
number_bits <= number_bits_sig;

end Behavioral;
