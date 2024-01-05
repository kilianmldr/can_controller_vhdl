----------------------------------------------------------------------------------
-- Engineer: Kilian Muelder
-- 
-- Create Date: 12.12.2023
-- Module Name: Execute_Receiving - Behavioral

-- Description: Diese Komponente empfaengt Daten vom CAN-Bus, fuehrt eine Integritaetspruefung 
--              durch und leitet die Daten weiter
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Execute_Receiving is
    Port ( RESET                 : in     STD_LOGIC;
           CLK                   : in     STD_LOGIC;
           CLK_READING           : in     STD_LOGIC;
           CLK_WRITING           : in     STD_LOGIC;
           START_RECEIVING       : in     STD_LOGIC;
           START_SENDING         : in     STD_LOGIC;
           DATA_FRAME_OUT        : out    STD_LOGIC_VECTOR(82 downto 0);
           DATA_FRAME_OUT_STATUS : out    STD_LOGIC;
           CAN_IN                : in     STD_LOGIC;
           CAN_OUT               : out    STD_LOGIC
         );
end Execute_Receiving;

architecture Behavioral of Execute_Receiving is

-- Komponente zur Pruefung der mitgelieferten Pruefsumme (CRC)
component CRC_Calculator is
    Port (clk        : in STD_LOGIC;
          reset      : in STD_LOGIC;
          start_calc : in STD_LOGIC;
          input_data : in STD_LOGIC_VECTOR(82 downto 0);
          crc_out    : out STD_LOGIC_VECTOR(14 downto 0);
          calc_done  : out STD_LOGIC
          );
end component;

-- Hilfssignale fuer CRC_Calculator Instanzierung
signal start_calc_sig : STD_LOGIC;
signal calc_done_sig  : STD_LOGIC;
signal input_data_sig : STD_LOGIC_VECTOR(82 downto 0);
signal crc_out_sig    : STD_LOGIC_VECTOR(14 downto 0);

-- Hilfssignale fuer Ausgangssignale
signal CAN_OUT_sig                  : STD_LOGIC := '1';
signal DATA_FRAME_OUT_sig           : STD_LOGIC_VECTOR(82 downto 0);
signal DATA_FRAME_OUT_STATUS_sig    : STD_LOGIC;

-- Zustandsautomat
type main_states is (IDLE, WAIT_FOR_BIT, IGNORE_BIT, BIT_SAVED, CHECK_WAIT_RISING_CLK, CHECK_WAIT_FALLING_CLK, SENDING_ACK, WAIT_FOR_EOF);
signal main_sm : main_states := IDLE;
type control_states is (IDLE, RECEIVING, SENDING);
signal control_sm : control_states := IDLE;

-- Zaehler zum Puffern und Verarbeiten der Nachricht
signal bit_counter_msg      : integer := 82;     --Zaehler fuer Anzahl gelesener Bits bis Daten; zaehlt von 82 runter
signal bit_counter_crc      : integer := 14;     --Zaehler fuer Anzahl gelesener Bits CRC-Feld; zaehlt von 14 runter
signal bit_counter_wait      : integer := 0;     --Warte-Zaehler, bis ACK gesendet werden darf; zaehlt hoch
signal same_bit_counter : integer := 0;     --Zaehler fuer Anzahl aufeinanderfolgender identischer Bits
signal data_bit_buffer  : integer := 0;     --Anzahl der Bits im Data-Field

--Puffer
signal msg_buffer  : STD_LOGIC_VECTOR(82 downto 0);     --Puffer für Nachricht bis einschliesslich Data-Field
signal crc_buffer  : STD_LOGIC_VECTOR(14 downto 0);     --Puffer für CRC-Field
signal dlc_buffer  : STD_LOGIC_VECTOR(3 downto 0);      --Puffer für DLC-Field
signal ack_buffer  : STD_LOGIC := '1';                         --Puffer fuer ACK-Signal, dass ausgegeben werden soll
signal previous_buffer : STD_LOGIC;


begin

crc_calc : CRC_Calculator
    port map (clk => clk,
              reset => reset,
              start_calc => start_calc_sig,
              input_data => input_data_sig,
              crc_out => crc_out_sig,
              calc_done => calc_done_sig
              );

