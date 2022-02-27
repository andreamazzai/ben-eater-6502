


//----------------------------------------------------
//			Code used on Ben Eater's 6502 computer
// 			Short version used to debug 65C02 Tool
//----------------------------------------------------
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
		// era  8000

// Check Busy done before sending command / data to LCD 

// RS = 0	Write command to LCD (Instruction Register, IR) or read Busy Flag and Address
// RS = 1	Send/receive data to/from LCD (Data Register, DR)
// R/!W = 1	read operation

init:
			ldx #$ff
			txs
// ----- @Step 1 Configure 6522@ -----
			lda #%11111111			// set all PORT_B pins for output
			sta DDR_B
			lda #%11100000			// set first three PORT_A pins for output
			sta DDR_A 				// 

// ----- @Step 2 Function Set@ -----
			lda #%00111000			// set 8 bits; 2 lines; 5x8
			jsr lcd_instruction

	//		jmp no_clear
// ----- @Step 3a Clear display@ -----
			lda #%00000001			// Clear display, set Address Counter (AC) = 0 
			jsr lcd_instruction
no_clear:

// ----- @Step 3b Display On Off Control@ -----
			lda #%00001110			// Display On; Curson On; Blink Off
			lda #%00001111			// Display On; Curson On; Blink Off !!!!!!! BLINK ON !!!!!!!			
			jsr lcd_instruction

// ----- @Step 4 Entry Mode Set@ -----
			lda #%00000110			// Set cursor move direction HI Increment / LO Decrement; no display shift
			jsr lcd_instruction

begin_delay:
// X = 1 / Y = 255 is ok for 1.1 MHz "print_helloworld"; otherwise weird behavior
// X = 2 / Y = 255 is ok for 2 MHz "print_helloworld"
// X = 3 / Y = 255 is ok for 2.66 MHz "print_helloworld"; not for "lcd_coding"

		jmp begin_delay_loop_exit
			ldx #$3
			ldy #$ff
begin_delay_loop:
			dey
			bne begin_delay_loop
			dex
			bne begin_delay_loop
begin_delay_loop_exit:		


print_scrollertext_prepare:
		// print some data on line 1
			ldx #$00
print_scrollertext_loop:
			lda line1text_2,x
			cmp #$ff 
			beq print_scrollertext_exit	
			jsr lcd_text
			inx
			bne print_scrollertext_loop
print_scrollertext_exit:

LCD_scroll_chars:
		// read first char, line 1
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			lda #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			jsr lcd_instruction			

			lda #%00000000			// Set PORT_B pins for input 
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			lda PORT_B 				// Read char from DDRAM 1st line and store in stack
			pha
			sta $55					// TMP storage			
			lda PORT_A
			eor #EN
			sta PORT_A				// DDRAM characted read

		// begin of repeatable code
			ldx #$0f				// First char read is rightmost on the display, line 1
LCD_scroll_lines_loop:
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
			lda PORT_B 				// Read char and save in stack
			pha

			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			jsr lcd_instruction			

			lda $55					// Read char from TMP storage			
			sta PORT_B
			jsr check_busy						
			lda #(RS | 0)			// RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Char sent, cursor moves right

			pla
			sta $55

			dex
			bpl LCD_scroll_lines_loop
LCD_scroll_lines_end:

end:
			// jmp LCD_scroll_chars
			brk // jmp end

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++++++++++++++++++++++++++++++++++
			++ Common subroutines from here onward ++  
			+++++++++++++++++++++++++++++++++++++++++
  			+++++++++++++++++++++++++++++++++++++++*/

// ----- @Send command to LCD@ -----
lcd_instruction:					// strobing by ORA + EOR
			jsr check_busy
			sta PORT_B
 // I think pha and pla are unnecessary here 
			pha						// Save A
			lda #(0 | 0)			// RS LO = select IR; R/!W LO = write
			sta PORT_A
			ora #EN					// Strobe EN to send command in PORT_B to LCD
			sta PORT_A
			eor #EN
			sta PORT_A 				// *********** cursore si muove verso sinistra  / home *********** WTFIT
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
			lda #%00000000			// Set PORT_B pins for input in order to read Busy Flag (also Address Counter, if desired)
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

line1text_2:
			.text "ABCDEFGHIJKLMNOP"
			.byte $ff
line2text_2:
			.text "FEDCBA9876543210"
			.byte $ff

//	$83FE will make a small (1K) .BIN; changing .bytes helps check if the programming operation was OK
 			*=$8FFE
			.byte $15
			.byte $50

//	remove the commenting out (//) to make a 32K ROM
// 			*=$fffc "Reset vector"
//			.word reset
// 			.word $0000
