
// start=$8000 (for Kick Assembler) 

// ----------------------------------------------------
// This code running used on Ben Eater's 6502 computer
//
// ----------------------------------------------------
			*=$8000 "Main Program"
.encoding	"ascii"
.const		PORT_A	= $6001			// Registers control
.const		PORT_B	= $6000			// Send commands + send/receive data, check Busy Flag
.const		DDR_A	= $6003			// Data Direction Register A controls PORT_A pins; !I/O
.const		DDR_B	= $6002			// Data Direction Register B controls PORT_B pins; !I/O
.const		EN		= %10000000		// ENable bit
.const		RW		= %01000000		// R/!W bit
.const		RS		= %00100000		// RS bit
.const		reset	= $8000

// Check Busy is done before sending command / data to LCD 
// RS = 0	Write command to LCD (Instruction Register, IR) or read Busy Flag and Address
// RS = 1	Send/receive data to/from LCD (Data Register, DR)
// R/!W = 1	Read operation
// R/!W = 0	Write operation

init:
			ldx #$ff
			txs
// ----- @Step 1 Configure 6522@ -----
			lda #%11111111			// set all PORT_B pins for output (used for Data lines)
			sta DDR_B
			lda #%11100000			// set first three PORT_A pins for output (EN, RW, RS)
			sta DDR_A
// ----- @LCD Reset@ -----
	// 1) Wait > 15 ms; x=1 --> 1ms
			ldx #16
			jsr delay
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			lda #%00110000			// set 8 bits
			jsr lcd_instruction_no_BF
	// 2) Wait > 4.1 ms
			ldx #5
			jsr delay
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			lda #%00110000			// set 8 bits			
			jsr lcd_instruction_no_BF
	// 3) Wait > 0.1 ms
			ldx #1
			jsr delay
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			lda #%00110000			// set 8 bits			
			jsr lcd_instruction_no_BF

// Initialization steps as per Data Sheet: Wait 15ms; 4.1 ms; .1 ms; Function Set; Display Off; Display Clear; Entry Mode Set 

// ----- @Step 2 Function Set@ -----
			lda #%00111000			// set 8 bits; 2 lines; 5x8
			jsr lcd_instruction

// ----- @Step 2a Display Off@ -----
			lda #%00001000			// Is this actually needed by LCD reset sequence?
			jsr lcd_instruction		// 22-03-2022 AIUI it looks like LCD OFF *not* mandatory for LCD initialization?

// ----- @Step 3a Clear display@ -----
			lda #%00000001			// Clear display, set Address Counter (AC) = 0
			jsr lcd_instruction
			ldx #1
			jsr delay				// if no delay after Clear, first few following chars not printed
									// TBH, initialization delays looks like not having impact at all - computer woks fine anyway 

// ----- @Step 4 Entry Mode Set@ -----
			lda #%00000110			// Set cursor direction (HI Increment / LO Decrement); no display shift
			jsr lcd_instruction

// ----- @Step 4a (used to be 3b) Display On@ -----
			lda #%00001111			// Display On; Curson On; Blink On
			jsr lcd_instruction

			//jmp scroll_demo

// ----- @ TMP code - reminder: need to learn Cursor + Display shift@ -----
//			lda #%00011000			// Scroll Display; left
//			sta	PORT_B
//			jsr lcd_instruction
						

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++ WRITE SOMETHING TO LCD ++++++++  
  			+++++++++++++++++++++++++++++++++++++++*/
//	jmp print_helloworld_exit
print_helloworld:
			ldx #$00
print_helloworld_loop:
			lda helloworld,x
			cmp #$ff 
			beq print_helloworld_exit	
			jsr lcd_text
			inx
			bne print_helloworld_loop 
print_helloworld_exit:
//!here:		jmp !here-

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++ DIRECT WRITE TO LCD +++++++++++  
  			+++++++++++++++++++++++++++++++++++++++*/
// jmp !exit++
direct_write:
// ----- @First line@ -----
line1_write:
			lda #%11111111			// Set PORT_B pins for output
			sta DDR_B
			ldx #$00
!loop:
			txa
			ora #%10000000			// Set DDRAM Address ($80) + 7 bits Address; DRAM 1st line starts at 0x00
			jsr lcd_instruction
			lda line1text,x
			cmp #$ff
			beq !exit+
			sta PORT_B				// Output char to PORT_B
			lda #(RS | 0)			// Set RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN			
			sta PORT_A
			eor #EN 
			sta PORT_A
			inx
			bne !loop-				// previuos loop
!exit:
// ----- @Second line@ -----
line2_write:
			ldx #$00
!loop:
			txa
			ora #%11000000			// Set DDRAM Address ($80) + $40 (DRAM 2nd line starts at 0x40) + 7 bits Address
			jsr lcd_instruction
			lda line2text,x
			cmp #$ff
			beq !exit+
			sta PORT_B				// Output char to PORT_B
			lda #(RS | 0)			// Set RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN			
			sta PORT_A
			eor #EN
			sta PORT_A
			inx
			bne !loop-				// previuos loop
