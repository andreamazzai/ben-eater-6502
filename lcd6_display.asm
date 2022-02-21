
// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
//			Code used on Ben Eater's 6502 computer
//----------------------------------------------------
			*=$8000
.encoding	"ascii"
.const		PORT_A	= $6001			// Registers control
.const		PORT_B	= $6000			// Send commands + send/receive data, check Busy Flag
.const		DDR_A	= $6003			// Data Direction Register A controls PORT_A pins; !I/O
.const		DDR_B	= $6002			// Data Direction Register B controls PORT_B pins; !I/O
.const		EN		= %10000000		// ENable bit
.const		RW		= %01000000		// R/!W bit
.const		RS		= %00100000		// RS bit
.const		reset	= $8000

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

// ----- @ TMP code - future reminder to play on Cursor or Display shift@ -----
//			lda #%00011000			// Scroll Display; left
//			sta	PORT_B
//			jsr lcd_instruction
						
// ----- @Step 5 Write Data@ -----
			//lda #RS				// RS = HI select DR
			//sta	PORT_A

	// jmp print_helloworld_exit // Bypass print "hello world" 

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

	// jmp print_scrollertext_prepare
	// jmp LCD_scroll_chars
	// jmp line2_write_exit	
	// jmp end

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++++++++++++++++++++++++++++++++++
			+++++++++ DIRECT WRITE TO LCD +++++++++++  
			+++++++++++++++++++++++++++++++++++++++++
  			+++++++++++++++++++++++++++++++++++++++*/

direct_w:
// ----- @*** DIRECT DDRAM WRITE TO LCD FIRST LINE ***@ -----
direct_w_line1_write:
			lda #%11111111			// Set PORT_B pins for output
			sta DDR_B
			ldx #$00
direct_w_line1_write_loop:
			txa
			ora #%10000000			// Send Set DDRAM Address command ($80) + 7 bits Address (DRAM 1st line starts at 0x00)
			jsr lcd_instruction
			lda line1text,x
			cmp #$ff
			beq direct_w_line1_write_exit
			sta PORT_B				// Output char to PORT_B
			lda #(RS | 0)			// Set RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN			
			sta PORT_A
			eor #EN 
			sta PORT_A
			inx
			bne direct_w_line1_write_loop
direct_w_line1_write_exit:

// ----- @*** DIRECT DDRAM WRITE TO LCD SECOND LINE ***@ -----						
direct_w_line2_write:
			ldx #$00
direct_w_line2_write_loop:
			txa
			ora #%11000000			// Send Set DDRAM Address command ($80) + $40 (DRAM 2nd line starts at 0x40) + 7 bits Address
			jsr lcd_instruction
			lda line2text,x
			cmp #$ff
			beq direct_w_line2_write_exit
			sta PORT_B				// Output char to PORT_B
			lda #(RS | 0)			// Set RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN			
			sta PORT_A
			eor #EN
			sta PORT_A
			inx
			bne direct_w_line2_write_loop
direct_w_line2_write_exit:

	// jmp end // LCD_swap_lines_end
	 
			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++++++++++++++++++++++++++++++++++
			++++ DIRECT WRITE & READ TO/FROM LCD ++++  
			+++++++++++++++++++++++++++++++++++++++++
  			+++++++++++++++++++++++++++++++++++++++*/

	// prepare some RAM; data read from LCD stored here in order to be able to check if meaningful / nonsense
		ldx #$00
		txa
clean_ram_loop:
		sta $1000,x
		inx
		bne clean_ram_loop

direct_rw:
// ----- @ Write in parallel line 1 and 2; also read line 1 or 2 and store in RAM
			ldx #$00
