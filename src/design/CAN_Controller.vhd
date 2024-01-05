----------------------------------------------------------------------------------
-- Engineer: Tim Buddemeier, Christoph Limbeck, Kilian Muelder
-- 
-- Create Date: 12.12.2023
-- Module Name: CAN_Controller - Behavioral

-- Description: CAN-Controller for sending and receiving CAN messages.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CAN_Controller is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
          CAN_in : in STD_LOGIC;
          CAN_out : out STD_LOGIC;
          Msg_in : in STD_LOGIC_VECTOR(78 downto 0);
          process_message : in STD_LOGIC;
          Msg_out : out STD_LOGIC_VECTOR(78 downto 0);
          message_received : out STD_LOGIC
          );
end CAN_Controller;

architecture Behavioral of CAN_Controller is

component Software_Handler is
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
end component;
signal MSG_MEM_OUT_sw_handler          : STD_LOGIC_VECTOR(78 downto 0)  := (others => '0');
signal READY_TO_READ_sw_handler        : STD_LOGIC                      := '0';
signal MSG_TO_SEND_sw_handler          : STD_LOGIC_VECTOR(78 downto 0)  := (others => '0');
signal MSG_TO_SEND_STATUS_sw_handler   : STD_LOGIC                      := '0';

component Control_Unit
Port ( CAN :          in std_logic;
       READY_TO_SEND     : in  std_logic;
       COLL_DETECT       : in  std_logic;
       clk               : in  std_logic;
       reset             : in std_logic;
       CLK_WRITE         : in std_logic;
       EXECUTE_RECEIVING : out std_logic;
       EXECUTE_SENDING   : out std_logic );
end Component;
signal EXECUTE_RECEIVING_ctrl_unit   : std_logic;
signal EXECUTE_SENDING_ctrl_unit     : std_logic;

component Collision_Detection is
Port ( 
   RESET                 : in     STD_LOGIC;
   CLK                   : in     STD_LOGIC;
   CLK_READING           : in     STD_LOGIC;
   CAN_IN                : in     STD_LOGIC;
   CAN_OUT               : in     STD_LOGIC;
   MSG_IDENT             : in     STD_LOGIC_VECTOR(10 downto 0);
   START_SENDING         : in     STD_LOGIC;
   COLL_DETECTED         : out    STD_LOGIC
);
end component;
signal COLL_DETECTED_coll_dect : STD_LOGIC := '0';

component Sync_Clock 
Port ( STATUS_READ  : out std_logic;
       STATUS_WRITE : out std_logic;
       CAN          : in  std_logic;
       CLK          : in  std_logic;
       reset        : in  std_logic);
end component;
signal STATUS_READ_sync_clk     : std_logic;
signal STATUS_WRITE_sync_clk    : std_logic;

component Prepare_Sending_Data_Frame is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
          send_message : in STD_LOGIC;
          id : in STD_LOGIC_VECTOR(10 downto 0);
          dlc : in STD_LOGIC_VECTOR(3 downto 0);
          data : in STD_LOGIC_VECTOR(63 downto 0);
          data_frame : out STD_LOGIC_VECTOR(107 downto 0);
          execute_sending : out STD_LOGIC;
          message_sent : out STD_LOGIC;
          number_bits : out integer
          );
end component;
signal data_frame_prep_send_df : STD_LOGIC_VECTOR(107 downto 0) := (others => '0');
signal execute_sending_prep_send_df : STD_LOGIC := '0';
signal message_sent_prep_send_df : STD_LOGIC := '0';
signal number_bits_prep_send_df : integer := 0;

component Process_Receiving_Data_Frame is
    Port (clk : in STD_LOGIC;
          reset : in STD_LOGIC;
	      data_frame : in STD_LOGIC_VECTOR(82 downto 0);
	      process_data_frame : in STD_LOGIC;
          id : out STD_LOGIC_VECTOR(10 downto 0);
          dlc : out STD_LOGIC_VECTOR(3 downto 0);
          data : out STD_LOGIC_VECTOR(63 downto 0);
          message_received : out STD_LOGIC
          );
end component;
signal id_proc_recv_df : STD_LOGIC_VECTOR(10 downto 0) := (others => '0');
signal dlc_proc_recv_df : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
signal data_proc_recv_df : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
signal message_received_proc_recv_df : STD_LOGIC := '0';

component Execute_Sending is
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
end component;
signal ready_to_send_ex_send : STD_LOGIC := '0';
signal CAN_out_ex_send : STD_LOGIC := '1';
signal msg_ident_ex_send : STD_LOGIC_VECTOR(10 downto 0);