!exit:
//!here:		jmp !here-

			/*+++++++++++++++++++++++++++++++++++++++
			++++ DIRECT WRITE & READ TO/FROM LCD ++++  
  			+++++++++++++++++++++++++++++++++++++++*/
// jmp !exit+
			// Clear some RAM; data read from LCD is stored here for later checking if data sent was meaningful / nonsense
			// in case the display is corrupt / empty / unreadable
			ldx #$00
			txa
!loop:
			sta $1000,x
			inx
			bne !loop-
direct_rw:
// ----- @ Write line 1 & 2 simultaneously; also read line 1 (or 2) and store in RAM
			ldx #$00
!loop:
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address (1st line starts at 0x00)
			sta PORT_B
			jsr check_busy
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// EN strobed; Command sent
			lda line1text_2,x
			sta PORT_B			
			jsr check_busy			
			lda #(RS | 0)			// RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// EN Strobed; Char sent for line 1
			txa						// reload index X to A because A was changed
			ora #%11000000			// Set DDRAM Address command ($80) + 7 bits Address (2nd line starts at 0x40)
			sta PORT_B
			jsr check_busy
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// EN Strobed; Command sent
			lda line2text_2,x
//			cmp #$ff
//			beq end
			sta PORT_B
			jsr check_busy						
			lda #(RS | 0)			// RS HI (select DR), R/!W LO (write)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// EN Strobed; Char sent for line 2
		// let's now read from first line
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			sta PORT_B
			jsr check_busy						
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent
			jsr check_busy			// ++++ 02-02-2022 check BF added to fix random blank chars (spaces) issues @ higher clock rates						
			lda #%00000000			// set PORT_B pins for input
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
	// 31-01-2022 AIUI as per datasheet it looks like data can be read also after EN fallen to LO (strobe complete) (unsure)
	// actually for me it only works if data is read on EN = HI				
	// 04-02-2022: https://hackaday.io/project/174128-db6502/log/181887-amazing-upside-to-sloppy-coding-hd44780-part-2				
	//		confirms Read is done on EN = HI
	// 14-03-2022: I understood wrong on 31-01-2022. http://forum.6502.org/viewtopic.php?f=2&t=4379&hilit=HD44780#p50129
	//		Klaus2m5 confirms Read is done on EN = HI
			lda PORT_B
			sta $1000,x				// Store DDRAM content in computer RAM
			lda PORT_A
			eor #EN
			sta PORT_A				// DDRAM characted read
			inx
			cpx #$10				// 16 chars
			bpl !exit+
			jmp !loop-
!exit:
//!here:		jmp !here-

			/*+++++++++++++++++++++++++++++++++++++++
			++++++++++ SWAP LCD LINE 1 and 2+++++++++  
  			+++++++++++++++++++++++++++++++++++++++*/
// jmp !exit+
			// weird behaviour @ 0.8  MHz... until check_busy added before 
  			// 01-02-2022 reading messed chars issue. 
  			// 02-02-2022 looks like fixed after check busy added
LCD_swap_lines:
			ldx #$00
!loop:
		// read from line 1 
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			sta PORT_B
			jsr check_busy						
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent
			jsr check_busy			// fix messed chars issue			
			lda #%00000000			// Set PORT_B pins for input 
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			lda PORT_B				// Read char from DDRAM 1st line and store in stack
			pha						// Save line 1 char in stack
			sta $1020,x
			lda PORT_A
			eor #EN
			sta PORT_A				// DDRAM characted read
		// read from line 2
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%11000000			// Set DDRAM Address command ($80) + 7 bits Address (2nd line starts at 0x40)
			sta PORT_B
			jsr check_busy						
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent
			jsr check_busy 			// fix messed chars issue
			lda #%00000000			// Set PORT_B pins for input 
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			lda PORT_B				// Read char from DDRAM 2nd line and store in stack
			pha						// Save line 2 char in stack
			sta $1030,x
			lda PORT_A
			eor #EN
			sta PORT_A				// DDRAM characted read
		// write to line 1 char that was read in line 2
			lda #%11111111			// Set PORT_B pins for output because we send a command first
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address
			sta PORT_B
			jsr check_busy						
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent
			pla						// Restore line 2 char from stack and write in line 1
			sta PORT_B
			jsr check_busy			
			lda #(RS | 0)			// RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Char sent, cursor moves right
		// write to line 2 char that was read in line 1
			txa
			ora #%11000000			// Set DDRAM Address command ($80) + 7 bits Address + $40
			sta PORT_B
			jsr check_busy			
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent
			pla						// Restore line 1 char from stack and write in line 2
			sta PORT_B
			jsr check_busy						
			lda #(RS | 0)			// RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Char sent, cursor moves right
			inx
			cpx #$10				// 16 chars
			bpl !exit+
			jmp !loop-
!exit:
//!here:		jmp !here-

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++++++++ SCROLLING+ ++++++++++++++  
  			+++++++++++++++++++++++++++++++++++++++*/
