----------------------------------------------------------------------------------
-- Engineer: Tim Buddemeier
-- 
-- Create Date: 19.12.2023
-- Module Name: CAN_Line - Behavioral

-- Description: Enables CAN communication on a board without CAN transceiver.
--              Supports up to 5 CAN-Controllers.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CAN_Line is
    Port (CAN_in_0 : in STD_LOGIC;
          CAN_in_1 : in STD_LOGIC;
          CAN_in_2 : in STD_LOGIC;
          CAN_in_3 : in STD_LOGIC;
          CAN_in_4 : in STD_LOGIC;
          
          CAN_out : out STD_LOGIC
          );
end CAN_Line;

architecture Behavioral of CAN_Line is

begin
    CAN_out <= CAN_in_0 AND CAN_in_1 AND CAN_in_2 AND CAN_in_3 AND CAN_in_4;
end Behavioral;