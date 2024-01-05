----------------------------------------------------------------------------------
-- Engineer: Tim Buddemeier, Christoph Limbeck, Kilian Muelder
-- 
-- Create Date: 17.12.2023
-- Module Name tb_CAN_Controller - Behavioral

-- Description: Testbench for CAN_Controller module.
-- Recommended simulation time: 1 s
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_CAN_Controller is
end tb_CAN_Controller;

architecture Behavioral of tb_CAN_Controller is

component CAN_Controller is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
          CAN_in : in STD_LOGIC;
          CAN_out : out STD_LOGIC;
          msg_in : in STD_LOGIC_VECTOR(78 downto 0);
          process_message : in STD_LOGIC;
          msg_out : out STD_LOGIC_VECTOR(78 downto 0);
          message_received : out STD_LOGIC
          );
end component;

component CAN_Line is
    Port (CAN_in_0 : in STD_LOGIC;
          CAN_in_1 : in STD_LOGIC;
          CAN_in_2 : in STD_LOGIC;
          CAN_in_3 : in STD_LOGIC;
          CAN_in_4 : in STD_LOGIC;
          
          CAN_out : out STD_LOGIC
          );
end component;

signal clk : STD_LOGIC;
signal reset : STD_LOGIC;

signal CAN_out_1 : STD_LOGIC;
signal msg_in_1 : STD_LOGIC_VECTOR(78 downto 0);
signal process_message_1 : STD_LOGIC;
signal msg_out_1: STD_LOGIC_VECTOR(78 downto 0);
signal message_received_1 : STD_LOGIC;

signal CAN_out_2 : STD_LOGIC;
signal msg_in_2 : STD_LOGIC_VECTOR(78 downto 0);
signal process_message_2 : STD_LOGIC;
signal msg_out_2: STD_LOGIC_VECTOR(78 downto 0);
signal message_received_2 : STD_LOGIC;

signal CAN_out_Line : STD_LOGIC;

begin

i_CAN_Controller_1 : CAN_Controller
    port map(clk => clk,
             reset => reset,
             CAN_in => CAN_out_Line,
             CAN_out => CAN_out_1,
             msg_in => msg_in_1,
             process_message => process_message_1,
             msg_out => msg_out_1,
             message_received => message_received_1
             );
    
i_CAN_Controller_2 : CAN_Controller
    port map(clk => clk,
             reset => reset,
             CAN_in => CAN_out_Line,
             CAN_out => CAN_out_2,
             msg_in => msg_in_2,
             process_message => process_message_2,
             msg_out => msg_out_2,
             message_received => message_received_2
             );
    
i_CAN_Line : CAN_LINE
    port map (CAN_in_0 => CAN_out_1,
              CAN_in_1 => CAN_out_2,
              CAN_in_2 => '1',
              CAN_in_3 => '1',
              CAN_in_4 => '1',
          
              CAN_out => CAN_out_Line
              );
    
clk_proc : process
begin
    clk <= '0';
    wait for 0.5 ns;
    clk <= '1';
    wait for 0.5 ns;
end process;

stimulus : process
begin
    reset <= '0';
    msg_in_1 <= (others => '0');
    process_message_1 <= '0';
    msg_in_2 <= (others => '0');
    process_message_2 <= '0';

    
    wait for 100 ns;
    reset <= '1';
    
    wait for 100 ns;
    -- Two Messages at the same time. Both controllers start sending. Message sending with higher
    -- identifier stops and starts sending after other message is received.
    process_message_1 <= '1';
    msg_in_1 <= "0000001010000010000000000000000000000000000000000000000000000000000000000000001";
                    -- Identifier: 00000010100
                    -- DLC: 0001
                    -- Data: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000001
                    
    process_message_2 <= '1';
    msg_in_2 <= "0000000110000100000000000000000000000000000000000000000000000000000000101110111";
                    -- Identifier: 00000001100
                    -- DLC: 0010
                    -- Data: 00000000 00000000 00000000 00000000 00000000 00000000 00000001 01110111
    
    wait for 50 ns;
    msg_in_1 <= (others => '0');
    process_message_1 <= '0';
    msg_in_2 <= (others => '0');
    process_message_2 <= '0';

    wait; -- wait for ever
end process;  

end Behavioral;