; Changes:
; 1. Adapted for zasm assembler including making things case sensitive
; 2. Adapted for RC2014 and modified init32K.asm
; 3. Removed/commented out all non-RS232 code
; 4. Added W command to set the start of the workspace where we want to load the Intel HEX file. This is needed for
; hex files that start at address 0000H instead of somewhere in RAM.
;
; Changes to Josh's original code are copyright Ben Chong and freely licensed to the community
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;Z80 Membership Card Firmware, Beta Version 1.1, Dec 14, 2014
;File: ZMCv11.asm
;
	MACRO 	VERSION_MSG
;	DB	CR,LF,"Z80 MEMBERSHIP CARD.  Beta v1.1, Dec 14, 2014",CR,LF,EOS
	DB	CR,LF,"Modified Monitor based on ZMC Beta v1.1",CR,LF,EOS
	ENDM

;	Table of Contents
;	Acknowledgments
;	Preface i	Acknowledgments, Revisions, notes
;	Preface ii	Description, Operation
;	Preface iii	Memory Mapping, I/O Mapping
;	Chapter 1	Page 0 interrupt & restart locations
;	Chapter 2	Startup Code
;	Chapter 3	Main Loop, MENU selection
;	Chapter 4	Menu operations. Loop back, Memory Enter/Dump/Execute, Port I/O
;	Chapter 5	Supporting routines. GET_BYTE, GET_WORD, PUT_BYTE, PUT_HL, PRINT, DELAY, GET/PUT_REGISTER
;	Chapter 6	Menu operations. ASCII HEXFILE TRANSFER
;	Chapter 7	Menu operations. XMODEM FILE TRANSFER
;	Chapter 8	Menu operations. RAM TEST
;	Chapter 9	Menu operations. DISASSEMBLER - Deleted
;	Chapter 10	BIOS.  PUT_CHAR (RS-232 & LED), GET_CHAR (RS-232), IN_KEY (Keyboard)
;	Chapter 11	ISR.  RS-232 Receive, LED & Keyboard scanning, Timer tic counting
;	Appendix A	LED FONT
;	Appendix B	RAM. System Ram allocation (LED_Buffer, KEY_Status, RX Buffer, etc)
;	Appendix C	Z80 Instruction Reference
;
;
;
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface i - Acknowledgments
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;Assemble using ver 2.0 of the ASMX assembler by Bruce Tomlin
;
;Command to assemble:
;
;   asmx20 -l -o -e -C Z80 ZMC.asm
;
;
;Z80 Membership Card hardware by Lee Hart.
;
;Operation, Documentation and Consultation by Herb Johnson
;
;Firmware by Josh Bensadon. Date: Feb 10, 2014
;
;Operation concepts adapted from the Heathkit H8 computer.
;
;Revision.
;0.1 	- RS-232 Full duplex operational. June 15
;0.2 	- LED Put_Char routine operational
;	- Keyboard Scanning operational
;	- Demo Keyboard or RS-232 input Displays on both LED & RS-232 output
;0.3	- Added a modified version of my IMSAI 8080 monitor
;	- Modified Dump routine to output "M"
;	- Added "M" function to enter Memory bytes
;	- Fixed code to assemble using ASMX.
;0.4	- First Beta Version.
;	- Added Rest of Keyboard functionality (Alter Register, Memory, I/O, GO)
;0.5	- Halt reset working
;	- Single Step working
;0.6	- Rewrote Register Save
;	- F-0 Reset detection working
;	- Fixed Display mode after Step
;	- Removed "Test Code"
;0.7	- Repurposed LED x7 to activate beeper on key down events
;0.8	- Corrected bug introduced in v0.7 with lights
;0.9	- Documentation improvements
;	- UiVec now a Subroutine, terminate with RET
;1.0	- Documentation improvements
;	- Get Hexfile routine modified to timeout if bad data or if end-of-file record not received
;	- X-Modem send & receive timeout values increased to allow more time to open/send or receive files
;1.1	- Added Single Step to RS-232 Menu
;
;Note.  Some assemblers might choose to substitute Long Jumps (JP) with Relative Jumps (JR) when possible.
;	These two instructions have different execution times.  Generally, this would not be an issue, however,
;	within the RS-232 bit banging routines, timing is critical and it may not tolerate the substitution.
;	The ASMX assembler supported by Herb Johnson's web site works great and does not substitute.
;
;
;
;
;
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface ii - Description, Operation
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;- - - HARDWARE - - -
;
;The Hardware is comprised of two boards, the CPU and Front Panel (FP) boards.
;
;CPU Board:
; Z80 CPU, 4Mhz Clock, 5V Regulator, 32K EPROM (w/firmware), 32K RAM, 8 bit input port, 8 bit output port
;
;Front Panel Board:
; Terminal for Power & RS-232 connection, Timer for 1mSec interrupt, LED Display Driver & Keyboard Matrix.
;
; LED Display: 7 x 7-Segment displays (d1 to d7) and 7 annunciator leds (x1 to x7) below the 7 digits.
;
;    d1   d2   d3   d4   d5   d6   d7
;    _    _    _    _    _    _    _
;   |_|  |_|  |_|  |_|  |_|  |_|  |_|
;   |_|  |_|  |_|  |_|  |_|  |_|  |_|
;    _   _      _   _     _   _     _
;    x1  x2     x3  x4    x5  x6    x7
;
; Keyboard: 16 keys labeled "0" to "F" designated as a HEX keyboard
; The "F" key is wired to a separate input line, so it can be used as a "Shift" key to produce an extended number of key codes.
; The "F" and "0" keys are also wired directly to an AND gate, so that pressing both these keys produces a HARD reset.
;
;- - - FIRMWARE - - -
;
;The Firmware provides a means to control the system through two interfaces.
;Control is reading/writing to memory, registers, I/O ports; having the Z80 execute programs in memory or halting execution.
;The two interfaces are:
; 1. The Keyboard and LED display
; 2. A terminal (or PC) connected at 9600,N,8,1 to the RS-232 port.
;
;- - - The Keyboard and LED display interface - - -
;
;While entering commands or data, the annunciator LED's will light according to the state of the operation or system as follows:
;
; x1 = Enter Register
; x2 = Enter Memory Location
; x3 = Alter Memory/Register
; x4 = Send Data to Output Port
; x5 = Monitor Mode (Default Mode upon Power up)
; x6 = Run Mode
; x7 = Beeper (on key press)
;
;Keyboard Functions:
;
; "F" & "0" - Forces a HARD reset to the Z80 and restarts the system.  See System Starting for additional details.
;
; While in Command Mode:
; "F" & "E" - Does a SOFT reset.
; "0" - Display a Register.  x1 lights and you have a few seconds to select which register to display.
; "E" - Display Memory.  x2 lights and you have a few seconds to enter a memory location.
; "5" - Display Input Port.  x2 lights and you have a few seconds to enter a port address.
; "6" - Output Port. x2 lights and you have a few seconds to enter a port address,
;	then x4 lights and you can enter data to output, new data may be sent while x4 remains lit.
; "A" - Advance Display Element.  Advances to next Register, Memory address or Port address.
; "B" - Backup Display Element.  Backs up to previous Register, Memory address or Port address.
; "4" - Go. Preloads all the registers ending with the PC being set, hence it causes execution at the current PC register.
; "D" - Alter/Output.  Depending on the display, Selects a different Register, Memory Address, Port or Sends Port Output.
;	Note, "D" will only send to that Output Port, to change which port, Command 6 must be used.
;
;
;- - - The Terminal interface - - -
;
;Through a Terminal, there are more features you can use.  Entering a question mark (?) or another unrecognized command will display a list of available commands.
;Most commands are easy to understand, given here are the few which could use a better explaination.
;
; C - Continous Dump.	Works like the D command but without pausing on the page boundaries.  This is to allow the text capturing of a dump.
;			The captured file can then be later sent back to the system by simply sending the text file through an ASCII upload.
; M - Multiple Input.	Allows the entering of data in a format that was previously sent & saved in an ASCII text file.
; R - Register.		Entering R without specifiying the register will display all the registers.
;			A specific register can be displayed or set if specified.  eg. R HL<CR>, R HL=1234<CR>
; T - Test RAM		Specify the first and last page to test, eg T 80 8F will test RAM from 8000 to 8FFF.
; X - Xmodem Transfers	Transfers a binary file through the XModem protocol.  Enter the command, then configure your PC to receive or send a file.
;			eg. X U 8000<CR> will transfer a file from your PC to the RAM starting at 8000 for the length of the file (rounded up to the next 128 byte block).
;			eg. X D 8000 0010 will transfer a file from RAM to your PC, starting at 8000 for 10 (16 decimal) blocks, hence file size = 2K.
; : - ASCII HEX Upload	The ":" character is not entered manually, it is part of the Intel HEX file you can upload through ASCII upload.
;			eg. While at the prompt, just instruct your PC's terminal program to ASCII upload a .HEX file.
;
;
;- - - System Starting - - -
;When the Z80 starts execution of the firmware at 0000, all the registers are saved for possible examination and the optional modification.
;There are many ways the Z80 can come to execute at 0000.  The firmware then tries to deterimine the cause of the start up and will respond differently.
;Regardless of why, the firmware first saves all the registers to RAM and saves the last Stack word assuming it was the PC.
;A test is done to check if the FP board is present.
;-If there is no FP board, then the firmware will either RUN code in RAM @8002 (if there's a valid signature of 2F8 @8000) or HALT.
;Next, 8 bytes of RAM is tested & set for/with a signature.
;-If there isn't a signature, it is assumed the system is starting from a powered up condition (COLD Start), no further testing is done.
;When the signature is good (WARM Start), more tests are done as follows:
;Test Keyboard for "F"&"E" = Soft Reset from Keyboard
;Test Keyboard for "F"|"0" = Hard Reset from Keyboard
;Test Last instruction executed (assuming PC was on Stack) for RST 0 (C7) = Code Break
;Test RS-232 Buffer for Ctrl-C (03) = Soft Reset from Terminal
;If cause cannot be deterimined, it is assumed an external source asserted the RESET line.
;
;The Display will indicate the cause of reset as:
;	"COLD 00"  (Power up detected by lack of RAM Signature)
;	"SOFT ##"  (F-E keys pressed)
;	"STEP ##"  (Single Step)
;	"^C   ##"  (Ctrl-C)
;	"HALT ##"  (HALT Instruction executed)
;	"F-0  ##"  (F-0 Hard Reset)
;	"RST0 ##"  (RST0 Instruction executed)
;	"HARD ##"  (HARD Reset by other)
;
;Where the number after the reset shows the total number of resets.
;
;The PC will be changed to 8000 on Cold resets.
;
;
;- - - Firmware BIOS - - -
;
;There are routines which can be called from your program to access the RS-232 Bit banging interface, Keyboard or Display inteface or Timer interrupt services.
;
;Label		Addr.	Description
;Sel_RS232	xxxx	Sets
;Put_Char	xxxx	Sends the ASCII character in A to the RS-232 port or LED Display (no registers, including A, are affected)
;Put_HEX	xxxx	Converts the low nibble of A to an ASCII character 0 to F and sends to RS-232 or LED Display
;Put_Byte	xxxx	Converts/sends both high and low nibbles of A (sends 2 ASCII Character) to RS-232 or LED Display










; Z80 - Registers
;
; A F   A' F'
; B C   B' C'
; D E   D' E'
; H L   H' L'
;    I R
;    IX
;    IY
;    SP
;    PC


;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Preface iii- Memory Mapping, I/O Mapping
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

;String equates
CR		equ	0x0D
LF		equ	0x0A
EOS		equ	0x00


;Memory Mapping
;
;0x0000 - 0x7FFF	EPROM
;0x8000 - 0xFFFF	RAM

#if 0
Port40		equ	0x40	;LED DISPLAY, RS-232 TXD/RXD AND KEYBOARD
#endif

;I/O
;0x40	Input/Output
;	Output bits	*Any write to output will clear /INT AND advance the Scan/Column Counter U2A.
;	0 = Segment D OR LED7       --4--
;	1 = Segment E OR LED6      2|   |3
;	2 = Segment F OR LED5       |   |
;	3 = Segment B OR LED4       --5--
;	4 = Segment A OR LED3      1|   |6
;	5 = Segment G OR LED2       |   |
;	6 = Segment C OR LED1       --0--
;	7 = RS-232 TXD (Bit Banged) = 1 when line idle, 0=start BIT
;
;	Input Bits
;	0 = Column Counter BIT 0 (Display AND Keyboard)
;	1 = Column Counter BIT 1 (Display AND Keyboard)
;	2 = Column Counter BIT 2 (Display AND Keyboard)
;	3 = 0 when Keys 0-7 are pressed (otherwise = 1), Row 0
;	4 = 0 when Keys 8-E are pressed (otherwise = 1), Row 1
;	5 = 1 when Key F is pressed (otherwise = 0), Key F is separate so it may be used as A Shift Key
;	6 = 1 when U2B causes an interrupt, Timer Interrupt (Send Output to reset)
;	7 = RS-232 RXD (Bit Banged) = 1 when not connected OR line idle, 0=first start BIT
;
;	Bit 5 allows Key F to be read separately to act as A "Shift" key when needed.
;	Bits 0-2 can be read to ascertain the Display Column currently being driven.



;	Chapter 1	Page 0 interrupt & restart locations
;
;                        *******    *******    *******    *******
;                       *********  *********  *********  *********
;                       **     **  **     **  **     **  **     **
;                       **     **  **     **  **     **  **     **
;---------------------  **     **  **     **  **     **  **     **  ---------------------
;---------------------  **     **  **     **  **     **  **     **  ---------------------
;                       **     **  **     **  **     **  **     **
;                       **     **  **     **  **     **  **     **
;                       *********  *********  *********  *********
;                        *******    *******    *******    *******

; [CODE]
; LABEL INSTRUCT PARAMETER(s)              ADR/OPCODE    ASCII


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 2	Startup Code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

		.ORG 150H		; Same as bas32K.asm
		
		; This part is from bas32K.asm
		; int32K.asm is written to jump here
COLD:   	JP      INIT_MENU	; STARTB          ; Jump for cold start
WARM:   	JP      INIT_MENU	; WARMST          ; Jump for warm start

;-------------------------------------------------------------------------------- RESET LDRTUP CODE
RESETLDRT:
;Save Registers & SET sp
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Save Input State to Temp location (LED DISPLAY Buffer)
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Test Hardware - FP Board Present?
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Execute RAM program if NO FP Board Present
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Deterimine Reason for RESET ie entering Monitor Mode
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Init all System RAM, enable interrupts
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 3	Main Loop, RS-232 MONITOR, MENU selection
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************
;************************************************************************************


;Monitor
;Functions:
; -Dump, Edit & Execute Memory.
; -Input Port and Output Port.
; -RAM Test
; -ASCII Upload intel HEX file
; -XMODEM up/down load to Memory
;
; D XXXX YYYY	Dump memory from XXXX to YYYY
; E XXXX	Edit memory starting at XXXX (type an X and press enter to exit entry)
; G XXXX	GO starting at address XXXX (Monitor program address left on stack)
; I XX		Input from I/O port XX and display as hex
; O XX YY	Output to I/O port XX byte YY
; L		Loop back test
; X U XXXX	XMODEM Upload to memory at XXXX (CRC or CHECKSUM)
; X D XXXX CCCC	XMODEM Download from memory at XXXX for CCCC number of 128 byte blocks
; :ssHHLLttDDDDDD...CS   -ASCII UPLOAD Intel HEX file to Memory.  Monitor auto downloads with the reception of a colon.
; R XX YY	RAM TEST from pages XX to YY
; V		Report Version


;----------------------------------------------------------------------------------------------------; MAIN MENU
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; MAIN MENU

INIT_MENU:
		; Initial hex_buffer for Intel HEX uploads
		LD	HL, 0000H
		LD	(hex_buffer), HL
		
MAIN_MENU:	LD	SP, StackTop	; Reset Stack = 0xFF80
		EI			; BC Enable interrupts
		LD	HL, MAIN_MENU	;Push Mainmenu onto stack as default return address
		PUSH	HL
		CALL	PRINTI		;Monitor Start, Display Welcome Message
;		DB	CR,LF,"Main Menu >",EOS
		DB	CR,LF,"Monitor >",EOS

MM_PURGE:
;		CALL	In_CharBC
; 		JR	NC, MM_PURGE

		LD	A,0xFF
		LD	(ECHO_ON),A	;TURN ON ECHO

		CALL 	GET_CHAR	;get char
		CP	':'
		JP 	Z, GETHEXFILE	; : = START HEX FILE LOAD
		CP	3
		JP 	Z, MM_PURGE
; bc		JP 	Z, MM_PURGE	;ignore CTRL-C
		AND 	0x5F		;to upper case
;		CP 	'C'		;Branch to Command entered
;		JP 	Z, MEM_DUMP	; C = Memory Dump (Continuous)
		CP 	'D'		;Branch to Command entered
		JP 	Z, MEM_DUMP_PAGED	; D = Memory Dump
		CP 	'E'
		JP 	Z, MEM_EDIT	; E = Edit Memory
		CP 	'G'
		JP 	Z, MEM_EXEC	; G = Go (Execute at)
		CP 	'W'
		JP 	Z, SET_BUFFER	; W = Set buffer start address for Intel HEX upload
#if 0
		CP 	'S'
		JP Z, 	GO_SINGLE	; S = Single Step
#endif
		CP 	'O'
		JP Z, 	PORT_OUT	; O = Output to port
		CP 	'I'
		JP Z, 	PORT_INP	; I = Input from Port
		CP 	'X'
		JP Z, 	XMODEM		; X = XMODEM
#if 0
		CP 	'R'
		JP Z,	REG_MENU	; R = REGISTER OPERATIONS
#endif

		CP 	'V'
		JP Z,	VERSION		; V = Version

		CALL 	PRINTI		;Display Help when input is invalid
		DB	CR,LF,"HELP"
		DB	CR,LF,"D XXXX         Dump memory from XXXX"
;		DB	CR,LF,"D XXXX YYYY    Dump memory from XXXX to YYYY"
;		DB	CR,LF,"C XXXX YYYY    Continous Dump (no pause)"
		DB	CR,LF,"E XXXX         Edit memory starting at XXXX"
;		DB	CR,LF,"M XXXX YY..YY  Enter many bytes into memory at XXXX"
		DB	CR,LF,"G XXXX         Go execute from XXXX"
;		DB	CR,LF,"S              Single Step"
		DB	CR,LF,"I XX           Input from I/O"
		DB	CR,LF,"O XX YY        Output to I/O"
;		DB	CR,LF,"R rr [=xx]     Register"
		DB	CR,LF,"V              Version"
		DB	CR,LF,"W XXXX         Set workspace XXXX"
		DB	CR,LF,":sHLtD...C     UPLOAD Intel HEX file, ':' is part of file"
		DB	CR,LF,"X U XXXX       XMODEM Upload to memory at XXXX"
		DB	CR,LF,"X D XXXX CCCC  XMODEM Download from XXXX for CCCC #of 128 byte blocks"
		DB	CR,LF,EOS

		JP 	MAIN_MENU




;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 4	Menu operations
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;=============================================================================
;Display Version
;-----------------------------------------------------------------------------
VERSION		CALL	PRINTI
		VERSION_MSG
		RET

;=============================================================================
;Register Display/Set
;-----------------------------------------------------------------------------
#if 0
REG_MENU	CALL	PUT_SPACE
		CALL	GET_CHAR
		CP	CR
		JP  NZ,	RM_NOTALL

;12345678901234567890123456789012345678901234567890123456789012345678901234567890  80 COLUMNS
;AF=xxxx  BC=xxxx  DE=xxxx  HL=xxxx  AF'=xxxx  BC'=xxxx  DE'=xxxx  HL'=xxxx
;IX=xxxx  IY=xxxx  IR=xxxx  PC=xxxx  SP=xxxx

REG_DISP_ALL	CALL	PUT_NEW_LINE	;Dump ALL registers
		LD	B,13		;13 Registers to dump
RM_LP		LD	HL,REGORDER
		LD	A,B
		DEC	A
		CALL	ADD_HL_A
		LD	C,(HL)
		CALL	PUT_REGNAME
		CALL	RM_DUMP_REG
		CALL	PRINTI
		DB	'  ',EOS
		LD	A,6
		CP	B
		JR  NZ,	RM_1
		CALL	PUT_NEW_LINE
RM_1		DJNZ	RM_LP
		RET

RM_NOTALL	CALL	IS_LETTER
		JR  C,	RM_ERR
		LD	E,A
		CALL	GET_CHAR
		CALL	IS_LETTER
		JR  C,	RM_ERR
		LD	D,A
		LD	L,0
RM_2		CALL	GET_CHAR
		CP	0x27		;Apostrophe Char
		JR  NZ,	RM_3
		LD	L,1		;L=1 if Alternate Register
		JR	RM_2
RM_3		RR	L		;Put Alternate flag into CARRY
		PUSH	AF		;Save last key input before proceeding to decode Register
		LD	B,13
RM_4		LD	C,B
		DEC	C
		CALL	GET_REGNAME	;HL=PTR TO NAME
		CALL	LD_HL_HL
		OR	A		;CLEAR CARRY
		SBC	HL,DE
		JP  Z,	RM_5		;Jump if NAME FOUND
		DJNZ	RM_4
		POP	AF
RM_ERR		LD	A,'?'		;Register Name not found
		CALL	PUT_CHARBC
		RET
RM_5		POP	AF
		LD	D,A
		JR  C,	RM_6		;Jump if Alternate (Selection would be correct)
		LD	A,C
		CP	9
		JR  C,	RM_6		;Jump if NOT Registers AF,BC,DE or HL
		SUB	8
		LD	C,A
RM_6		LD	A,D		;RESUME Decoding command line
		CP	CR
		JR  Z,	RM_DUMP_REG
		CP	'='
		JR  NZ,	RM_ERR

		CALL	GET_WORD	;DE = Word from Command
		LD	A,C
		CALL	PUT_REGISTER

RM_DUMP_REG	LD	A,'='
		CALL	PUT_CHARBC
		LD	A,C
		CALL	GET_REGISTER
		CALL	PUT_HL
		RET

REGORDER	DB	0
		DB	5
		DB	8
		DB	7
		DB	6
		DB	12
		DB	11
		DB	10
		DB	9
		DB	4
		DB	3
		DB	2
		DB	1
#endif

;=============================================================================
;Loop back test
;-----------------------------------------------------------------------------


;=============================================================================
;MEMORY ENTER.  M XXXX YY..YY,  ENTERS AS MANY BYTES AS THERE ARE ON THE LINE.
;-----------------------------------------------------------------------------
#if 0
MEM_ENTER	CALL	GET_WORD	;DE = Word from console, A=non-hex character following word (space)
		CP	' '	;Test delimiting character, must be a space
		JP NZ,	MAIN_MENU
		EX	DE,HL		;HL = Start
MEN_LP		CALL	GET_BYTE	;A = Byte or A=non-hex character (Carry Set)
		JR C,	MEN_RET		;Jump if non-hex input
		LD	(HL),A		;else, save the byte
		INC	HL		;advance memory pointer
		JR	MEN_LP		;repeat for next byte input

MEN_RET		CALL	GET_CHAR	;ignore rest of line before returning to main menu
		CP	0x0A		;wait until we get the <LF>
		JP NZ,	MEN_RET
		LD	A,4		;Wait up to 2 seconds for another M command or return to main menu
		CALL	TIMED_GETCHAR	;
		CP	'M'		;If another M command comes in, process it
		JR Z,	MEM_ENTER
		JP 	MAIN_MENU	;If not, return to main menu prompt
#endif

;=============================================================================
;MEMORY DUMP - Continous
;-----------------------------------------------------------------------------
; MEM_DUMP:	LD	B,0xFF		;Continuous Dump, No pausing
MEM_DUMP_0	CALL	SPACE_GET_WORD	;Input start address
		EX	DE,HL			;HL = Start
;		CALL	SPACE_GET_WORD	;Input end address (DE = end)
		LD	DE, 0FFFFH	; Auto to end of RAM

MEM_DUMP_LP:	CALL	PUT_NEW_LINE
		CALL	DUMP_LINE	;Dump 16 byte lines (advances HL)
		RET Z			;RETURN WHEN HL=DE
		LD	A,L
		OR	B
		JR  NZ,	MEM_DUMP_LP	;Dump 1 Page, then prompt for continue
		CALL	GET_CONTINUE
		JR	MEM_DUMP_LP
;=============================================================================
; MEMORY DUMP - Paged
; Changing behavior so that we don't need to type in end address
; We will dump until ESC is pressed
;-----------------------------------------------------------------------------
MEM_DUMP_PAGED	LD	B,0		;Paused Dump
		JR	MEM_DUMP_0

;-----------------------------------------------------------------------------
GET_CONTINUE	CALL	PUT_NEW_LINE
		CALL	PRINTI
		DB	"Press any key to continue",EOS
		CALL	GET_CHAR
		CP	27		; Escape to abort
		RET 	NZ
		POP	HL		;Scrap return address
		RET

;-----------------------------------------------------------------------------
;DUMP_LINE -- Dumps a line
;xxx0:  <pre spaces> XX XX XX XX XX After spaces | ....ASCII....
;-----------------------------------------------------------------------------
DUMP_LINE:	PUSH	BC		;+1
		PUSH	HL		;+2 Save H for 2nd part of display
		PUSH	HL		;+3 Start line with xxx0 address
		LD	A,'M'
		CALL	Put_CharBC
		CALL	PUT_HL		;Print Address
		CALL	PUT_SPACE
		POP	HL		;-3
		LD	A,L
		AND	0x0F		;Fetch how many prespaces to print
		LD	C,A
		LD	B,A		;Save count of prespaces for part 2 of display
		CALL	PUT_3C_SPACES

DL_P1L		LD	A,(HL)
		CALL	SPACE_PUT_BYTE
		CALL	CP_HL_DE
		JR Z,	DL_P1E
		INC	HL
		LD	A,L
		AND	0x0F
		JR  NZ,	DL_P1L
		JR	DL_P2

DL_P1E		LD	A,L
		CPL
		AND	0x0F
		LD	C,A
		CALL	PUT_3C_SPACES

DL_P2		CALL	PRINTI		;Print Seperator between part 1 and part 2
		DB	" ; ",EOS

DL_PSL2		LD	A,B		;Print prespaces for part 2
		OR	A
		JR Z,	DL_PSE2
		CALL	PUT_SPACE
		DEC	B
		JR	DL_PSL2
DL_PSE2
		POP	HL		;-2
		POP	BC		;-1
DL_P2L		LD	A,(HL)
		CP	' '		;A - 20h	Test for Valid ASCII characters
		JR NC,	DL_P2K1
		LD	A,'.'				;Replace with . if not ASCII
DL_P2K1		CP	0x7F		;A - 07Fh
		JR C,	DL_P2K2
		LD	A,'.'
DL_P2K2		CALL	Put_CharBC

		CALL	CP_HL_DE
		RET Z
		INC	HL
		LD	A,L
		AND	0x0F
		JR  NZ,	DL_P2L

;-----------------------------------------------------------------------------
;Compare HL with DE
;Exit:		Z=1 if HL=DE
;		M=1 if DE > HL
CP_HL_DE	LD	A,H
		CP	D		;H-D
		RET NZ			;M flag set if D > H
		LD	A,L
		CP	E		;L-E
		RET


PUT_3C_SPACES	INC	C		;Print 3C Spaces
PUT_3C_SPACES_L	DEC	C		;Count down Prespaces
		RET Z
		CALL	PRINTI		;Print pre spaces
		DB "   ",EOS
		JR	PUT_3C_SPACES_L


;-----------------------------------------------------------------------------
;EDIT MEMORY
;Edit memory from a starting address until X is pressed.
;Display mem loc, contents, and results of write.
;-----------------------------------------------------------------------------
MEM_EDIT:	CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL			;HL = Address to edit
ME_LP		CALL	PUT_NEW_LINE
		CALL	PUT_HL		;Print current contents of memory
		CALL	PUT_SPACE
		LD	A, ':'
		CALL	Put_CharBC
		LD	A, (HL)
		CALL	SPACE_PUT_BYTE
		CALL	SPACE_GET_BYTE	;Input new value or Exit if invalid
		RET C			;Exit to Command Loop
		LD	(HL), A		;or Save new value
		LD	A, (HL)
		CALL	SPACE_PUT_BYTE
		INC	HL		;Advance to next location
		JR	ME_LP		;repeat input


;=============================================================================
;	MEM_EXEC - Execute at
;	Get an address and jump to it
; 	Note: right now, we actually push the address on stack and return
;	We're ignoring all the single step stuff for now
;-----------------------------------------------------------------------------
MEM_EXEC:	CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JP	C, ME_0		; If c=1 then we have a word to jump to
;		JP	NC, ME_1	
		RET			; If c=0 then there is no word, abort
;		CP	27		; 
;		RET Z			; Exit if <ESC> pressed
ME_0
		LD	(RPC),DE	; Store word in RPC

		PUSH	AF
		CALL	PRINTI
		DB	' PC=',EOS
		LD	H,D
		LD	L,E
		CALL	PUT_HL
		POP	AF

ME_1		CP	27
		RET 	Z		; Abort and exit if <ESC> pressed
		DI			;
#if 0
GO_EXEC		CALL	WRITE_BLOCK	;17 + 137 + 21 * 7 = 301   	;Note, timing is critical in this routine for the Single Step function to work
		DW	ANBAR_DEF	;Where to write			;You may change the timing, but the single step waste count must be adjusted
		DW	7		;# Bytes to write		;so that an interrupt occurs after a single instruction is executed.
		DB	0x82		;(ANBAR_DEF) = RUN MODE
		DW	GET_REG_RUN	;(GET_REG)
		DW	PUT_REG_RUN	;(PUT_REG)
		DW	CTRL_C_TEST	;(CTRL_C_CHK)

		LD	A,(ANBAR_DEF)	;13 Refresh Display
		LD	(LED_ANBAR),A	;13

		EX	AF,AF'		;4  Fetch Alternate register set
		LD	SP,RSAF2	;10 Set Stack to get register AF'
		POP	AF		;10
		EX	AF,AF'		;4
		EXX			;4  Fetch Alternate register set
		LD	BC,(RSBC2)	;20
		LD	DE,(RSDE2)	;20
		LD	HL,(RSHL2)	;20
		EXX			;4

		LD	BC,(RSIR)	;20 Fetch IR
		LD	A,C		;4
		LD	R,A		;9
		LD	A,B		;4
		LD	I,A		;9

		LD	SP,RSAF		;10 Set Stack to Fetch register AF
		POP	AF		;10

		LD	SP,(RSSP)	;20 Fetch SP
		LD	HL,(RPC)	;16 Fetch PC
		PUSH	HL		;11 & Put on stack

		LD	BC,(RSBC)	;20
		LD	DE,(RSDE)	;20
		LD	HL,(RSHL)	;20
		LD	IX,(RSIX)	;20
		LD	IY,(RSIY)	;20
#else
		PUSH	DE
#endif
		EI			;4  Enable Interrupts (for the benefit of Single Step)
		RET			;10 PC=(STACK)   Total = 650

;===============================================
;Input from port, print contents
PORT_INP:	CALL	SPACE_GET_BYTE
		LD	C, A
		IN	A,(C)
		CALL	SPACE_PUT_BYTE
		RET

;Get a port address, write byte out
PORT_OUT:	CALL	SPACE_GET_BYTE
		LD	C, A
		CALL	SPACE_GET_BYTE
		OUT	(C),A
		RET



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 5	Supporting routines. GET_BYTE, GET_WORD, PUT_BYTE, PUT_WORD
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
#if 0
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
					;Critical Timing in effect for GO_EXEC
WRITE_BLOCK	EX	(SP),HL		;19 HL=PC Total = 137 + 21 * BC
		PUSH	DE		;11
		PUSH	BC		;11
		LD	E,(HL)		;7
		INC	HL		;6
		LD	D,(HL)		;7
		INC	HL		;6
		LD	C,(HL)		;7
		INC	HL		;6
		LD	B,(HL)		;7
		INC	HL		;6
		LDIR			;21/16  21*BC-5
		POP	BC		;10
		POP	DE		;10
		EX	(SP),HL		;19 PC=HL
		RET			;10

CLEAR_BLOCK	LD	(HL),0
		INC	HL
		DJNZ	CLEAR_BLOCK
		RET

PUT_REGNAME	CALL	GET_REGNAME
		CALL	PRINT
		LD	A,C		;Test for alternate register
		CP	9
		RET C			;Exit C set if NOT an alternate register (LED OUTPUT, PRINT SPACE)
		LD	A,0x27		;Apostrophe Char
		CALL	PUT_CHARBC
		SCF
		RET

GET_REGNAME	LD	A,C
		ADD	A,C
		ADD	A,C
		LD	HL,REGNAMES
		CALL	ADD_HL_A
		RET

REGNAMES	DB	'SP',0		;0
		DB	'AF',0		;1
		DB	'BC',0		;2
		DB	'DE',0		;3
		DB	'HL',0		;4
		DB	'PC',0		;5
		DB	'IX',0		;6
		DB	'IY',0		;7
		DB	'IR',0		;8
		DB	'AF',0		;9
		DB	'BC',0		;10
		DB	'DE',0		;11
		DB	'HL',0		;12

GET_REGISTER	LD	HL,(GET_REG)	;16
		JP	(HL)		;4

GET_REG_MON	LD	HL,RSSP		;
		RLCA
		CALL	ADD_HL_A	;17+18 HL=Where to find Register
		CALL	LD_HL_HL	;HL=(HL)
		RET

GET_REG_RUN	LD	HL,GRR_TBL	;10
		JP	SHORTNWAY	;10

PUT_REGISTER	LD	HL,(PUT_REG)
		JP	(HL)

PUT_REG_MON	LD	HL,RSSP
		RLCA
		CALL	ADD_HL_A	;HL=Where to find Register
PURRS_RET	LD	(HL),E
		INC	HL
		LD	(HL),D
		RET

PUT_REG_RUN	LD	HL,PURR_TBL
					;40 to get here
SHORTNWAY	AND	0xF		;7
		CALL	ADD_HL_A	;14+18
		LD	A,(HL)		;7
		LD	HL,GRR_SUB	;10
		CALL	ADD_HL_A	;17+18
		JP	(HL)		;4  st=138

GRR_TBL		DB	0
		DB	GRR_SUB_AF - GRR_SUB
		DB	GRR_SUB_BC - GRR_SUB
		DB	GRR_SUB_DE - GRR_SUB
		DB	GRR_SUB_HL - GRR_SUB
		DB	GRR_SUB_PC - GRR_SUB
		DB	GRR_SUB_IX - GRR_SUB
		DB	GRR_SUB_IY - GRR_SUB
		DB	GRR_SUB_IR - GRR_SUB
		DB	GRR_SUB_AFA - GRR_SUB
		DB	GRR_SUB_BCA - GRR_SUB
		DB	GRR_SUB_DEA - GRR_SUB
		DB	GRR_SUB_HLA - GRR_SUB
		DB	0
		DB	0
		DB	0

PURR_TBL	DB	PURR_SUB_SP - GRR_SUB
		DB	PURR_SUB_AF - GRR_SUB
		DB	PURR_SUB_BC - GRR_SUB
		DB	PURR_SUB_DE - GRR_SUB
		DB	PURR_SUB_HL - GRR_SUB
		DB	PURR_SUB_PC - GRR_SUB
		DB	PURR_SUB_IX - GRR_SUB
		DB	PURR_SUB_IY - GRR_SUB
		DB	PURR_SUB_IR - GRR_SUB
		DB	PURR_SUB_AFA - GRR_SUB
		DB	PURR_SUB_BCA - GRR_SUB
		DB	PURR_SUB_DEA - GRR_SUB
		DB	PURR_SUB_HLA - GRR_SUB
		DB	0
		DB	0
		DB	0

		;Stack holds:
		;SP	RETURN TO ISR
		;SP+2	AF
		;SP+4	HL
		;SP+6	RETURN TO MAIN CODE (PC)

GRR_SUB		LD	HL,8		;Get SP;True value of SP (prior to ISR)
		ADD	HL,SP
		RET
GRR_SUB_AF	LD	HL,2		;Get AF
		ADD	HL,SP
		CALL	LD_HL_HL	;HL=(HL)
		RET
GRR_SUB_BC	PUSH	BC
		POP	HL
		RET
GRR_SUB_DE	PUSH	DE
		POP	HL
		RET
GRR_SUB_HL	LD	HL,4		;Get HL
		ADD	HL,SP
		CALL	LD_HL_HL	;HL=(HL)
		RET
GRR_SUB_PC	LD	HL,6		;Get PC
		ADD	HL,SP
		CALL	LD_HL_HL	;HL=(HL)
		RET
GRR_SUB_IX	PUSH	IX
		POP	HL
		RET
GRR_SUB_IY	PUSH	IY
		POP	HL
		RET
GRR_SUB_IR	LD	A,I
		LD	H,A
		LD	A,R
		LD	L,A
		RET
GRR_SUB_AFA	EX	AF,AF'
		PUSH	AF
		EX	AF,AF'
		POP	HL
		RET
GRR_SUB_BCA	EXX
		PUSH	BC
		EXX
		POP	HL
		RET
GRR_SUB_DEA	EXX
		PUSH	DE
		EXX
		POP	HL
		RET
GRR_SUB_HLA	EXX
		PUSH	HL
		EXX
		POP	HL
		RET

		;Stack holds:
		;SP	RETURN TO ISR
		;SP+2	DE
		;SP+4	AF
		;SP+6	HL
		;SP+8	RETURN TO MAIN CODE (PC)

PURR_SUB_SP	RET		;Do we really want to change the SP during RUN mode??? Suicide!
PURR_SUB_AF	LD	HL,4		;Get DE
		ADD	HL,SP
		JP	PURRS_RET
PURR_SUB_BC	PUSH	DE
		POP	BC
		RET
PURR_SUB_DE	LD	HL,2		;10 Get DE
		ADD	HL,SP		;11
		JP	PURRS_RET	;10  st=31
PURR_SUB_HL	LD	HL,6		;Get HL
		ADD	HL,SP
		JP	PURRS_RET
PURR_SUB_PC	LD	HL,8		;Get PC
		ADD	HL,SP
		JP	PURRS_RET
PURR_SUB_IX	PUSH	DE
		POP	IX
		RET
PURR_SUB_IY	PUSH	DE
		POP	IY
		RET
PURR_SUB_IR	LD	A,D
		LD	I,A
		LD	A,E
		LD	R,A
		RET
PURR_SUB_AFA	PUSH	DE
		EX	AF,AF'
		POP	AF
		EX	AF,AF'
		RET
PURR_SUB_BCA	PUSH	DE
		EXX
		POP	BC
		EXX
		RET
PURR_SUB_DEA	PUSH	DE
		EXX
		POP	DE
		EXX
		RET
PURR_SUB_HLA	PUSH	DE
		EXX
		POP	HL
		EXX
		RET
#endif

;=============================================================================
SPACE_GET_BYTE	CALL	PUT_SPACE

;=============================================================================
;GET_BYTE -- Get byte from console as hex
;
;in:	Nothing
;out:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)
;-----------------------------------------------------------------------------
GET_BYTE:	CALL	GET_HEX_CHAR	;Get 1st HEX CHAR
		JR  NC,	GB_1
		CP	' '		;Exit if not HEX CHAR (ignoring SPACE)
		JR Z,	GET_BYTE	;Loop back if first char is a SPACE
		SCF			;Set Carry
		RET			;or EXIT with delimiting char
