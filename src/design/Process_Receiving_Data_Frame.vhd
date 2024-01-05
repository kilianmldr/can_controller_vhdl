----------------------------------------------------------------------------------
-- Engineer: Tim Buddemeier
-- 
-- Create Date: 12.12.2023
-- Module Name: Process_Receiving_Data_Frame - Behavioral

-- Description: Receives Data frame from Receiving component and sends relevant
--              data to Software Handler.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Process_Receiving_Data_Frame is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
	  data_frame : in STD_LOGIC_VECTOR(82 downto 0); -- Data frame without CRC-, ACK- and EOF-Field
	  process_data_frame : in STD_LOGIC;
          id : out STD_LOGIC_VECTOR(10 downto 0); -- only 11 bit identifier are supported in this implementation
          dlc : out STD_LOGIC_VECTOR(3 downto 0);
          data : out STD_LOGIC_VECTOR(63 downto 0);
	  message_received : out STD_LOGIC
          );
end Process_Receiving_Data_Frame;

architecture Behavioral of Process_Receiving_Data_Frame is

signal id_sig : STD_LOGIC_VECTOR(10 downto 0) := (others => '0');
signal dlc_sig : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
signal data_sig : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
signal message_received_sig : STD_LOGIC := '0';
signal data_frame_sig : STD_LOGIC_VECTOR(82 downto 0) := (others => '0');

type states is (IDLE, PROCESS_FRAME, SEND);
signal state : states := IDLE;

begin

proc_data_frame_proc : process(clk, reset)
begin
    if (reset = '0') then
        state <= IDLE;
        
	id_sig <= (others => '0');
        dlc_sig <= (others => '0');
	data_sig <= (others => '0');
	message_received_sig <= '0';
	data_frame_sig <= (others => '0');
    elsif (rising_edge(clk)) then
        case state is
            when IDLE =>
	        if (process_data_frame = '1') then
                    state <= PROCESS_FRAME;

		    id_sig <= data_frame(81 downto 71);
	            dlc_sig <= data_frame(67 downto 64);
                    data_frame_sig <= data_frame;
                else
                    state <= IDLE;

                    id_sig <= (others => '0');
                    dlc_sig <= (others => '0');
                    data_sig <= (others => '0');
                    message_received_sig <= '0';
                    data_frame_sig <= (others => '0');
                end if;

	    when PROCESS_FRAME =>
                state <= SEND;

                data_sig(63 downto 0) <= (others => '0');
		if(dlc_sig = "0000") then
		    null;
		else
		    data_sig(to_integer(unsigned(dlc_sig)) * 8 - 1 downto 0) <= data_frame_sig(63 downto 64 - to_integer(unsigned(dlc_sig)) * 8);
		end if;

            when SEND =>
		state <= IDLE;
		message_received_sig <= '1';

            when others =>
                null; 
        end case;
    else
        null;
    end if;
end process;

id <= id_sig;
dlc <= dlc_sig;
data <= data_sig;
message_received <= message_received_sig;

end Behavioral;
