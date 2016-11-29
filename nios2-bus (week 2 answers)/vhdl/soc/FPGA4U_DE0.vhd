-- Copyright (C) 1991-2015 Altera Corporation. All rights reserved.
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, the Altera Quartus II License Agreement,
-- the Altera MegaCore Function License Agreement, or other 
-- applicable license agreement, including, without limitation, 
-- that your use is for the sole purpose of programming logic 
-- devices manufactured by Altera and sold by Altera or its 
-- authorized distributors.  Please refer to the applicable 
-- agreement for further details.

-- PROGRAM		"Quartus II 64-Bit"
-- VERSION		"Version 15.0.0 Build 145 04/22/2015 SJ Full Version"
-- CREATED		"Tue Sep 29 11:06:29 2015"

LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

ENTITY FPGA4U_DE0 IS 
	PORT
	(
		CLOCK :  IN  STD_LOGIC;
		Button_n :  IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		KEY_n :  IN  STD_LOGIC_VECTOR(0 TO 0);
		LED_Reset :  OUT  STD_LOGIC;
		LED_Sel_B :  OUT  STD_LOGIC_VECTOR(0 TO 7);
		LED_Sel_G :  OUT  STD_LOGIC_VECTOR(0 TO 7);
		LED_Sel_R :  OUT  STD_LOGIC_VECTOR(0 TO 7);
		LED_SelC_n :  OUT  STD_LOGIC_VECTOR(0 TO 11);
		LedButton :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END FPGA4U_DE0;

ARCHITECTURE bdf_type OF FPGA4U_DE0 IS 

COMPONENT fpga4u
	PORT(clk : IN STD_LOGIC;
		 reset_n : IN STD_LOGIC;
		 in_buttons : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 out_LEDs : OUT STD_LOGIC_VECTOR(95 DOWNTO 0)
	);
END COMPONENT;

COMPONENT clk_pll
	PORT(inclk0 : IN STD_LOGIC;
		 areset : IN STD_LOGIC;
		 c0 : OUT STD_LOGIC;
		 locked : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT rgb_led96
GENERIC (DEFAULT_COLOR : STD_LOGIC_VECTOR(23 DOWNTO 0)
			);
	PORT(clk : IN STD_LOGIC;
		 reset : IN STD_LOGIC;
		 color : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
		 LEDs : IN STD_LOGIC_VECTOR(95 DOWNTO 0);
		 LED_Reset : OUT STD_LOGIC;
		 LED_SEL_B : OUT STD_LOGIC_VECTOR(0 TO 7);
		 LED_SEL_G : OUT STD_LOGIC_VECTOR(0 TO 7);
		 LED_SEL_R : OUT STD_LOGIC_VECTOR(0 TO 7);
		 LED_SELC_n : OUT STD_LOGIC_VECTOR(0 TO 11)
	);
END COMPONENT;

SIGNAL	clk :  STD_LOGIC;
SIGNAL	GND :  STD_LOGIC;
SIGNAL	reset :  STD_LOGIC;
SIGNAL	reset_n :  STD_LOGIC;
SIGNAL	VCC :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_0 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_1 :  STD_LOGIC_VECTOR(95 DOWNTO 0);


BEGIN 




b2v_inst : fpga4u
PORT MAP(clk => clk,
		 reset_n => reset_n,
		 in_buttons => Button_n,
		 out_LEDs => SYNTHESIZED_WIRE_1);


b2v_inst1 : clk_pll
PORT MAP(inclk0 => CLOCK,
		 areset => SYNTHESIZED_WIRE_0,
		 c0 => clk,
		 locked => reset_n);


SYNTHESIZED_WIRE_0 <= not KEY_n(0);



reset <= not reset_n;



b2v_inst4 : rgb_led96
GENERIC MAP(DEFAULT_COLOR => "000000001111111111111111"
			)
PORT MAP(clk => clk,
		 reset => reset,
         color => (others => '0'),
		 LEDs => SYNTHESIZED_WIRE_1,
		 LED_Reset => LED_Reset,
		 LED_SEL_B => LED_Sel_B,
		 LED_SEL_G => LED_Sel_G,
		 LED_SEL_R => LED_Sel_R,
		 LED_SELC_n => LED_SelC_n);


LedButton <= NOT(Button_n);




GND <= '0';
VCC <= '1';
END bdf_type;