GB_1		PUSH	DE		;Process 1st HEX CHAR
		RLCA
		RLCA
		RLCA
		RLCA
		AND	0xF0
		LD	D,A
		CALL	GET_HEX_CHAR
		JR  NC,	GB_2		;If 2nd char is HEX CHAR
		CP	' '
		JR Z,	GB_RET1
		SCF			;Set Carry
		POP	DE
		RET			;or EXIT with delimiting char
GB_2		OR	D
		POP	DE
		RET
GB_RET1		LD	A,D
		RRCA
		RRCA
		RRCA
		RRCA
GB_RET		OR	A
		POP	DE
		RET


;=============================================================================
; Print a space, then input a word
;
; in:	Nothing
; out:	c=1	A = non-hex char input
;		DE = Word
; out:	c=0	A = non-hex char input (No Word in DE)

SPACE_GET_WORD	CALL	PUT_SPACE

;=============================================================================
;GET_WORD -- Get word from console as hex
;
;in:	Nothing
;out:	c=1	A = non-hex char input
;		DE = Word
;out:	c=0	A = non-hex char input (No Word in DE)
;-----------------------------------------------------------------------------
GET_WORD:	LD	DE,0
		CALL	GET_HEX_CHAR	;Get 1st HEX CHAR
		JR  	NC, GW_LP
					; Not HEX
		CP	' '		; Is it SPACE
		JR 	Z, GET_WORD	; Loop back if first char is a SPACE
		OR	A		; Otherwise, clear Carry and exit
		RET			; 
