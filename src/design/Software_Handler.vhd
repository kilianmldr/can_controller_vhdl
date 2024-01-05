----------------------------------------------------------------------------------
-- Engineer: Kilian Muelder
-- 
-- Create Date: 12.12.2023
-- Module Name: Software_Handler - Behavioral

-- Description: Component for communication with external components
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Software_Handler is
Port ( 
       --Board-Signale
       RESET                : in    STD_LOGIC;
       CLK                  : in    STD_LOGIC;
       --Signale zur Kommunikation mit uebergeordneter/externer Software
       MSG_MEM_IN           : in    STD_LOGIC_VECTOR(78 downto 0);
       READY_TO_PROCESS     : in    STD_LOGIC;
       MSG_MEM_OUT          : out   STD_LOGIC_VECTOR(78 downto 0);
       READY_TO_READ        : out   STD_LOGIC;
       --Signale zur Kommunikation mit anderen Komponenten des CAN-Controllers
       MSG_TO_READ          : in    STD_LOGIC_VECTOR(78 downto 0);
       MSG_TO_READ_STATUS   : in    STD_LOGIC;
       MSG_TO_SEND          : out   STD_LOGIC_VECTOR(78 downto 0);
       MSG_TO_SEND_STATUS   : out   STD_LOGIC
);
end Software_Handler;

architecture Behavioral of Software_Handler is

--Hilfssignale fuer Ausgangssignale
signal MSG_MEM_OUT_sig          : STD_LOGIC_VECTOR(78 downto 0);
signal READY_TO_READ_sig        : STD_LOGIC;
signal MSG_TO_SEND_sig          : STD_LOGIC_VECTOR(78 downto 0);
signal MSG_TO_SEND_STATUS_sig   : STD_LOGIC;

--Zustandsautomaten
type states is (IDLE, PROC);
signal send_sm : states := IDLE;
signal receive_sm : states := IDLE;

begin

send_proc : process(RESET, CLK)
begin
    if (RESET = '0') then
        --Alle Signale auf Standard-/IDLE-Werte setzen
        send_sm <= IDLE;
        MSG_TO_SEND_sig <= (others => '0');
        MSG_TO_SEND_STATUS_sig <= '0';
    elsif (rising_edge(CLK)) then
        case send_sm is
            when IDLE =>
                MSG_TO_SEND_STATUS_sig <= '0';
                if (READY_TO_PROCESS = '1') then
                    --Zu sendende Nachricht (Daten-Frame) weiterleiten
                    MSG_TO_SEND_sig <= MSG_MEM_IN;
                    send_sm <= PROC;
                end if;
            when PROC =>
                --Status-Bit auf HIGH setzen und zurueckwechseln nach IDLE
                MSG_TO_SEND_STATUS_sig <= '1';
                send_sm <= IDLE;
            when others =>
                --Unerwarteter Zustand - Alle Signale auf Standard-/IDLE-Werte setzen
                send_sm <= IDLE;
                MSG_TO_SEND_sig <= (others => '0');
                MSG_TO_SEND_STATUS_sig <= '0';
        end case;
    end if;
end process;

receive_proc : process(RESET, CLK)
begin
    if (RESET = '0') then
        --Alle Signale auf Standard-/IDLE-Werte setzen
        receive_sm <= IDLE;
        MSG_MEM_OUT_sig <= (others => '0');
        READY_TO_READ_sig <= '0';
    elsif (rising_edge(CLK)) then
        case receive_sm is
            when IDLE =>
                READY_TO_READ_sig <= '0';
                if (MSG_TO_READ_STATUS = '1') then
                    --Empfangende Nachricht (Daten-Frame) weiterleiten
                    MSG_MEM_OUT_sig <= MSG_TO_READ;
                    receive_sm <= PROC;
                end if;
            when PROC =>
                --Status-Bit auf HIGH setzen und zurueckwechseln nach IDLE
                READY_TO_READ_sig <= '1';
                receive_sm <= IDLE;
            when others =>
                --Unerwarteter Zustand - Alle Signale auf Standard-/IDLE-Werte setzen
                receive_sm <= IDLE;
                MSG_MEM_OUT_sig <= (others => '0');
                READY_TO_READ_sig <= '0';
        end case;
    end if;
end process;

--Beschaltung der Ausgangssignale
MSG_MEM_OUT <= MSG_MEM_OUT_sig;
READY_TO_READ <= READY_TO_READ_sig;
MSG_TO_SEND <= MSG_TO_SEND_sig;
MSG_TO_SEND_STATUS <= MSG_TO_SEND_STATUS_sig;

end Behavioral;