scroll_demo:
		// print some data on line 1
			lda #%00000001			// Clear Display
			jsr lcd_instruction
			ldx #1
			jsr delay				// Note: delay **required*** after Clear @ 1 MHz, otherwise first few chars not printed
									// TBH, previous delays looks like not having impact at all (IOW, not needed)
			ldx #$00			
!loop:
			lda line1text_2,x //scroll_text,x
			cmp #$ff 
			beq !exit+	
			jsr lcd_text
			inx
			bne !loop-
!exit:
LCD_scroll_chars:
		// read first char, line 1
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			lda #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			jsr lcd_instruction
			jsr check_busy			// is this needed here?
			lda #%00000000			// Set PORT_B pins for input 
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			lda PORT_B 				// Read leftmost char from DDRAM 1st line and store in Y
			tay
			lda PORT_A				// Strobe EN
			eor #EN
			sta PORT_A				// DDRAM characted read
			ldx #$0f				// start from $0F  = Read rightmost char from DDRAM 1st line
		// begin of loop
!loop:
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			jsr lcd_instruction			
			jsr check_busy
			lda #%00000000			// Set PORT_B pins for input 
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			lda PORT_B 				// Read chars from rightmost to leftmost position and save in stack
			pha
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			jsr lcd_instruction
			tya
			jsr lcd_text			// jsr to lcd_text = code below 
			pla
			tay
			dex
			bpl !loop-
!exit:
			ldx #100
			jsr delay
			jmp LCD_scroll_chars
!here:		jmp !here-

			/*+++++++++++++++++++++++++++++++++++++++
			++++++++ Common subroutines below +++++++  
  			+++++++++++++++++++++++++++++++++++++++*/

// ----- @Send command to LCD @ -----
lcd_instruction:					// strobing done via ORA + EOR
			jsr check_busy
lcd_instruction_no_BF:
			sta PORT_B
			pha						// Save A
			lda #(0 | 0)			// RS LO = select IR; R/!W LO = write
			sta PORT_A
			ora #EN					// Strobe EN to send command in PORT_B to LCD
			sta PORT_A
			eor #EN
			sta PORT_A
			pla						// Restore A
			rts

// ----- @ Send char to LCD @ -----
lcd_text:
			jsr check_busy
			sta	PORT_B				// Store in PORT_B char to be written to LCD
			lda #(RS | 0)			// RS HI (select DR);  R/!W LO (write operation)
			sta PORT_A
			ora #EN					// strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A
			rts

// ----- @ Check Busy Flag @ -----
check_busy:
			pha						// Save command or data sent from main prog to subroutine (lcd_instruction or lcd_text) 
			lda	DDR_B				// Save DDR_B into stack
			pha
			lda #%00000000			// Set PORT_B pins for input in order to read Busy Flag (+ Address Counter, if needed)
			sta DDR_B
BF_busy:
			lda #(0 | RW)			// RS LO = Select IR (cmds or read BF+AC)); R/!W = HI (read operation)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A
			lda #%10000000			// Check PORT_B MSb: bit 7 is Busy Flag state; if 1 then LCD is busy
			bit PORT_B				// Check if MSb (7) is 1 (BIT sets Zero Flag if AND result between PORT_B MSb and %10000000 is true)   
			beq BF_busy				// Compare A and PORT_B MSb (if equal, ZF is set due to no difference, means LCD is busy, hence jump back)
			pla						// Restore DDR_B; it's usually set for output (%11111111) 
			sta DDR_B 
			pla
			rts

// ----- @ Delay (x = # of ms @ clock 1 MHz) @ -----
delay:
			ldy #$00				// 2 cycles
!loop:
			dey						// 2 cycles
			bne !loop-				// 2 cycles (if not crossing page boundary) = 256 * 4 = 1024 cycles = about 1 ms
			dex						// 2 cycles
			bne !loop-				// 2 cycles (if not crossing page boundary)
			rts

helloworld:			
//			.text "|-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --|"
			.text "Hello, world!"
			.byte $ff				
helloworld2:			
			.text "Hello, my world!"
			.byte $ff				
line1text:
			.text "1st line of LCD!"
			.byte $ff
line2text:
			.text "2nd line of LCD!"
			.byte $ff
line1text_2:
			.text "ABCDEFGHIJKLMNO-"
			.byte $ff
line2text_2:
			.text "FEDCBA9876543210"
			.byte $ff
scroll_text:
			.text "o0O@°°@O0o"
			.byte $ff
			
//			.text "Hello, world! This is a long text. Let's see if the routine works by design! EOM "			
//			.text "con lettere lunghe per capire come si comporta il display 5x8 o 5x10? "			

//	this will make a small (1K) .BIN; changing .bytes $FE and $FF values helps check if the programming operation was OK
 			*=$83FE "Kickass assembler log visual verification"
			.byte $23			
			.byte $37

/*	Uncomment to make a 32K ROM
 			*=$fffa			"NMI, Reset, IRQ vectors"
 			.word $0000
			.word reset
 			.word $0000
*/