GW_LP		LD	E,A		; HEX
		CALL	GET_HEX_CHAR	; Get next char
		RET 	C		; EXIT when a delimiting char is entered
		EX	DE,HL		; Else, shift new HEX Char Value into DE
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		EX	DE,HL
		OR	E
		JR	GW_LP



;===============================================
;Get HEX CHAR
;in:	Nothing
;out:	A = Value of HEX Char when CY=0
;	A = Received (non-hex) char when CY=1
;-----------------------------------------------
GET_HEX_CHAR:	CALL	GET_CHAR
		CP	'0'
		JP M,	GHC_NOT_RET
		CP	'9'+1
		JP M,	GHC_NRET
		CP	'A'
		JP M,	GHC_NOT_RET
		CP	'F'+1
		JP M,	GHC_ARET
		CP	'a'
		JP M,	GHC_NOT_RET
		CP	'f'+1
		JP M,	GHC_ARET
GHC_NOT_RET	SCF
		RET
GHC_ARET	SUB	0x07
GHC_NRET	AND	0x0F	; Clear CY
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Put_CharBC
; Output character to RS232
; Character is in A
; Preserve AF
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Put_CharBC:
PUT_CHARBC:	
		PUSH	AF
		RST	08H
		POP	AF
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;PRINT -- Print A null-terminated string @(HL)
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PRINT:		LD	A, (HL)
		INC	HL
		OR	A
		RET	Z
		CALL	Put_CharBC
		JR	PRINT

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;PRINT IMMEDIATE
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PRINTI:		EX	(SP),HL	;HL = Top of Stack
		CALL	PRINT
		EX	(SP),HL	;Move updated return address back to stack
		RET


