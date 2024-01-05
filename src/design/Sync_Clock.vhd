----------------------------------------------------------------------------------
-- Engineer: Christoph Limbeck
-- 
-- Create Date: 12.12.2023
-- Module Name: Sync_Clock - Behavioral

-- Description: ENTER A SHORT DESCRIPTION
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Sync_Clock is
Port ( STATUS_READ  : out std_logic;
       STATUS_WRITE : out std_logic;
       CAN          : in  std_logic;
       CLK          : in  std_logic;
       reset        : in  std_logic);
end Sync_Clock;

architecture Behavioral of Sync_Clock is

-- Statemachine Haupt-Automat
type proc_states is (SyncSeg, Laufzeitsegment, Phasensegment1, Read, Phasensegment2);
signal s1 : proc_states := SyncSeg;
-- Statemachine Save-Automat
type save_states is (Idle, Save);
signal s2 : save_states := Idle;

signal STATUS_READ_SIG : std_logic := '0';
signal STATUS_WRITE_SIG : std_logic := '0';

-- CAN-Flanke gespeichert
signal SAVE_FALLING_EDGE_CAN : std_logic := '0';
-- CAN-Flanke verarbeitet
signal SAVE_ACCEPTED : std_logic := '0';

-- Zaehlvariablen
signal Laufzeit_COUNT : integer := 0;
signal Phase1_COUNT : integer := 0;
signal Phase2_COUNT : integer := 0;

-- Anzahl Quantenbits pro Abschnitt -1
signal Laufzeit_const : integer := 8;
signal Phase1_const : integer := 9;
signal Phase2_const : integer := 19;

begin

state_proc : process (clk, reset)
begin

if(reset = '0') then
    s1 <= SyncSeg;
    Phase1_COUNT <= 0;
    STATUS_WRITE_SIG <= '0';
    STATUS_READ_SIG <= '0';
elsif (rising_edge(clk)) then
    case s1 is
        when SyncSeg =>
            SAVE_ACCEPTED <= '0';
            Laufzeit_COUNT <= 0;
            Phase1_COUNT <= 0;
            Phase2_COUNT <= 0;
            STATUS_WRITE_SIG <= '1';
            Phase2_COUNT <= 0;
            s1 <= Laufzeitsegment;
            if(SAVE_FALLING_EDGE_CAN = '1' AND SAVE_ACCEPTED <= '0') then
                SAVE_ACCEPTED <= '1';
            end if;
            
        when Laufzeitsegment =>
            SAVE_ACCEPTED <= '0';
            STATUS_WRITE_SIG <= '0';
            Laufzeit_COUNT <= Laufzeit_COUNT + 1;
            if(SAVE_FALLING_EDGE_CAN = '1' AND SAVE_ACCEPTED <= '0') then
                SAVE_ACCEPTED <= '1';
                Phase1_COUNT <= Phase1_COUNT - Laufzeit_count;
            elsif(Laufzeit_COUNT = Laufzeit_const) then
                s1 <= Phasensegment1;
            end if;
            
        when Phasensegment1 =>
            SAVE_ACCEPTED <= '0';
            Phase1_COUNT <= Phase1_COUNT + 1;
            if(Phase1_COUNT = Phase1_const) then
                s1 <= Read;
            end if;
            
        when Read =>
            Phase1_COUNT <= 0;
            STATUS_READ_SIG <= '1';
            s1 <= Phasensegment2;
            
        when Phasensegment2 =>
            STATUS_READ_SIG <= '0';
            SAVE_ACCEPTED <= '0';
            Phase2_COUNT <= Phase2_COUNT + 1;
            if(SAVE_FALLING_EDGE_CAN = '1' AND SAVE_ACCEPTED <= '0') then
                SAVE_ACCEPTED <= '1';
                Phase2_COUNT <= Phase2_COUNT + (Phase2_const - Phase2_count);
            elsif(Phase2_COUNT = Phase2_const) then
                s1 <= SyncSeg;
            end if;
            
    end case;
end if;
end process;


save_proc : process (CAN, reset, clk)
begin

if(reset = '0') then
    SAVE_FALLING_EDGE_CAN <= '0';
    s2 <= Idle;
else 
    case s2 is
        when idle =>
            SAVE_FALLING_EDGE_CAN <= '0';
            if (falling_edge(CAN))then
                s2 <= save;
            end if;
        when save =>
            SAVE_FALLING_EDGE_CAN <= '1';
            if (SAVE_ACCEPTED = '1') then
                s2 <= idle;
            end if;
    end case;
end if;

end process;



STATUS_READ <= STATUS_READ_SIG;
STATUS_WRITE <= STATUS_WRITE_SIG;

end Behavioral;