control_proc : process(RESET, CLK)
begin
    if (RESET = '0') then
        control_sm <= IDLE;
    elsif (rising_edge(CLK)) then
        case control_sm is
            when IDLE =>
                if (START_RECEIVING = '1') then
                    control_sm <= RECEIVING;
                elsif (START_SENDING = '1' AND CAN_IN = '0') then
                    --Erst nach SENDING wechseln, wenn SOF gesendet wird
                    control_sm <= SENDING;
                end if;
            when RECEIVING =>
                if (main_sm = IDLE) then
                    control_sm <= IDLE;
                end if;
            when SENDING =>
                if (START_RECEIVING = '1') then
                    control_sm <= RECEIVING;
                elsif (main_sm = IDLE) then
                    control_sm <= IDLE;
                end if;
            when others =>
                control_sm <= IDLE;
        end case;
    end if;
end process;

main_proc : process(RESET, CLK)
begin
    if (RESET = '0') then
        --Alle Hilfssignale auf Standard-/IDLE-Werte setzen
        main_sm <= IDLE;
        DATA_FRAME_OUT_sig <= (others => '0');
        DATA_FRAME_OUT_STATUS_sig <= '0';
        CAN_OUT_sig <= '1';
        bit_counter_msg <= 82;
        bit_counter_crc <= 14;
        data_bit_buffer <= 0;
        same_bit_counter <= 0;
        msg_buffer <= (others => '0');
        crc_buffer <= (others => '0');
        dlc_buffer <= "0001";
        previous_buffer <= '1';
        start_calc_sig <= '0';
        input_data_sig <= (others => '0');
    elsif (rising_edge(CLK)) then
        case main_sm is
            when IDLE =>
                --Alle Hilfssignale auf Standard-/IDLE-Werte setzen
                main_sm <= IDLE;
                DATA_FRAME_OUT_sig <= (others => '0');
                DATA_FRAME_OUT_STATUS_sig <= '0';
                CAN_OUT_sig <= '1';
                bit_counter_msg <= 82;
                bit_counter_crc <= 14;
                data_bit_buffer <= 0;
                same_bit_counter <= 0;
                msg_buffer <= (others => '0');
                crc_buffer <= (others => '0');
                dlc_buffer <= "0001";
                previous_buffer <= '1';
                start_calc_sig <= '0';
                input_data_sig <= (others => '0');
                
                if ((START_RECEIVING = '1') OR (START_SENDING = '1' AND CAN_IN = '0')) then
                    --Wechsel von IDLE nach RECEIVING
                    main_sm <= WAIT_FOR_BIT;
                end if;
                
            when WAIT_FOR_BIT =>
                if (CLK_READING = '1') then
                    --speichern des aktuellen Bits vom Bus (Puffern)
                    previous_buffer <= CAN_IN;
                    
                    --speichern des DLC (Bit 15 bis Bit 18) und Umrechnen in Integer
                    if (bit_counter_msg = 67) then
                        dlc_buffer(3) <= CAN_IN;
                    elsif (bit_counter_msg = 66) then
                        dlc_buffer(2) <= CAN_IN;
                    elsif (bit_counter_msg = 65) then
                        dlc_buffer(1) <= CAN_IN;
                    elsif (bit_counter_msg = 64) then
                        dlc_buffer(0) <= CAN_IN;
                    end if;
                    data_bit_buffer <= (CONV_INTEGER(dlc_buffer) * 8);
                    
                    if (bit_counter_msg > 63) then
                        --Puffern der Nachricht bis einschliesslich DLC
                        msg_buffer(bit_counter_msg) <= CAN_IN;
                        bit_counter_msg <= bit_counter_msg - 1;
                        main_sm <= BIT_SAVED;
                    elsif (bit_counter_msg > (63 - data_bit_buffer)) then
                        --Puffern der Daten unter Beruecksichtigung eines Offsets, abhaengig von Datengroesse
                        msg_buffer(bit_counter_msg - 64 + data_bit_buffer) <= CAN_IN;
                        bit_counter_msg <= bit_counter_msg - 1;
                        main_sm <= BIT_SAVED;
                    elsif (bit_counter_crc >= 0) then
                        --Puffern der Pruefsumme
                        crc_buffer(bit_counter_crc) <= CAN_IN;
                        bit_counter_crc <= bit_counter_crc - 1;
                        main_sm <= BIT_SAVED;
                    end if;
                    
                    if ((bit_counter_msg < 82) AND previous_buffer = CAN_IN) then
                        --Das aktuelle Bit und das vorherige Bit besitzen den gleichen Pegel
                        same_bit_counter <= same_bit_counter + 1;
                    else
                        --Das aktuelle Bit und das vorherige Bit besitzen NICHT den gleichen Pegel
                        same_bit_counter <= 0;
                    end if;
                  
                end if; 
               
            when IGNORE_BIT =>
                --Ignoriere aktuelles Bit, da es ein Stopfbit ist
                if (CLK_READING = '1') then
                    main_sm <= BIT_SAVED;
                end if;
                
            when BIT_SAVED =>
                --Warte in diesem Zustand, bis CLK_READING wieder Low ist
                if (bit_counter_crc < 0 and control_sm = SENDING) then
                    if (START_SENDING = '0') then
                        main_sm <= IDLE;
                    end if;
                elsif (bit_counter_crc < 0 and control_sm = RECEIVING) then
                    --Fertig mit Puffern, Pruefsumme checken
                    main_sm <= CHECK_WAIT_RISING_CLK;
                    start_calc_sig <= '1';
                    input_data_sig(18 + data_bit_buffer downto 0) <= msg_buffer(82 downto 64) & msg_buffer((data_bit_buffer - 1) downto 0);   
                elsif (CLK_READING = '0') then
                    if (same_bit_counter >= 4) then
                        main_sm <= IGNORE_BIT;
                        same_bit_counter <= 0;
                    else
                        main_sm <= WAIT_FOR_BIT;
                    end if;
                end if;
            
            when CHECK_WAIT_RISING_CLK =>
                start_calc_sig <= '0';
                if (bit_counter_wait >= 2) then
                    --Wechsel mit der dritten Taktflanke von CLK_READING zu SENDIND_ACK
                    main_sm <= SENDING_ACK;
                elsif (CLK_READING = '1') then
                    bit_counter_wait <= bit_counter_wait + 1;
                    main_sm <= CHECK_WAIT_FALLING_CLK;
                end if;
            
            when CHECK_WAIT_FALLING_CLK =>
                if (CLK_READING = '0') then
                    main_sm <= CHECK_WAIT_RISING_CLK;
                end if;
                                
            when SENDING_ACK =>
                CAN_OUT_sig <= ack_buffer;
                if (CLK_READING = '1') then
                    main_sm <= WAIT_FOR_EOF;
                    CAN_OUT_sig <= '1';
                    
                    if (ack_buffer = '0') then
                        --ACK, sende Daten an weitere Komponenten
                        DATA_FRAME_OUT_sig <= msg_buffer;
                        DATA_FRAME_OUT_STATUS_sig <= '1';
                    end if;
                end if;
            
            when WAIT_FOR_EOF =>
                DATA_FRAME_OUT_STATUS_sig <= '0';
                if (CLK_READING = '0') then
                    main_sm <= IDLE;
                end if;
            
            when others =>
                -- Unerwarteter Zustand, fuehre Reset durch
                --Alle Hilfssignale auf Standard-/IDLE-Werte setzen
                main_sm <= IDLE;
                DATA_FRAME_OUT_sig <= (others => '0');
                DATA_FRAME_OUT_STATUS_sig <= '0';
                CAN_OUT_sig <= '1';
                bit_counter_msg <= 82;
                bit_counter_crc <= 14;
                data_bit_buffer <= 0;
                same_bit_counter <= 0;
                msg_buffer <= (others => '0');
                crc_buffer <= (others => '0');
                dlc_buffer <= (others => '0');
                start_calc_sig <= '0';
                input_data_sig <= (others => '0');
        end case;
    end if;

end process;

ack_proc : process(CLK, RESET)
begin
    if (RESET = '0') then
        ack_buffer <= '1';
    elsif (rising_edge(clk)) then
        if ((main_sm = CHECK_WAIT_RISING_CLK) OR (main_sm = CHECK_WAIT_FALLING_CLK) OR (main_sm = SENDING_ACK)) then
            if (calc_done_sig = '1') then
                if (crc_out_sig = crc_buffer) then
                    --ACK, da Pruefsummen gleich
                    ack_buffer <= '0';
                else
                    --NACK, da Pruefsummen ungleich
                    ack_buffer <= '1';
                end if;
            end if;
        else
            ack_buffer <= '1';
        end if;   
    end if;
end process;

-- Beschaltung der Ausgangssignale
CAN_OUT                 <= CAN_OUT_sig;
DATA_FRAME_OUT          <= DATA_FRAME_OUT_sig;
DATA_FRAME_OUT_STATUS   <= DATA_FRAME_OUT_STATUS_sig;

end Behavioral;