;===============================================
;ASCHEX -- Convert ASCII coded hex to nibble
;
;pre:	A register contains ASCII coded nibble
;post:	A register contains nibble
;-----------------------------------------------
ASCHEX:		SUB	0x30
		CP	0x0A
		RET M
		AND	0x5F
		SUB	0x07
		RET


;===============================================
;PUT_HL Prints HL Word
;-----------------------------------------------
PUT_HL:		LD	A, H
		CALL	PUT_BYTE
		LD	A, L
		CALL	PUT_BYTE
		RET


;===============================================
;SPACE_PUT_BYTE -- Output (SPACE) & byte to console as hex
;
;pre:	A register contains byte to be output
;post:	Destroys A
;-----------------------------------------------
SPACE_PUT_BYTE	PUSH	AF
		CALL	PUT_SPACE
		POP	AF

;===============================================
;PUT_BYTE -- Output byte to console as hex
;
;pre:	A register contains byte to be output
;post:	Destroys A
;-----------------------------------------------
PUT_BYTE:	PUSH	AF
		RRCA
		RRCA
		RRCA
		RRCA
		AND	0x0F
		CALL	PUT_HEX
		POP	AF
		AND	0x0F
;		CALL	PUT_HEX
;		RET

;===============================================
;PUT_HEX -- Convert nibble to ASCII char
;-----------------------------------------------
PUT_HEX:	CALL	TO_HEX
		JP	Put_CharBC

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;TO_HEX - Convert nibble to ASCII char
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TO_HEX:		AND	0xF
		ADD	A,0x30
		CP	0x3A
		RET C
		ADD	A,0x7
		RET


;===============================================
;PUT_SPACE -- Print a space to the console
;
;pre: none
;post: 0x20 printed to console
;-----------------------------------------------
PUT_SPACE:	LD	A, ' '
		JP	Put_CharBC

;===============================================
;PUT_NEW_LINE -- Start a new line on the console
;
;pre: none
;post: 0x0A printed to console
;-----------------------------------------------
PUT_NEW_LINE:	LD	A, 0x0D
		CALL	Put_CharBC
		LD	A, 0x0A
		JP	Put_CharBC

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Terminal Increment byte at (HL).  Do not pass 0xFF
TINC:		INC	(HL)
		RET	NZ
		DEC	(HL)
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DELAY_10mS	LD	C, 24	; bc 12
DELAY_C		PUSH	BC
		LD	B,0
DELAY_LP	DJNZ	DELAY_LP	;13 * 256 / 4 = 832uSec
		DEC	C
		JR	NZ, DELAY_LP	;*4 ~= 7mSec
		POP	BC
		RET


;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ADD_HL_A	ADD	A,L		;4
		LD	L,A		;4
		RET NC			;10
		INC	H
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LD_HL_HL	LD      A,(HL)		;7
		INC     HL		;6
		LD      H,(HL)		;7
		LD      L,A		;4
		RET			;10

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
IS_LETTER	CP	'A'
		RET C
		CP	'Z'+1
		CCF
		RET



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 6	Menu operations. ASCII HEXFILE TRANSFER
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

; Set the address to the buffer where we want to upload the Intel HEX file
; This is to be used if the Intel HEX file uses 0000h as the start address
; You will want to set this address to somewhere in RAM...
SET_BUFFER
		CALL	SPACE_GET_WORD	;Input address, c=1 if we have a word, c=0 if no word
		JR	NC, SE_0	; If c=0 then there is no word, abort
					; If c=1 then we have a word to load
		LD	(hex_buffer),DE	; Store word
SE_0
		RET

;----------------------------------------------------------------------------------------------------
; ASCII HEXFILE TRANSFER
;Registers:	B= Byte counter per line (initialized at start of line)
;		C= Check sum (initialized at start of line)
;		D= Temp for assembling HEX bytes
;		E= Error counter over the entire transfer
;		HL= Address to save data
; We are jumping in here with the first character ":" already loaded
GETHEXFILE	LD	E,0		;ZERO ERROR COUNTER
		JR	GHDOLINE	; Jump straight to reading in the byte cound

GHWAIT			; LD	A,20			;10 Second Timeout for Get char
		CALL	TIMED_GETCHAR_BC
		JR  	C, GHENDTO	; Timeout
		CP	27		; ESC
		JR  	Z, GHENDTO	; Abort if ESC
		CP	':'
		JR  	NZ, GHWAIT

		; Handle a line
GHDOLINE	CALL	TGET_BYTE	;GET BYTE COUNT
		LD	B,A		;BYTE COUNTER
		LD	C,A		;CHECKSUM

		CALL	TGET_BYTE	;GET HIGH ADDRESS
		LD	H,A

		CALL	TGET_BYTE	;GET LOW ADDRESS
		LD	L,A
		; Add buffer start
		PUSH	DE
		LD	DE, (hex_buffer)
		ADD	HL, DE
		POP	DE
		CALL	TGET_BYTE	;GET RECORD TYPE
		CP	1
		JP 	Z,	GHEND	;IF RECORD TYPE IS 01 THEN END
		
		; Assuming everything else is data record...
GHLOOP		CALL	TGET_BYTE	;GET DATA
		LD	(HL),A
		INC	HL
		DJNZ	GHLOOP		;Repeat for all data in line

		CALL	TGET_BYTE	;GET CHECKSUM
		XOR	A
		CP	C		;Test Checksum = 0
		JR 	Z, GHWAIT0	; No error
		INC	E
		JR  	NZ, GHWAIT0
		DEC	E
GHWAIT0
		LD	A, '.'		; Output tick
		CALL	PUT_CHARBC
		JR	GHWAIT
		
;GHENDTO		CALL	PRINTI
;		DB	CR,LF,"HEX TRANSFER TIMEOUT",EOS
;		JR	GHEND1
	
GHEND		; We come here on detecting RECORD TYPE = 1 but there are 2 more characters
		CALL	TGET_BYTE	; Get the last checksum byte
GHENDTO
GHEND1
		CALL	PRINTI
		DB	CR,LF,"HEX TRANSFER COMPLETE ERRORS=",EOS
		LD	A,E
		CALL	PUT_BYTE
		JP	MAIN_MENU
		
;-----------------------------------------------------------------------------
;TGET_BYTE -- Get byte from console as hex with timeout
;
;in:	Nothing
;out:	A = Byte (if CY=0)  (last 2 hex characters)  Exit if Space Entered
;	A = non-hex char input (if CY=1)
;-----------------------------------------------------------------------------
TGET_BYTE:	CALL	TGET_HEX_CHAR	;Get 1st HEX CHAR
		JR  C,  GHENDTO		;Exit previous routine with a time out (leaves address on stack but MAIN_MENU will reset stack)
		RLCA			;Shift 1st HEX CHAR
		RLCA
		RLCA
		RLCA
		AND	0xF0
		LD	D,A
		CALL	TGET_HEX_CHAR	;Get 2nd HEX CHAR
		JR  C,  GHENDTO
		OR	D
		LD	D,A		;Save byte
		ADD	A,C		;Add byte to Checksum
		LD	C,A
		LD	A,D		;Restore byte
		RET

;===============================================
;Get HEX CHAR
;in:	Nothing
;out:	CY=0, A = Value of HEX Char
;	CY=1, A = Received (non-hex) char or Time out
;-----------------------------------------------
TGET_HEX_CHAR:		; LD	A,20			;10 Second Timeout for Get char
		CALL	TIMED_GETCHAR_BC	; C=1, No Char (Time Out)
						; C=0, A = Char
		RET	C			; Timeout. Should probably test for ESC here
		CP	'0'
		JP M,	TGHC_NOT_RET
		CP	'9'+1
		JP M,	TGHC_NRET
		CP	'A'
		JP M,	TGHC_NOT_RET
		CP	'F'+1
		JP M,	TGHC_ARET
		CP	'a'
		JP M,	TGHC_NOT_RET
		CP	'f'+1
		JP M,	TGHC_ARET
TGHC_NOT_RET	SCF
		RET
TGHC_ARET	SUB	0x07
TGHC_NRET	AND	0x0F
		RET


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 7	Menu operations. XMODEM FILE TRANSFER
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; XMODEM ROUTINES

SOH	equ	1	;Start of Header
EOT	equ	4	;End of Transmission
ACK	equ	6
DLE	equ	16
DC1	equ	17	; (X-ON)
DC3	equ	19	; (X-OFF)
NAK	equ	21
SYN	equ	22
CAN	equ	24	;(Cancel)

;---------------------------------------------------------------------------------
;XMODEM MENU
;ENTRY:	TOP OF LDCK HOLDS RETURN ADDRESS (EXIT MECHANDSM IF XMODEM IS CANCELLED)
;---------------------------------------------------------------------------------
XMODEM		CALL	PUT_SPACE
		CALL	GET_CHAR	;get char
		AND	0x5F		;to upper case
		CP	'D'
		JR Z,	XMDN		; D = DOWNLOAD
		CP	'U'
		JR Z,	XMUP		; U = UPLOAD
		CALL 	PRINTI
		DB	"?",EOS
		RET