component Execute_Receiving is
Port (
    RESET                 : in     STD_LOGIC;
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
end component;
signal CAN_ex_recv                      : STD_LOGIC                     := '1';
signal DATA_FRAME_OUT_ex_recv           : STD_LOGIC_VECTOR(82 downto 0) := (others => '0');
signal DATA_FRAME_OUT_STATUS_ex_recv    : STD_LOGIC                     := '0';

-- Signale zum Zwischenspeichern zusammengehaengter Signale
signal msg_to_read_temp : STD_LOGIC_VECTOR(78 downto 0);
signal out_temp : STD_LOGIC;

begin

i_Software_Handler : Software_Handler
Port map(
    RESET => reset,
    CLK => clk,
    MSG_MEM_IN => Msg_in,
    READY_TO_PROCESS => process_message,
    MSG_MEM_OUT => MSG_MEM_OUT_sw_handler,
    READY_TO_READ => READY_TO_READ_sw_handler,
    MSG_TO_READ => msg_to_read_temp,
    MSG_TO_READ_STATUS => message_received_proc_recv_df,
    MSG_TO_SEND => MSG_TO_SEND_sw_handler,
    MSG_TO_SEND_STATUS => MSG_TO_SEND_STATUS_sw_handler
);

i_Control_Unit : Control_Unit
port map( READY_TO_SEND => ready_to_send_ex_send,
          COLL_DETECT => COLL_DETECTED_coll_dect,
          EXECUTE_RECEIVING => EXECUTE_RECEIVING_ctrl_unit,
          EXECUTE_SENDING => EXECUTE_SENDING_ctrl_unit,
          CLK_WRITE => STATUS_WRITE_sync_clk,
          clk => clk,
          reset => reset,
          CAN => CAN_in);
    
i_Collision_Detection : Collision_Detection
Port map(
    RESET => reset,
    CLK => clk,
    CLK_READING => STATUS_READ_sync_clk,
    CAN_IN => CAN_in,
    CAN_OUT => out_temp,
    MSG_IDENT => msg_ident_ex_send,
    START_SENDING => EXECUTE_SENDING_ctrl_unit,
    COLL_DETECTED => COLL_DETECTED_coll_dect
);
    
i_Sync_Clock : Sync_Clock
port map(
    STATUS_READ => STATUS_READ_sync_clk,
    STATUS_WRITE => STATUS_WRITE_sync_clk,
    CAN => CAN_in,
    clk => clk,
    reset => reset);
    
i_Prepare_Sending_Data_Frame : Prepare_Sending_Data_Frame
    port map(clk => clk,
             reset => reset,
             send_message => MSG_TO_SEND_STATUS_sw_handler,
             id => MSG_TO_SEND_sw_handler(78 downto 68),
             dlc => MSG_TO_SEND_sw_handler(67 downto 64),
             data => MSG_TO_SEND_sw_handler(63 downto 0),
             data_frame => data_frame_prep_send_df,
             execute_sending => execute_sending_prep_send_df,
             message_sent => message_sent_prep_send_df,
             number_bits => number_bits_prep_send_df
             );
    
i_Process_Receiving_Data_Frame : Process_Receiving_Data_Frame
    port map(clk => clk,
             reset => reset,
             data_frame => DATA_FRAME_OUT_ex_recv,
             process_data_frame => DATA_FRAME_OUT_STATUS_ex_recv,
             id => id_proc_recv_df,
             dlc => dlc_proc_recv_df,
             data => data_proc_recv_df,
             message_received => message_received_proc_recv_df
             );

i_Execute_Sending : Execute_Sending
    port map(clk => clk,
             reset => reset,
             data_frame => data_frame_prep_send_df,
             data_frame_in => execute_sending_prep_send_df,
             ready_to_send => ready_to_send_ex_send,
             execute_send => EXECUTE_SENDING_ctrl_unit,
             send => STATUS_WRITE_sync_clk,
             coll_detect => COLL_DETECTED_coll_dect,
             CAN_out => CAN_out_ex_send,
             number_bits => number_bits_prep_send_df,
             msg_ident => msg_ident_ex_send
             );
    
i_Execute_Receiving : Execute_Receiving
Port map(
    RESET                   => reset,
    CLK                     => clk,
    CLK_READING             => STATUS_READ_sync_clk,
    START_RECEIVING         => EXECUTE_RECEIVING_ctrl_unit,
    START_SENDING           => EXECUTE_SENDING_ctrl_unit,
    CLK_WRITING             => STATUS_WRITE_sync_clk,
    DATA_FRAME_OUT          => DATA_FRAME_OUT_ex_recv,
    DATA_FRAME_OUT_STATUS   => DATA_FRAME_OUT_STATUS_ex_recv,
    CAN_OUT                 => CAN_ex_recv,
    CAN_IN                  => CAN_in
);
    
--Beschaltung der Ausgangssignale und temporaerer Signale
CAN_out <= CAN_out_ex_send AND CAN_ex_recv;
out_temp <= CAN_out_ex_send AND CAN_ex_recv;
Msg_out <= MSG_MEM_OUT_sw_handler;
message_received <= READY_TO_READ_sw_handler;
msg_to_read_temp <= id_proc_recv_df & dlc_proc_recv_df & data_proc_recv_df;

end Behavioral;
