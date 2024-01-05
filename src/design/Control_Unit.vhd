----------------------------------------------------------------------------------
-- Engineer: Christoph Limbeck
-- 
-- Create Date: 30.12.2023 17:50:26
-- Design Name: 
-- Module Name: CONTROL_UNIT - Behavioral
-- Project Name: CAN-Controller
----------------------------------------------------------------------------------
 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
 
 
entity CONTROL_UNIT is
Port ( CAN :          in std_logic;
       READY_TO_SEND     : in  std_logic;
       COLL_DETECT       : in  std_logic;
       clk               : in  std_logic;
       clk_write         : in  std_logic;
       reset             :  in std_logic;
       EXECUTE_RECEIVING : out std_logic;
       EXECUTE_SENDING   : out std_logic );
end CONTROL_UNIT;
 
architecture Behavioral of CONTROL_UNIT is
 
--Statemachine Controle-Automat
type proc_states is (Idle, Prepare_Sending, Sending, Detection, Receiving);
signal s1 : proc_states := Idle;
--Statemachine EOF-Detection
type EOF_states is (Idle, Counter, Ready, EOF);
signal s2 : EOF_states := Idle;
 
signal EOF_sig : std_logic := '0';
signal Bus_not_in_use_sig : std_logic := '0';
signal EXECUTE_RECEIVING_sig : std_logic := '0';
signal EXECUTE_SENDING_sig : std_logic := '0';
 
signal Bit_COUNT : Integer :=0;
signal EOF_COUNT : Integer :=7;
signal READY_COUNT : Integer :=3;
 
begin
 
state_proc : process (clk, reset)
begin
    if(reset = '0') then
    s1 <= Idle;
elsif (rising_edge(clk)) then
    case s1 is
        when Idle =>
            EXECUTE_RECEIVING_sig <= '0';
            EXECUTE_SENDING_sig <= '0';
            if(CAN = '0') then
                s1 <= Receiving;
                EXECUTE_RECEIVING_sig <= '1';
            elsif ( READY_TO_SEND = '1') then
                s1 <= Prepare_Sending;
            end if;
        when Prepare_Sending =>
            if(CAN = '0') then
                s1 <= Receiving;
                EXECUTE_RECEIVING_sig <= '1';
            elsif ( BUS_NOT_IN_USE_SIG = '1') then
                s1 <= Sending;
            end if;
        when Sending =>
            EXECUTE_SENDING_sig <= '1';
            if(CAN = '0') then
                s1 <= Receiving;
                EXECUTE_RECEIVING_sig <= '1';
            else
                s1 <= Detection;
            end if;
        when Detection =>
            if(COLL_DETECT = '1') then
                s1 <= Receiving;
                EXECUTE_RECEIVING_sig <= '1';
                EXECUTE_SENDING_sig <= '0';
            elsif ( EOF_SIG = '1') then
                s1 <= Idle;
            end if;
        when Receiving =>
            EXECUTE_SENDING_sig <= '0';
            EXECUTE_RECEIVING_sig <= '0';
            if ( EOF_SIG = '1') then
                s1 <= Idle;
            end if;
    end case;
end if;
end process;
 
 
 
detec_proc : process (clk_write, reset)
begin
    if(reset = '0') then
    s2 <= Idle;
elsif (rising_edge(clk_write)) then
        Case s2 is
            when Idle =>
                Bit_Count <= 0;
                EOF_sig <= '0';
                Bus_not_in_use_sig <= '0';
                if (CAN = '1') then
                    s2 <= Counter;
                end if;
            when Counter =>
                Bit_Count <= Bit_Count + 1;
                EOF_sig <= '0';
                Bus_not_in_use_sig <= '0';
                if ( CAN = '0') then
                    s2 <= Idle;
                elsif ( Bit_Count = EOF_COUNT) then 
                    s2 <= EOF;
                elsif (Bit_Count = Ready_COUNT + EOF_COUNT) then
                    s2 <= Ready;
                end if;
            when EOF =>
                EOF_sig <= '1';
                if (CAN = '1') then
                    s2 <= Counter;
                    Bit_Count <= Bit_Count + 1;
                elsif (CAN = '0') then
                    s2 <= Idle;
                end if;
            when Ready =>
                Bus_not_in_use_sig <= '1';
                if ( CAN = '0' OR EXECUTE_SENDING_sig = '1') then
                    s2 <= Idle;
                end if; 
      end case;
    end if;
end process;
 
EXECUTE_RECEIVING <=  EXECUTE_RECEIVING_sig;
EXECUTE_SENDING <= EXECUTE_SENDING_sig;
 
end Behavioral;