;---------------------------------------------------------------------------------
;XMDN - XMODEM DOWNLOAD (send file from IMSAI to Terminal)
;INPUT STARTING ADDRESS AND COUNT OF BLOCKS (WORD)
;WAIT FOR 'C' OR NAK FROM HOST TO START CRC/CS TRANSFER
;---------------------------------------------------------------------------------
XMDN		CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL		;HL = Address to SAVE DATA
		CALL	SPACE_GET_WORD	;Input #Blocks to Send
					;DE = Count of Blocks

		LD	A,D
		OR	E
		RET Z			;Exit if Block Count = 0

	;HL = Address of data to send from the IMSAI 8080
	;DE = Count of Blocks to send.

		CALL	XMS_INIT	;Starts the Seq, Sets the CS/CRC format
					;Cancelled Transfers will cause a RET

XMDN_LP		CALL	XMS_SEND	;Sends the packet @HL, Resends if NAK
					;Cancelled Transfers will cause a RET
		DEC	DE
		LD	A,D
		OR	E
		JR  NZ,	XMDN_LP

		CALL	XMS_EOT		;Send End of Transmission
		JP	PURGE


;---------------------------------------------------------------------------------
;XMUP - XMODEM UPLOAD (receive file from Terminal to IMSAI 8080)
;INPUT STARTING ADDRESS
;SEND 'C' OR NAK TO HOST TO START CRC/CS TRANSFER
;---------------------------------------------------------------------------------
XMUP		CALL	SPACE_GET_WORD	;Input Address
		EX	DE,HL		;HL = Address to SAVE DATA

	;HL = Address of data to send from the IMSAI 8080

		CALL	XMR_INIT	;Starts the transfer & Receives first PACKET
					;Cancelled Transfers will cause a RET

XMUP_LP		CALL	XMR_RECV	;Receives the next packet @HL, Resends if NAK
					;Cancelled Transfers will cause a RET
		JR C,	XMUP_LP		;Jump until EOT Received
		JP	PURGE



;---------------------------------------------------------------------------------
;INIT FOR SENDING XMODEM PROTOCOL, GET NAK OR 'C', SAVE THE XMTYPE
;---------------------------------------------------------------------------------
XMS_INIT	LD	A,1		;First SEQ number
		LD	(XMSEQ),A

		LD	B,6		;6 retries for initiating the transfer
XMS_INIT_LP	LD	A,28		;GET CHAR, 15 SECONDS TIMEOUT (EXPECT C OR NAK)
		CALL	TIMED_GETCHAR
		JP C,	XMS_INIT_RT	;Cancel if Host Timed out

		CP	NAK		;If NAK, Start Checksum Download
		JR Z,	XMS_DO
		CP	'C'		;If C, Start CRC Download
		JR Z,	XMS_DO
XMS_INIT_RT	DJNZ	XMS_INIT_LP	;Count down Retries
		JP	XM_CANCEL	;Cancel XModem if all retries exhausted

XMS_DO		LD	(XMTYPE),A
		RET

;---------------------------------------------------------------------------------
;SEND A PACKET (RESEND UPON NAK)
;---------------------------------------------------------------------------------
XMS_RESEND	LD	BC,0xFF80
		ADD	HL,BC
XMS_SEND	PUSH	DE
		LD	A,SOH		;SEND THE HEADER FOR CRC OR CHECKSUM
		CALL	Put_CharBC
		LD	A,(XMSEQ)
		CALL	Put_CharBC
		CPL
		CALL	Put_CharBC
		LD	DE,0x0000	;Init DE=0000 (CRC Accumulator)
		LD	C,0		;Init C=00 (CS Accumulator)
		LD	B,128		;Count 128 bytes per block
XMS_BLP		LD	A,(HL)		;Fetch bytes to send  -------------------\
		CALL	Put_CharBC	;Send them
		CALL	CRC_UPDATE	;Update the CRC
		LD	A,(HL)
		ADD	A,C		;Update the CS
		LD	C,A
		INC	HL		;Advance to next byte in block
		DEC	B		;Count down bytes sent
		JR NZ,	XMS_BLP		;Loop back until 128 bytes are sent -----^
		LD	A,(XMTYPE)
		CP	NAK		;If NAK, send Checksum
		JR Z,	XMS_CS		;----------------------v
		LD	A,D		;else, Send the CRC next
		CALL	Put_CharBC
		LD	C,E
XMS_CS		LD	A,C		;----------------------/
		CALL	Put_CharBC
					;Packet Sent, get Ack/Nak Response
		LD	A,120		;GET CHAR, 60 SECONDS TIMEOUT (EXPECT C OR NAK)
		CALL	TIMED_GETCHAR
		POP	DE
		JR C,	XM_CANCEL	;Cancel download if no response within 45 seconds
		CP	NAK
		JR Z,	XMS_RESEND	;Loop back to resend packet
		CP	CAN
		JR Z,	XM_CANCEL
		CP	ACK
		JR NZ,	XM_CANCEL

		LD	A,(XMSEQ)
		INC	A		;NEXT SEQ
		LD	(XMSEQ),A
		RET


;---------------------------------------------------------------------------------
;XMDN - DOWNLOAD XMODEM PACKET
;---------------------------------------------------------------------------------
XMS_EOT		LD	A,EOT		;HANDLE THE END OF TRANSFER FOR CRC OR CHECKSUM
		CALL	Put_CharBC
		LD	A,120		;GET CHAR, 60 SECONDS TIMEOUT (EXPECT C OR NAK)
		CALL	TIMED_GETCHAR
		JR C,	XM_CANCEL
		CP	NAK
		JR Z,	XMS_EOT
		CP	ACK
		JR NZ,	XM_CANCEL

XM_DONE		CALL	PURGE
		CALL	PRINTI
		DB	CR,LF,"TRANSFER COMPLETE\r\n",EOS
		XOR	A		;CLEAR A, CY
		RET

;FINISHING CODE PRIOR TO LEAVING XMODEM
XM_CANCEL	LD	A,CAN
		CALL	Put_CharBC
		CALL	Put_CharBC
		CALL	PURGE
		CALL	PRINTI
		DB	"TRANSFER CANCELED\r\n",EOS
		POP	BC		;SCRAP CALLING ROUTINE AND HEAD TO PARENT
		RET






;---------------------------------------------------------------------------------
;START XMODEM RECEIVING and RECEIVE FIRST PACKET
;---------------------------------------------------------------------------------
XMR_INIT	LD	E,7		;7 ATTEMPTS TO INITIATE XMODEM CRC TRANSFER
		LD	A,1		;EXPECTED SEQ NUMBER starts at 1
		LD	(XMSEQ),A
XMR_CRC		CALL	PURGE
		LD	A,'C'		;Send C
		LD	(XMTYPE),A	;Save as XM Type (CRC or CS)
		CALL	Put_CharBC
		CALL	XMGET_HDR	;Await a packet
		JR NC,	XMR_TSEQ	;Jump if first packet received
		JR NZ,	XM_CANCEL	;Cancel if there was a response that was not a header
		DEC	E		;Otherwise, if no response, retry a few times
		JR NZ,	XMR_CRC

		LD	E,9		;9 ATTEMPTS TO INITIATE XMODEM CHECKSUM TRANSFER
XMR_CS		CALL	PURGE
		LD	A,NAK		;Send NAK
		LD	(XMTYPE),A	;Save as XM Type (CRC or CS)
		CALL	Put_CharBC
		CALL	XMGET_HDR	;Await a packet
		JR NC,	XMR_TSEQ	;Jump if first packet received
		JR NZ,	XM_CANCEL	;Cancel if there was a response that was not a header
		DEC	E		;Otherwise, if no response, retry a few times
		JR NZ,	XMR_CS
		JR	XM_CANCEL	;Abort


;--------------------- XMODEM RECEIVE
;Entry:	XMR_TSEQ in the middle of the routine
;Pre:	C=1 (expected first block as received when negogiating CRC or Checksum)
;	HL=Memory to dump the file to
;Uses:	B to count the 128 bytes per block
;	C to track Block Number expected
;	DE as CRC (Within Loop) (D is destroyed when Getting Header)
;------------------------------------
XMR_RECV	LD	A,ACK		;Send Ack to start Receiving next packet
		CALL	Put_CharBC
XMR_LP		CALL	XMGET_HDR
		JR NC,	XMR_TSEQ
		PUSH	HL
		JR Z,	XMR_NAK		;NACK IF TIMED OUT
		POP	HL
		CP	EOT
		JR NZ,	XM_CANCEL	;CANCEL IF CAN RECEIVED (OR JUST NOT EOT)
		LD	A,ACK
		CALL	Put_CharBC
		JP	XM_DONE

XMR_TSEQ	LD	C,A
		LD	A,(XMSEQ)
		CP	C		;CHECK IF THIS SEQ IS EXPECTED
		JR Z,	XMR_SEQ_OK	;Jump if CORRECT SEQ
		DEC	A		;Else test if Previous SEQ
		LD	(XMSEQ),A
		CP	C
		JP NZ,	XM_CANCEL	;CANCEL IF SEQUENCE ISN'T PREVIOUS BLOCK
		CALL	PURGE		;ELSE, PURGE AND SEND ACK (ASSUMING PREVIOUS ACK WAS NOT RECEIVED)
		JR	XMR_ACK

XMR_SEQ_OK	LD	B,128		;128 BYTES PER BLOCK
		LD	C,0		;Clear Checksum
		LD	DE,0x0000	;CLEAR CRC
		PUSH	HL		;Save HL where block is to go
XMR_BLK_LP	CALL	TIMED1_GETCHAR
		JR C,	XMR_NAK
		LD	(HL),A		;SAVE DATA BYTE
		CALL	CRC_UPDATE
		LD	A,(HL)		;Update checksum
		ADD	A,C
		LD	C,A
		INC	HL		;ADVANCE
		DEC	B
		JR NZ,	XMR_BLK_LP
					;After 128 byte packet, verify error checking byte(s)
		LD	A,(XMTYPE)	;Determine if we are using CRC or Checksum
		CP	NAK		;If NAK, then use Checksum
		JR Z,	XMR_CCS
		CALL	TIMED1_GETCHAR
		JR C,	XMR_NAK
		CP	D
		JR NZ,	XMR_NAK
		CALL	TIMED1_GETCHAR
		JR C,	XMR_NAK
		CP	E
		JR NZ,	XMR_NAK
		JR	XMR_ACK

XMR_CCS		CALL	TIMED1_GETCHAR
		JP C,	XMR_NAK
		CP	C
		JR NZ,	XMR_NAK

		;If we were transfering to a FILE, this is where we would write the
		;sector and reset HL to the same 128 byte sector buffer.
		;CALL	WRITE_SECTOR

XMR_ACK		;LD	A,ACK		;The sending of the Ack is done by
		;CALL	Put_CharBC	;the calling routine, to allow writes to disk
		LD	A,(XMSEQ)
		INC	A		;Advance to next SEQ BLOCK
		LD	(XMSEQ),A
		POP	BC
		SCF			;Carry set when NOT last packet
		RET

XMR_NAK		POP	HL		;Return HL to start of block
		CALL	PURGE
		LD	A,NAK
		CALL	Put_CharBC
		JR	XMR_LP


;--------------------- XMODEM - GET HEADER
;
;pre:	Nothing
;post:	Carry Set: A=0, (Zero set) if Timeout
;	Carry Set: A=CAN (Not Zero) if Cancel received
;	Carry Set: A=EOT (Not Zero) if End of Tranmission received
;	Carry Clear and A = B = Seq if Header found and is good
;------------------------------------------
XMGET_HDR	LD	A,6		;GET CHAR, 3 SECONDS TIMEOUT (EXPECT SOH)
		CALL	TIMED_GETCHAR
		RET C			;Return if Timed out
		CP	SOH		;TEST IF START OF HEADER
		JR Z,	GS_SEQ		;IF SOH RECEIVED, GET SEQ NEXT
		CP	EOT		;TEST IF END OF TRANSMISSION
		JR Z,	GS_ESC		;IF EOT RECEIVED, TERMINATE XMODEM
		CP	CAN		;TEST IF CANCEL
		JR NZ,	XMGET_HDR
GS_ESC		OR	A		;Clear Z flag (because A<>0)
		SCF
		RET
GS_SEQ		CALL	TIMED1_GETCHAR	;GET SEQ CHAR
		RET C			;Return if Timed out
		LD	B,A		;SAVE SEQ
		CALL	TIMED1_GETCHAR	;GET SEQ COMPLEMENT
		RET C			;Return if Timed out
		CPL
		CP	B		;TEST IF SEQ VALID
		JR NZ,	XMGET_HDR	;LOOP BACK AND TRY AGAIN IF HEADER INCORRECT (SYNC FRAME)
		RET

