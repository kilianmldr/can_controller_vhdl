----------------------------------------------------------------------------------
-- Engineer: Kilian Muelder
-- 
-- Create Date: 12.12.2023
-- Module Name: Collision_Detection - Behavioral

-- Description: Wahrend der Controller einen Message Identifier auf den Bus sendet,
--              prueft diese Komponente, ob es dabei zu Kollisionen kommt
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Collision_Detection is
Port ( RESET                 : in     STD_LOGIC;
       CLK                   : in     STD_LOGIC;
       CLK_READING           : in     STD_LOGIC;
       CAN_IN                : in     STD_LOGIC;
       CAN_OUT               : in     STD_LOGIC;   
       MSG_IDENT             : in     STD_LOGIC_VECTOR(10 downto 0);
       START_SENDING         : in     STD_LOGIC;
       COLL_DETECTED         : out    STD_LOGIC
     );
end Collision_Detection;

architecture Behavioral of Collision_Detection is

-- Hilfssignale fuer Ausgangssignale
signal COLL_DETECTED_sig : STD_LOGIC;

-- Zustandsautomat
type states is (IDLE, CHECKING, WAIT_FALLING_CLK, COLLISION, WAIT_END);
signal main_sm : states := IDLE;

--Zaehlersignale
signal bit_counter : integer := 0;     --Zaehler fuer Anzahl verglichener Bits

begin

main_proc : process(RESET, CLK)
begin
    if (RESET = '0') then
        --Alle Hilfssignale auf Standard-/IDLE-Werte setzen
        main_sm             <= IDLE;
        COLL_DETECTED_sig   <= '0';
        bit_counter         <= 0;

    elsif (rising_edge(CLK)) then
        case main_sm is
            when IDLE =>
                --Alle Hilfssignale auf Standard-/IDLE-Werte setzen
                main_sm             <= IDLE;
                COLL_DETECTED_sig   <= '0';
                bit_counter         <= 0;
                
                if (START_SENDING = '1') then
                    main_sm <= CHECKING;
                end if;
            when CHECKING =>
                if (CLK_READING = '1') then
                    if (CAN_IN = CAN_OUT) then
                        --Vergleich positiv
                        main_sm <= WAIT_FALLING_CLK;
                        bit_counter <= bit_counter + 1;
                    else
                        --Vergleich negativ
                        main_sm <= COLLISION;
                        COLL_DETECTED_sig <= '1';
                    end if;
                end if;
            when WAIT_FALLING_CLK =>
                if (bit_counter >= 12) then
                    --Alle Bits erfolgreich verglichen
                    main_sm <= WAIT_END;
                elsif (CLK_READING = '0') then
                    main_sm <= CHECKING;
                end if;
            when COLLISION =>
                COLL_DETECTED_sig <= '0';
                main_sm <= WAIT_END;
            when WAIT_END =>
                if (START_SENDING = '0') then
                    main_sm <= IDLE;
                end if;
            when others =>
                --Unerwarteter Zustand - Alle Hilfssignale auf Standard-/IDLE-Werte setzen
                main_sm             <= IDLE;
                COLL_DETECTED_sig   <= '0';
                bit_counter         <= 0;
        end case;
    end if;
end process;

--Beschaltung der Ausgangssignale
COLL_DETECTED <= COLL_DETECTED_sig;
end Behavioral;