direct_rw_loop:
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
			sta PORT_A				// Command sent
			lda line1text_2,x
			sta PORT_B			
			jsr check_busy			
			lda #(RS | 0)			// RS HI (select DR), R/!W LO (write operation)			
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// char sent line 1

			txa
			ora #%11000000			// Set DDRAM Address command ($80) + 7 bits Address (2nd line starts at 0x40)
			sta PORT_B
			jsr check_busy			
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent line 2
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
			sta PORT_A				// Char sent

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
			jsr check_busy			// ++++ 02-02-2022 check BF fix random blank chars (spaces) issues @ higher frequencies						
			lda #%00000000			// set PORT_B pins for input 
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR); R/!W HI (read operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
	// 31-01-2022 as per datasheet it looks like data can be read also after EN fall to LO (strobe complete) (unsure)
	// actually for me it only works if I read when EN = HI				
	// 04-02-2022: https://hackaday.io/project/174128-db6502/log/181887-amazing-upside-to-sloppy-coding-hd44780-part-2				
	// confirms Read is done when EN = HI				 
			lda PORT_B
			sta $1000,x				// Store DDRAM content in computer RAM
			lda PORT_A
			eor #EN
			sta PORT_A				// DDRAM characted read
			inx
			cpx #$10				// 16 chars
			bpl direct_rw_end
			jmp direct_rw_loop
direct_rw_end:

//		jmp end // LCD_swap_lines_end
//		weird behaviour @ 0.8  MHz... until check_busy added before 

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++++++++++++++++++++++++++++++++++
			++++++++++ SWAP LCD LINE 1 and 2+++++++++  
			+++++++++++++++++++++++++++++++++++++++++
  			+++++++++++++++++++++++++++++++++++++++*/

  			// 01-02-2022 reading messed chars issue. 
  			// 02-02-2022 looks like fixed after check busy added

LCD_swap_lines:
			ldx #$00
LCD_swap_lines_loop:
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

	jsr check_busy // fix messed chars issue			
			
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

	jsr check_busy // fix messed chars issue

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
			bpl LCD_swap_lines_end
			jmp LCD_swap_lines_loop
LCD_swap_lines_end:

			/*+++++++++++++++++++++++++++++++++++++++
			+++++++++++++++++++++++++++++++++++++++++
			++++++++++++++ SCROLL TEST ++++++++++++++  
			+++++++++++++++++++++++++++++++++++++++++
  			+++++++++++++++++++++++++++++++++++++++*/

/*			40 caratteri per riga = $27
			setto comando per fare read address
			leggo dato di primo indirizzo e salvo in PHA
			inizio ciclo da secondo indirizzo
			leggo dato
			scrivo su indirizzo -1
			next fino a che non arrivo a 40° carattere
			passo a seconda riga e ripeto fino a 39° carattere
			PLA e scrivo ultimo carattere */

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
			lda PORT_B 				// Read first char from DDRAM 1st line and store in stack
			pha
			sta $55					// also store in TMP storage			
			lda PORT_A				// Strobe EN
			eor #EN
			sta PORT_A				// DDRAM characted read


			ldx #$0f				// First char read is rightmost on the display, line 1
		// begin of repeatable code
LCD_scroll_lines_loop:
			lda #%11111111			// Set PORT_B pins for output because we send a command first 
			sta DDR_B
			txa
			ora #%10000000			// Set DDRAM Address command ($80) + 7 bits Address			
			jsr lcd_instruction			

/* this is the code that was later substituted with above jsr lcd_instruction			
			sta PORT_B
			jsr check_busy						
			lda #(0 | 0)			// RS LO (select IR); R/!W LO (write operation)
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A				// Command sent
*/
			jsr check_busy			// do I need this?
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
			jmp LCD_scroll_chars
			jmp end

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
			
//			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe! EOM "			
//			.text "con lettere lunghe per capire come si comporta il display 5x8 o 5x10? "			

//	this will make a small (1K) .BIN; changing .bytes helps check if the programming operation was OK
 			*=$83FE
			.byte $22			
			.byte $29

//	remove the commenting out (//) to make a 32K ROM
// 			*=$fffc
//			.word reset
// 			.word $0000