;------------------------------------------ CRC_UPDATE
;HANDLE THE CRC CALCULATION FOR UP/DOWNLOADING
;Total Time=775 cycles = 388uSec
;In:	A  = New char to roll into CRC accumulator
;	DE = 16bit CRC accumulator
;Out:	DE = 16bit CRC accumulator
;------------------------------------------
;CRC_UPDATE	XOR	D		;4
;		LD	D,A		;5
;		PUSH	BC		;11
;		LD	B,8		;7	PRELOOP=27
;CRCU_LP	OR	A		;4	CLEAR CARRY
;		LD	A,E		;5
;		RLA			;4
;		LD	E,A		;5
;		LD	A,D		;5
;		RLA			;4
;		LD	D,A		;5
;		JP NC,	CRCU_NX		;10
;		LD	A,D		;5
;		XOR	0x10		;7
;		LD	D,A		;5
;		LD	A,E		;5
;		XOR	0x21		;7
;		LD	E,A		;5
;CRCU_NX	DEC	B		;5
;		JP NZ,	CRCU_LP		;10	LOOP=91*8 (WORSE CASE)
;		POP	BC		;10	POSTLOOP=20
;		RET			;10


;------------------------------------------ CRC_UPDATE
;HANDLE THE CRC CALCULATION FOR UP/DOWNLOADING
;Total Time=604 cycles = 302uSec MAX
;In:	A  = New char to roll into CRC accumulator
;	DE = 16bit CRC accumulator
;Out:	DE = 16bit CRC accumulator
;------------------------------------------
CRC_UPDATE	EX	DE,HL			;4
		XOR	H		;4
		LD	H,A		;5
		ADD	HL,HL		;10	Shift HL Left 1
		CALL C,	CRC_UPC		;17 (10/61)
		ADD	HL,HL		;10	Shift HL Left 2
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 3
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 4
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 5
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 6
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 7
		CALL C,	CRC_UPC		;17
		ADD	HL,HL		;10	Shift HL Left 8
		CALL C,	CRC_UPC		;17
		EX	DE,HL			;4
		RET			;10

CRC_UPC		LD	A,H		;5
		XOR	0x10		;7
		LD	H,A		;5
		LD	A,L		;5
		XOR	0x21		;7
		LD	L,A		;5
		RET			;10


;XModem implementation on 8080 Monitor (CP/M-80)
;
;Terminal uploads to 8080 system:
;-Terminal user enters command "XU aaaa"
;-8080 "drives" the protocol since it's the receiver
;-8080 sends <Nak> every 10 seconds until the transmitter sends a packet
;-if transmitter does not begin within 10 trys (100 seconds), 8080 aborts XMODEM
;-a packet is:
; <SOH> [seq] [NOT seq] [128 bytes of data] [checksum or CRC]
;
;<SOH> = 1 (Start of Header)
;<EOT> = 4 (End of Transmission)
;<ACK> = 6
;<DLE> = 16
;<DC1> = 17 (X-ON)
;<DC3> = 19 (X-OFF)
;<NAK> = 21
;<SYN> = 22
;<CAN> = 24 (Cancel)
;
;Checksum is the ModuLOW 256 sum of all 128 data bytes
;
;                                     <<<<<          [NAK]
;       [SOH][001][255][...][csum]    >>>>>
;                                     <<<<<          [ACK]
;       [SOH][002][254][...][csum]    >>>>>
;                                     <<<<<          [ACK]
;       [SOH][003][253][...][csum]    >>>>>
;                                     <<<<<          [ACK]
;       [EOT]                         >>>>>
;                                     <<<<<          [ACK]
;
;-if we get <EOT> then ACK and terminate XModem
;-if we get <CAN> then terminate XModem
;-if checksum invalid, then NAK
;-if seq number not correct as per [NOT seq], then NAK
;-if seq number = previous number, then ACK (But ignore block)
;-if seq number not the expected number, then <CAN><CAN> and terminate XModem
;-if data not received after 10 seconds, then NAK (inc Timeout Retry)
;-if timeout retry>10 then <CAN><CAN> and terminate XModem
;
;-To keep synchronized,
;  -Look for <SOH>, qualify <SOH> by checking the [seq] / [NOT seq]
;  -if no <SOH> found after 135 chars, then NAK
;
;-False EOT condtion
;  -NAK the first EOT
;  -if the next char is EOT again, then ACK and leave XModem
;
;-False <CAN>, expect a 2nd <CAN> ?
;
;-Using CRC, send "C" instead of <NAK> for the first packet
;  -Send "C" every 3 seconds for 3 tries, then degrade to checksums by sending <NAK>
;
;
;
;* The character-receive subroutine should be called with a
;parameter specifying the number of seconds to wait.  The
;receiver should first call it with a time of 10, then <nak> and
;try again, 10 times.
;  After receiving the <soh>, the receiver should call the
;character receive subroutine with a 1-second timeout, for the
;remainder of the message and the <cksum>.  Since they are sent
;as a continuous stream, timing out of this implies a serious
;like glitch that caused, say, 127 characters to be seen instead
;of 128.
;
;* When the receiver wishes to <nak>, it should call a "PURGE"
;subroutine, to wait for the line to clear.  Recall the sender
;tosses any characters in its UART buffer immediately upon
;completing sending a block, to ensure no glitches were mis-
;interpreted.
;  The most common technique is for "PURGE" to call the
;character receive subroutine, specifying a 1-second timeout,
;and looping back to PURGE until a timeout occurs.  The <nak> is
;then sent, ensuring the other end will see it.
;
;* You may wish to add code recommended by Jonh Mahr to your
;character receive routine - to set an error flag if the UART
;shows framing error, or overrun.  This will help catch a few
;more glitches - the most common of which is a hit in the high
;bits of the byte in two consecutive bytes.  The <cksum> comes
;out OK since counting in 1-byte produces the same result of
;adding 80H + 80H as with adding 00H + 00H.



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 8	Menu operations. RAM TEST
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; RAM TEST

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 10	BIOS.
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; CONSOLE BIOS

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Keyboard Get A byte
;All Keys are equal, but F works as a SHIFT on Press and F on release
;Output:	Z=1, No Key Pressed
;		Z=0, A=Key Pressed, bit 4 = Shift, ie, 0x97 = Shift-7
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Select Put_Char Output
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


;===============================================
;TIMED1_GETCHAR - Gets a character within 1 second
;-----------------------------------------------
TIMED1_GETCHAR	LD	A, 2

;===============================================
;TIMED_GETCHAR - Gets a character within a time limit
;in:	A contains # of seconds to wait before returning
;out: 	C=1, No Char (Time Out)
;	C=0, A = Char
;-----------------------------------------------

TIMED_GETCHAR_BC
		CALL	In_CharBC	; This is a blocking call
		CP	A, 27		; ESC
		JP	Z, TGC_TOBC
		OR	A		; C=0
		RET
TGC_TOBC
		SCF			; C=1
		RET


TIMED_GETCHAR	
		PUSH	DE
		PUSH	BC
		LD	D,A
TGC_LP1		LD	C,142		; D,C=Loop Count down until timeout
TGC_LP2		
		RST	18H		; Check if a char is available
		CP	A, 00H
		JR	NZ, TGC_AVAILABLE	; NZ = available		
;		CALL	In_Char	;87	;TEST FOR RX DATA
;		JP	NC, TGC_RET	;10
		DJNZ	TGC_LP2	;13/8	;110 Cycles inner Loop time. 70*256*.25 ~= 7 mSec
		DEC	C	;5
		JP 	NZ, TGC_LP2	;10
		DEC	D
		JP	NZ, TGC_LP1
		SCF		; BC uncommented this...SET CARRY TO INDICATE TIME OUT
TGC_RET		POP	BC
		POP	DE
		RET
TGC_AVAILABLE:
		RST	10H	; Go get the character
		CCF		; Clear C, I hope...!
		JP	TGC_RET

;		RET

;===============================================
;PURGE - Clears all in coming bytes until the line is clear for a full 2 seconds
;-----------------------------------------------
PURGE
		LD	A,4	;2 seconds for time out
		CALL	TIMED_GETCHAR
		JR	NC, PURGE
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;RS-232 RX Buffer Count
RX_COUNT	PUSH	HL
		LD	A,(RXBHEAD)
		LD	HL,RXBTAIL
		SUB	(HL)
		POP	HL
		RET

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;RS-232 Get A byte
;	Exit:	C=0, A=Byte from Buffer
;		C=1, Buffer Empty, no byte
;		w/call, tcy=87 if no byte
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; This is a block read
In_CharBC:
		RST 	10H
		OR	A		; Exit with C=0
		RET

#if 0
In_Char		PUSH	BC		;11 + 17(call)
		LD	A,(RXBHEAD)	;13 Test if TAIL=HEAD (=No bytes in buffer)
		LD	B,A		;4
		LD	A,(RXBTAIL)	;13
		XOR	B		;4 Check if byte(s) in receive buffer
		POP	BC		;10
		SCF			;4  C=1, Assume byte NOT available
		RET Z			;11 Exit if byte not available (ie TAIL=HEAD), C=1
		PUSH	HL
		LD	HL,(RXBTAIL)
		INC	L
		LD	(RXBTAIL),HL	;Tail = Tail + 1
		LD	A,(HL)		;A = Byte from buffer (@ TAIL)
		POP	HL
		OR	A		;Exit with C=0
		RET
#endif

;===============================================
;GET_CHAR -- Get a char from the console NO ECHO
;-----------------------------------------------
GET_CHAR_NE:	CALL	In_CharBC
		JR C,	GET_CHAR_NE
		RET

;===============================================
;GET_CHAR -- Get a char from the console
;-----------------------------------------------
GET_CHAR:	LD	A,(ECHO_ON)
		OR	A
		JR Z,	GET_CHAR_NE
GET_CHAR_LP	CALL	GET_CHAR_NE
		CP	' '	;Do not echo control chars
		RET	M
		;RET		;ECHO THE CHAR
		JP	PUT_CHARBC

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Send A byte to RS-232 or LED
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;The byte to be sent is done through the msb of the LED Display Output byte.
;To simplify AND expedite the sending of those Display bytes (with the RS-232 BIT), the transmitted
;byte will be scattered IN A secondary buffer that is 10 bytes (1 start, 8 data, 1 stop)
;This secondary buffer will have the transmitted bits mixed IN with the LED Display Bytes
;The Interrupt is disabled only at crucial moments, but otherwise left on to accept any characters
;received from the RS-232 line

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Chapter 11	ISR.  RS-232 Receive, LED & Keyboard scanning, Timer tic counting
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;                       *********   *******    ********
;                       *********  *********   *********
;                          ***     **     **   **     **
;                          ***     **          **     **
;---------------------     ***     *******     ********   ---------------------
;---------------------     ***       *******   ********   ---------------------
;                          ***            **   **  **
;                          ***     **     **   **   **
;                       *********  *********   **    **
;                       *********   *******    **     **
;
;
;	Normal timer interrupt takes 463 cycles
;	42  ISR Vectoring & Redirection
;	50  Timer Int Detection
;	28  LED Refresh (Re-enable Interrupts)
;	78  Resync & Prepare next LED Refresh value
;	111 Halt Test
;	38  TIC Counter
;	21  Keyboard/Display maintenance required check
;	41  User Interrupt Check
;	34  ISR Exit
;
;	Occuring 8 out of 32 ISR's:
;	82  Scanning non pressed keys
;
;	Occuring 1 out of 32 ISR's
;	165 Processing non pressed keys
;	97  Ctrl-C Checking
;	67  Beeper Timer
;	31  Cmd Expiration Timer
;	262 Display Memory contents
;	649 Display Register contents
;
;	24/32 ISR's = 463 cycles	= 11,112
;	7/32  ISR's = 545 cycles    	=  3,815
;	1/32  ISR's = 1,554 cycles	=  1,554 (Displaying Register)
;	Total over 32 ISR's		= 16,481
;	Average per ISR = 515 cycles
;			= 128.75uS used every 1024uS interrupt cycle
;			= 13% ISR Overhead (When Displaying Register)
;
;
;
;
;					;42 to get here from ORG 38h
;		;PUSH	HL = HL is pushed before getting here


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Appendix A	LED FONT
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Appendix B	RAM. System Ram allocation
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;


;                       ********      ***     **     **
;                       *********    *****    ***   ***
;                       **     **   *** ***   **** ****
;                       **     **  ***   ***  *********
;---------------------  ********   *********  ** *** **  ---------------------
;---------------------  ********   *********  ** *** **  ---------------------
;                       **  **     **     **  **     **
;                       **   **    **     **  **     **
;                       **    **   **     **  **     **
;                       **     **  **     **  **     **

RAM_LDRT	equ	0x8100	; bc bas32K.asm uses RAM from 8065h. Here, we can start higher up 0x8000

;----------------------------------------------------------------------------------------------------; RAM SPACE
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;----------------------------------------------------------------------------------------------------; RAM SPACE
RXBUFFER	equ	0xFE00	;256 bytes of RX Buffer space


;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;Reserve space from 0xFF60 to FF7F for Stack
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StackTop	equ	0xFF60	; Stack = 0xFF80 (Next Stack Push Location = 0xFF7F)

;*** BEGIN COLD_BOOT_INIT (RAM that is to be initialized upon COLD BOOT) ***
#if 0
RAMSIGNATURE	equ	0xFF60	;RAM signature
				;WARNING, Following 19 bytes must be consecutive in this order
