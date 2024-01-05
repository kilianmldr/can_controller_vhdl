----------------------------------------------------------------------------------
-- Engineer: Tim Buddemeier
-- 
-- Create Date: 12.12.2023
-- Module Name: Execute_Sending - Behavioral

-- Description: Sends CAN frames to the bus.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Execute_Sending is
	Port (clk : in STD_LOGIC;
              reset : in STD_LOGIC;
	      data_frame : in STD_LOGIC_VECTOR(107 downto 0);
	      data_frame_in : in STD_LOGIC;
	      ready_to_send : out STD_LOGIC;  
	      execute_send : in STD_LOGIC;
	      send : in STD_LOGIC;
	      coll_detect : in STD_LOGIC;
	      CAN_out : out STD_LOGIC;
	      number_bits : in integer;
	      msg_ident : out STD_LOGIC_VECTOR(10 downto 0)
          );
end Execute_Sending;

architecture Behavioral of Execute_Sending is

signal ready_to_send_sig : STD_LOGIC := '0';
signal CAN_out_sig : STD_LOGIC := '1';

type states is (IDLE, READY, SENDING);
signal state : states := IDLE;
signal counter : integer := 107;
signal data_frame_sig : STD_LOGIC_VECTOR(107 downto 0) := (others => '0');
signal number_bits_sig : integer := 0;
signal last_sent_bit : STD_LOGIC := '-';
signal counter_stuff_bits: integer := 0;

begin

exe_sending_proc : process(clk, send, reset)
begin
    if(reset = '0') then
        ready_to_send_sig <= '0';
        CAN_out_sig <= '1';
        counter <= 107;
        data_frame_sig <= (others => '0');
        number_bits_sig <= 0;
        last_sent_bit <= '-';
        counter_stuff_bits <= 0;
    elsif(rising_edge(clk) OR rising_edge(send)) then
        case state is
            when IDLE =>
                ready_to_send_sig <= '0';
                CAN_out_sig <= '1';
                counter <= 107;
                data_frame_sig <= (others => '0');
                number_bits_sig <= 0;
                last_sent_bit <= '-';
                counter_stuff_bits <= 0;
                if(data_frame_in = '1') then
                    data_frame_sig <= data_frame;
                    number_bits_sig <= number_bits;
                    ready_to_send_sig <= '1';
                    state <= READY;
                else
                    state <= IDLE;
                end if;
            
            when READY =>
                if(execute_send = '1') then
                    ready_to_send_sig <= '0';
                    state <= SENDING;
                else
                    state <= READY;
                end if;
                
            when SENDING =>
                if(coll_detect = '0') then
                    if(rising_edge(send)) then
                        if(counter_stuff_bits = 4) then
                            if(last_sent_bit = '1') then
                                CAN_out_sig <= '0';
                            else
                                CAN_out_sig <= '1';
                            end if;
                            counter_stuff_bits <= 0;
                        else
                            if(counter = 107 - number_bits_sig) then
                                state <= IDLE;
                            else
                                CAN_out_sig <= data_frame_sig(counter);
                                if(counter < 118 - number_bits_sig) then
                                    counter_stuff_bits <= 0;
                                else
                                    if(last_sent_bit = data_frame_sig(counter)) then
                                        counter_stuff_bits <= counter_stuff_bits + 1;
                                    else
                                        last_sent_bit <= data_frame_sig(counter);
                                        counter_stuff_bits <= 0;
                                    end if;
                                end if;
                                counter <= counter - 1;
                            end if;
                        end if;
                    else
                        state <= SENDING;
                    end if;
                else
                    ready_to_send_sig <= '1';
                    CAN_out_sig <= '1';
                    counter <= 107;
		    last_sent_bit <= '-';
		    counter_stuff_bits <= 0;
		    state <= READY;
                end if;
            
            when others =>
                null;
        end case;
    else
        null;       
    end if;
end process;

CAN_out <= CAN_out_sig;
ready_to_send <= ready_to_send_sig;
msg_ident <= data_frame_sig(106 downto 96);
				
end Behavioral;