RC_TYPE		equ	0xFF68	;Type of Reset (WARNING, Next 7 RC counters must end with lsb bits = 001,010,011,100,101,110,111)
RC_SOFT		equ	0xFF69	;Count of Resets by SOFT F-E SWITCH
RC_STEP		equ	0xFF6A	;Count of Resets by SINGLE STEP
RC_CC		equ	0xFF6B	;Count of Resets by CTRL-C
RC_HALT		equ	0xFF6C	;Count of Resets by HALT INSTRUCTION
RC_F0		equ	0xFF6D	;Count of Resets by pressing F & 0 keys
RC_RST0		equ	0xFF6E	;Count of Resets by RST 0 INSTRUCTION
RC_HARD		equ	0xFF6F	;Count of Resets by UNKNOWN RESET LINE

UiVec		equ	0xFF70	;User Interrupt Vector
;		equ	0xFF72	;
RegPtr		equ	0xFF73	;Ptr to Registers
ABUSS		equ	0xFF74	;
IoPtr		equ	0xFF76	; I/O Ptr
RX_ERR_LDRT	equ	0xFF77	;Counts False Start Bits (Noise Flag)
RX_ERR_STOP	equ	0xFF78	;Counts Missing Stop Bits (Framing Error)
RX_ERR_OVR	equ	0xFF79	;Counts Overrun Errors
BEEP_TO		equ	0xFF7A	;Count down the beep (beep duration)
#endif

hex_buffer	equ	0xFF70	;
;*** END COLD_BOOT_INIT (RAM that is to be initialized upon COLD BOOT) ***

				;Saved Registers
RSSP		equ	0xFF80	;Value of SP upon REGISTER SAVE
RSAF		equ	0xFF82	;Value of AF upon REGISTER SAVE
RSBC		equ	0xFF84	;Value of BC upon REGISTER SAVE
RSDE		equ	0xFF86	;Value of DE upon REGISTER SAVE
RSHL		equ	0xFF88	;Value of HL upon REGISTER SAVE
RPC		equ	0xFF8A	;Value of PC upon REGISTER SAVE
RSIX		equ	0xFF8C	;Value of IX upon REGISTER SAVE
RSIY		equ	0xFF8E	;Value of IY upon REGISTER SAVE
RSIR		equ	0xFF90	;Value of IR upon REGISTER SAVE
RSAF2		equ	0xFF92	;Value of AF' upon REGISTER SAVE
RSBC2		equ	0xFF94	;Value of BC' upon REGISTER SAVE
RSDE2		equ	0xFF96	;Value of DE' upon REGISTER SAVE
RSHL2		equ	0xFF98	;Value of HL' upon REGISTER SAVE


;*** BEGIN WARM_BOOT_INIT (RAM that is to be initialized on every boot) ***
				;WARNING, Following 33 bytes must be consecutive in this order
ANBAR_DEF	equ	0xFFA1	;Base setting for the Annunciator LED's (after current function times out)
GET_REG		equ	0xFFA2	;Get Reg Routine (in monitor mode, registers fetched from RAM)
PUT_REG		equ	0xFFA4	;Put Reg Routine
CTRL_C_CHK	equ	0xFFA6	;Vector for CTRL-C Checking
LDISPMODE	equ	0xFFA8	;Last Display Mode (Holds DISPMODE while in HEX Entry)
DISPMODE	equ	0xFFAA	;Display Routine
KEY_EVENT	equ	0xFFAC	;
IK_TIMER	equ	0xFFAE	;IMON TIMEOUT
KEYBFMODE	equ	0xFFAF	;KEY INPUT MODE. 8F=HEX INPUT, 90=Shiftable
DISPLABEL	equ	0xFFB0	;Display Label Refresh
IK_HEXST	equ	0xFFB1	;IMON HEX Input State
HEX_CURSOR	equ	0xFFB2	;HEX Input Cursor location
HEX_READY	equ	0xFFB4	;HEX Input Ready
LED_CURSOR	equ	0xFFB6	;Cursor location for LED Put_Char
PUTCHAR_EXE	equ	0xFFB8	;PutChar Execution (Set for PC_LED or PC_RS232)
RXBHEAD		equ	0xFFBA	;RS-232 RX BUFFER HEAD
RXBTAIL		equ	0xFFBC	;RS-232 RX BUFFER TAIL
INT_VEC		equ	0xFFBE	;Vector to Interrupt ISR
SCAN_PTR	equ	0xFFC0	;SCAN_PTR points to next LED_DISPLAY byte to output (will always be 1 more
				;than the current hardware column because hardware automatically advances)

;*** END WARM_BOOT_INIT (RAM that is to be initialized on every boot) ***


SDISPMODE	equ	0xFFC2

CLEARED_SPACE	equ	0xFFC2	;Bytes here and later are cleared upon init (some initialized seperately)
CLEARED_LEN	equ	0xFFFF - CLEARED_SPACE + 1
CTRL_C_TIMER	equ	0xFFDE	;Count down the CTRL-C condition
SOFT_RST_FLAG	equ	0xFFDF	;Flag a Soft Reset (F-E Keys, Single Step)

				;Display/Serial Comms
LED_DISPLAY	equ	0xFFE0	;8 Bytes of LED Output bytes to Scan to hardware
;8 Bytes			;Warning, LED_DISPLAY must be nibble aligned at E0 (XXE0)
LED_ANBAR	equ	0xFFE7	;LED Annunciator Bar (Part of LED_DISPLAY Buffer)

IK_HEXL		equ	0xFFE8	;IMON HEX INPUT
IK_HEXH		equ	0xFFE9	;IMON HEX INPUT

KBHEXSAMPLE	equ	0xFFEA	;KEY SAMPLER Input HEX format
KBOCTSAMPLE	equ	0xFFEB	;KEY SAMPLER Input Octal Format (Upper-Row/Lower-Row)
KEY_OCTAL	equ	0xFFEC	;KEY Input Octal Format (Upper-Row/Lower-Row)
KEYBSCANPV	equ	0xFFED	;KEY Input HEX format
KEYBSCANTIMER	equ	0xFFEE	;KEY Input TIMER
KEY_PRESSED	equ	0xFFEF	;KEY INPUT LAST & Currently Processing

TicCnt		equ	0xFFF0	;Tic Counter
;TicCnt		equ	0xFFF1	;
ECHO_ON		equ	0xFFF2	;Echo characters
XMSEQ		equ	0xFFF3	;XMODEM SEQUENCE NUMBER
XMTYPE		equ	0xFFF4	;XMODEM BLOCK TYPE (CRC/CS)
SCAN_LED	equ	0xFFF5	;Holds the next LED output
LED_DISPLAY_SB	equ	0xFFF6	;10 Bytes FFF6=Start BIT, 7,8,9,A,B,C,D,E=Data bits, F=Stop BIT
;10 bytes	equ	0xFFFF	;Warning, LED_DISPLAY_TBL must be at this address (XXF6)


;                       *********   *******    *********
;                       *********  *********   *********
;                       **         **     **   **
;                       **         **     **   **
;---------------------  *******    **     **   *******    ---------------------
;---------------------  *******    **     **   *******    ---------------------
;                       **         **     **   **
;                       **         **     **   **
;                       *********  *********   **
;                       *********   *******    **

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;
;	Appendix C	Z80 Instruction Reference
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<;

;===================================================
;Mnemonic	Cyc	Opcodes		Bytes
;ADC A,(HL)	7	8E		1
;ADC A,(IX+o)	19	DD 8E oo	3
;ADC A,(IY+o)	19	FD 8E oo	3
;ADC A,n	7      	CE nn        	2
;ADC A,r	4	88+r		1
;ADC A,IXp	8	DD 88+P		2
;ADC A,IYp	8	FD 88+P		2
;ADC HL,BC	15	ED 4A		2
;ADC HL,DE	15	ED 5A		2
;ADC HL,HL	15	ED 6A		2
;ADC HL,sp	15	ED 7A		2
;ADD A,(HL)	7	86		1
;ADD A,(IX+o)	19	DD 86 oo	3
;ADD A,(IY+o)	19	FD 86 oo	3
;ADD A,n	7      	C6 nn		2
;ADD A,r	4	80+r		1
;ADD A,IXp      8      	DD 80+P		2
;ADD A,IYp      8      	FD 80+P		2
;ADD HL,BC	11	09		1
;ADD HL,DE	11	19		1
;ADD HL,HL	11	29		1
;ADD HL,sp	11	39		1
;ADD IX,BC	15	DD 09		2
;ADD IX,DE	15	DD 19		2
;ADD IX,IX	15	DD 29		2
;ADD IX,sp	15	DD 39		2
;ADD IY,BC	15	FD 09		2
;ADD IY,DE	15	FD 19		2
;ADD IY,IY	15	FD 29		2
;ADD IY,sp	15	FD 39		2
;AND (HL)	7	A6		1
;AND (IX+o)	19	DD A6 oo	3
;AND (IY+o)	19	FD A6 oo	3
;AND n       	7      	E6 nn		2
;AND r		4	A0+r		1
;AND IXp        8      	DD A0+P		2
;AND IYp        8      	FD A0+P		2
;BIT B,(HL)	12	CB 46+8*B	2	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;BIT B,(IX+o)	20	DD CB oo 46+8*B	4	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;BIT B,(IY+o)	20	FD CB oo 46+8*B	4	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;BIT B,r	8	CB 40+8*B+r	2	Test BIT B (AND the BIT, but do not save), Z=1 if BIT tested is 0
;CALL nn	17	CD nn nn	3
;CALL C,nn	17/10	DC nn nn	3
;CALL M,nn	17/10	FC nn nn	3
;CALL NC,nn	17/10	D4 nn nn	3
;CALL NZ,nn	17/10	C4 nn nn	3
;CALL P,nn	17/10	F4 nn nn	3
;CALL PE,nn	17/10	EC nn nn	3
;CALL PO,nn	17/10	E4 nn nn	3
;CALL Z,nn	17/10	CALL C, nn nn	3
;CCF		4	3F		1
;CP (HL)	7	BE		1
;CP (IX+o)	19	DD BE oo	3
;CP (IY+o)	19	FD BE oo	3
;CP n        	7      	FE nn		2
;CP r		4	B8+r		1
;CP IXp        	8      	DD B8+P		2
;CP IYp        	8      	FD B8+P        	2
;CPD		16	ED A9		2
;CPDR		21/16	ED B9		2
;CP		16	ED A1		2
;CPIR		21/16	ED B1		2
;CPL		4	2F		1
;DAA		4	27		1
;DEC (HL)	11	35		1
;DEC (IX+o)	23	DD 35 oo	3
;DEC (IY+o)	23	FD 35 oo	3
;DEC A		4	3D		1
;DEC B		4	05		1
;DEC BC		6	0B		1
;DEC C		4	0D		1
;DEC D		4	15		1
;DEC DE		6	1B		1
;DEC E		4	1D		1
;DEC H		4	25		1
;DEC HL		6	2B		1
;DEC IX		10	DD 2B		2
;DEC IY		10	FD 2B		2
;DEC IXp        8      	DD 05+8*P	2
;DEC IYp        8      	FD 05+8*q      	2
;DEC L		4	2D		2
;DEC sp		6	3B		1
;DI		4	F3		1
;DJNZ o		13/8	10 oo		2
;EI		4	FB		1
;EX (sp),HL	19	E3		1
;EX (sp),IX	23	DD E3		2
;EX (sp),IY	23	FD E3		2
;EX AF,AF'	4	08		1
;EX	DE,HL	4	EB		1
;EXX		4	D9		1
;HALT		4	76		1
;IM 0		8	ED 46		2
;IM 1		8	ED 56		2
;IM 2		8	ED 5E		2
;IN A,(C)	12	ED 78		2
;IN A,(n)	11	db nn		2
;IN B,(C)	12	ED 40		2
;IN C,(C)	12	ED 48		2
;IN D,(C)	12	ED 50		2
;IN E,(C)	12	ED 58		2
;IN H,(C)	12	ED 60		2
;IN L,(C)	12	ED 68		2
;IN F,(C)	12	ED 70		3
;INC (HL)	11	34		1
;INC (IX+o)	23	DD 34 oo	3
;INC (IY+o)	23	FD 34 oo	3
;INC A		4	3C		1
;INC B		4	04		1
;INC BC		6	03		1
;INC C		4	0C		1
;INC D		4	14		1
;INC DE		6	13		1
;INC E		4	1C		1
;INC H		4	24		1
;INC HL		6	23		1
;INC IX		10	DD 23		2
;INC IY		10	FD 23		2
;INC IXp        8      	DD 04+8*P	2
;INC IYp       	8      	FD 04+8*q      	2
;INC L		4	2C		1
;INC sp		6	33		1
;IND		16	ED AA		2
;INDR		21/16	ED BA		2
;INI		16	ED A2		2
;INIR		21/16	ED B2		2
;JP nn		10	C3 nn nn	3	Jump Absolute
;JP (HL)	4	E9		1
;JP (IX)	8	DD E9		2
;JP (IY)	8	FD E9		2
;JP C,nn	10	DA nn nn	3
;JP M,nn	10	FA nn nn	3
;JP NC,nn	10	D2 nn nn	3
;JP NZ,nn	10	C2 nn nn	3
;JP P,nn	10	F2 nn nn	3
;JP PE,nn	10	EA nn nn	3
;JP PO,nn	10	E2 nn nn	3
;JP Z,nn	10	CA nn nn	3
;JR o		12	18 oo		2	Jump Relative
;JR C,o		12/7	38 oo		2
;JR NC,o	12/7	30 oo		2
;JR NZ,o	12/7	20 oo		2
;JR Z,o		12/7	28 oo		2
;LD (BC),A	7	02		1
;LD (DE),A	7	12		1
;LD (HL),n      10     	36 nn		2
;LD (HL),r	7	70+r		1
;LD (IX+o),n    19     	DD 36 oo nn	4
;LD (IX+o),r	19	DD 70+r oo	3
;LD (IY+o),n    19     	FD 36 oo nn	4
;LD (IY+o),r	19	FD 70+r oo	3
;LD (nn),A	13	32 nn nn	3
;LD (nn),BC	20	ED 43 nn nn	4
;LD (nn),DE	20	ED 53 nn nn	4
;LD (nn),HL	16	22 nn nn	3
;LD (nn),IX	20	DD 22 nn nn	4
;LD (nn),IY	20	FD 22 nn nn	4
;LD (nn),sp	20	ED 73 nn nn	4
;LD A,(BC)	7	0A		1
;LD A,(DE)	7	1A		1
;LD A,(HL)	7	7E		1
;LD A,(IX+o)	19	DD 7E oo	3
;LD A,(IY+o)	19	FD 7E oo	3
;LD A,(nn)	13	3A nn nn	3
;LD A,n        	7     	3E nn		2
;LD A,r		4	78+r		1
;LD A,IXp       8      	DD 78+P        	2
;LD A,IYp       8      	FD 78+P        	2
;LD A,I		9	ED 57		2
;LD A,R		9	ED 5F		2
;LD B,(HL)	7	46		1
;LD B,(IX+o)	19	DD 46 oo	3
;LD B,(IY+o)	19	FD 46 oo	3
;LD B,n        	7      	06 nn		2
;LD B,r		4	40+r		1
;LD B,IXp       8      	DD 40+P		2
;LD B,IYp       8     	FD 40+P        	2
;LD BC,(nn)	20	ED 4B nn nn	4
;LD BC,nn	10	01 nn nn	3
;LD C,(HL)	7	4E		1
;LD C,(IX+o)	19	DD 4E oo	3
;LD C,(IY+o)	19	FD 4E oo	3
;LD C,n        	7      	0E nn        	2
;LD C,r		4	48+r		1
;LD C,IXp       8      	DD 48+P        	2
;LD C,IYp       8      	FD 48+P		2
;LD D,(HL)	7	56		1
;LD D,(IX+o)	19	DD 56 oo	3
;LD D,(IY+o)	19	FD 56 oo	3
;LD D,n        	7      	16 nn		2
;LD D,r		4	50+r		1
;LD D,IXp       8      	DD 50+P        	2
;LD D,IYp       8      	FD 50+P        	2
;LD DE,(nn)	20	ED 5B nn nn	4
;LD DE,nn	10	11 nn nn	3
;LD E,(HL)	7	5E		1
;LD E,(IX+o)	19	DD 5E oo	3
;LD E,(IY+o)	19	FD 5E oo	3
;LD E,n        	7      	1E nn        	2
;LD E,r		4	58+r		1
;LD E,IXp       8      	DD 58+P        	2
;LD E,IYp       8      	FD 58+P        	2
;LD H,(HL)	7	66		1
;LD H,(IX+o)	19	DD 66 oo	3
;LD H,(IY+o)	19	FD 66 oo	3
;LD H,n        	7      	26 nn		2
;LD H,r		4	60+r		1
;LD HL,(nn)	16	2A nn nn	5
;LD HL,nn	10	21 nn nn	3
;LD I,A		9	ED 47		2
;LD IX,(nn)	20	DD 2A nn nn	4
;LD IX,nn	14	DD 21 nn nn	4
;LD IXh,n       11     	DD 26 nn 	2
;LD IXh,P       8     	DD 60+P		2
;LD IXl,n       11     	DD 2E nn 	2
;LD IXl,P       8     	DD 68+P		2
;LD IY,(nn)	20	FD 2A nn nn	4
;LD IY,nn	14	FD 21 nn nn	4
;LD IYh,n       11     	FD 26 nn 	2
;LD IYh,q       8     	FD 60+P		2
;LD IYl,n       11     	FD 2E nn 	2
;LD IYl,q       8     	FD 68+P		2
;LD L,(HL)	7	6E		1
;LD L,(IX+o)	19	DD 6E oo	3
;LD L,(IY+o)	19	FD 6E oo	3
;LD L,n       	7     	2E nn		2
;LD L,r		4	68+r		1
;LD R,A		9	ED 4F		2
;LD sp,(nn)	20	ED 7B nn nn	4
;LD sp,HL	6	F9		1
;LD sp,IX	10	DD F9		2
;LD sp,IY	10	FD F9		2
;LD sp,nn	10	31 nn nn	3
;LDD		16	ED A8		2
;LDDR		21/16	ED B8		2
;LDI		16	ED A0		2
;LDIR		21/16	ED B0		2
;MULUB A,r 		ED C1+8*r 	2
;MULUW HL,BC		ED C3 		2
;MULUW HL,sp		ED F3 		2
;NEG		8	ED 44		2
;NOP		4	00		1
;OR (HL)	7	B6		1
;OR (IX+o)	19	DD B6 oo	3
;OR (IY+o)	19	FD B6 oo	3
;OR n       	7     	F6 nn		2
;OR r		4	B0+r		1
;OR IXp       	8     	DD B0+P		2
;OR IYp       	8     	FD B0+P		2
;OTDR		21/16	ED BB		2
;OTIR		21/16	ED B3		2
;OUT (C),A	12	ED 79		2
;OUT (C),B	12	ED 41		2
;OUT (C),C	12	ED 49		2
;OUT (C),D	12	ED 51		2
;OUT (C),E	12	ED 59		2
;OUT (C),H	12	ED 61		2
;OUT (C),L	12	ED 69		2
;OUT (n),A	11	D3 nn		2
;OUTD		16	ED AB		2
;OUTI		16	ED A3		2
;POP AF		10	F1		1
;POP BC		10	C1		1
;POP DE		10	D1		1
;POP HL		10	E1		1
;POP IX		14	DD E1		2
;POP IY		14	FD E1		2
;PUSH AF	11	F5		1
;PUSH BC	11	C5		1
;PUSH DE	11	D5		1
;PUSH HL	11	E5		1
;PUSH IX	15	DD E5		2
;PUSH IY	15	FD E5		2
;RES B,(HL)	15	CB 86+8*B	2	Reset BIT B (clear BIT)
;RES B,(IX+o)	23	DD CB oo 86+8*B	4	Reset BIT B (clear BIT)
;RES B,(IY+o)	23	FD CB oo 86+8*B	4	Reset BIT B (clear BIT)
;RES B,r	8	CB 80+8*B+r	2	Reset BIT B (clear BIT)
;RET		10	C9		1
;RET C		11/5	D8		1
;RET M		11/5	F8		1
;RET NC		11/5	D0		1
;RET NZ		11/5	C0		1
;RET P		11/5	F0		1
;RET PE		11/5	E8		1
;RET PO		11/5	E0		1
;RET Z		11/5	C8		1
;RETI		14	ED 4D		2
;RETN		14	ED 45		2
;RL (HL)	15	CB 16		2  	9 BIT rotate left through Carry
;RL (IX+o)	23	DD CB oo 16	4	9 BIT rotate left through Carry
;RL (IY+o)	23	FD CB oo 16	4	9 BIT rotate left through Carry
;RL r       	8     	CB 10+r		2	9 BIT rotate left through Carry
;RLA		4	17		1	9 BIT rotate left through Carry
;RLC (HL)	15	CB 06		2	8 BIT rotate left, C=msb
;RLC (IX+o)	23	DD CB oo 06	4	8 BIT rotate left, C=msb
;RLC (IY+o)	23	FD CB oo 06	4	8 BIT rotate left, C=msb
;RLC r		8	CB 00+r		2	8 BIT rotate left, C=msb
;RLCA		4	07		1	8 BIT rotate left, C=msb
;RLD		18	ED 6F		2	3 nibble rotate, A3-0 to (HL)3-0, (HL)3-0 to (HL)7-4, (HL)7-4 to A3-0
;RR (HL)	15	CB 1E		2	9 BIT rotate right through Carry
;RR (IX+o)	23	DD CB oo 1E	4	9 BIT rotate right through Carry
;RR (IY+o)	23	FD CB oo 1E	4	9 BIT rotate right through Carry
;RR r       	8     	CB 18+r		2	9 BIT rotate right through Carry
;RRA		4	1F		1	9 BIT rotate right through Carry
;RRCA (HL)	15	CB 0E		2	8 BIT rotate right, C=lsb
;RRCA (IX+o)	23	DD CB oo 0E	4	8 BIT rotate right, C=lsb
;RRCA (IY+o)	23	FD CB oo 0E	4	8 BIT rotate right, C=lsb
;RRCA r		8	CB 08+r		2	8 BIT rotate right, C=lsb
;RRCAA		4	0F		1	8 BIT rotate right, C=lsb
;RRD		18	ED 67		2	3 nibble rotate, A3-0 to (HL)7-4, (HL)7-4 to (HL)3-0, (HL)3-0 to A3-0
;RST 0		11	C7		1
;RST 8H		11	CF		1
;RST 10H	11	D7		1
;RST 18H	11	DF		1
;RST 20H	11	E7		1
;RST 28H	11	EF		1
;RST 30H	11	F7		1
;RST 38H	11	FF		1
;SBC A,(HL)	7	9E		1
;SBC A,(IX+o)	19	DD 9E oo	3
;SBC A,(IY+o)	19	FD 9E oo	3
;SBC A,n	7	DE nn		2
;SBC A,r	4	98+r		1
;SBC A,IXp      8     	DD 98+P		2
;SBC A,IYp      8     	FD 98+P		2
;SBC HL,BC	15	ED 42		2
;SBC HL,DE	15	ED 52		2
;SBC HL,HL	15	ED 62		2
;SBC HL,sp	15	ED 72		2
;SCF		4	37		1	Set Carry
;SET B,(HL)	15	CB C6+8*B	2	Set BIT B (0-7)
;SET B,(IX+o)	23	DD CB oo C6+8*B	4	Set BIT B (0-7)
;SET B,(IY+o)	23	FD CB oo C6+8*B	4	Set BIT B (0-7)
;SET B,r	8	CB C0+8*B+r	2	Set BIT B (0-7)
;SLA (HL)	15	CB 26		2	9 BIT shift left, C=msb, lsb=0
;SLA (IX+o)	23	DD CB oo 26	4	9 BIT shift left, C=msb, lsb=0
;SLA (IY+o)	23	FD CB oo 26	4	9 BIT shift left, C=msb, lsb=0
;SLA r		8	CB 20+r		2	9 BIT shift left, C=msb, lsb=0
;SRA (HL)	15	CB 2E		2	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRA (IX+o)	23	DD CB oo 2E	4	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRA (IY+o)	23	FD CB oo 2E	4	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRA r		8	CB 28+r		2	8 BIT shift right, C=lsb, msb=msb (msb does not change)
;SRL (HL)	15	CB 3E		2	8 BIT shift right, C=lsb, msb=0
;SRL (IX+o)	23	DD CB oo 3E	4	8 BIT shift right, C=lsb, msb=0
;SRL (IY+o)	23	FD CB oo 3E	4	8 BIT shift right, C=lsb, msb=0
;SRL r		8	CB 38+r		2	8 BIT shift right, C=lsb, msb=0
;SUB (HL)	7	96		1
;SUB (IX+o)	19	DD 96 oo	3
;SUB (IY+o)	19	FD 96 oo	3
;SUB n       	7     	D6 nn		2
;SUB r		4	90+r		1
;SUB IXp       	8     	DD 90+P		2
;SUB IYp       	8     	FD 90+P		2
;XOR (HL)	7	AE		1
;XOR (IX+o)	19	DD AE oo	3
;XOR (IY+o)	19	FD AE oo	3
;XOR n       	7     	EE nn		2
;XOR r       	4     	A8+r		1
;XOR IXp       	8     	DD A8+P		2
;XOR IYp       	8     	FD A8+P		2
;
;variables used:
;
; B = 3-BIT value
; n = 8-BIT value
; nn= 16-BIT value
; o = 8-BIT offset (2-complement)
; r = Register. This can be A, B, C, D, E, H, L OR (HL). Add to the last byte of the opcode:
;
;		Register	Register bits value
;		A		7
;		B		0
;		C		1
;		D		2
;		E		3
;		H		4
;		L		5
;		(HL)		6
;
; P = The high OR low part of the IX OR IY register: (IXh, IXl, IYh, IYl). Add to the last byte of the opcode:
;
;		Register	Register bits value
;		A		7
;		B		0
;		C		1
;		D		2
;		E		3
;		IXh (IYh)	4
;		IXl (IYl)	5
		