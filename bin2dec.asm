
// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
//			Code used on Ben Eater's 6502 computer
//			Divide algorithm https://www.youtube.com/watch?v=v3-a-zqKfgA 
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
.const		value			= $0200	// working location for number to be converted
.const		mod_n			= $0202	// working location for modulo
.const		output_string	= $0204	// storage for converted string (6 bytes)


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

			jmp main_bin2mod

			// number; mod; quotient; remainder

number:		.word 64738
modulo:		.word 10				// this program can print any Number in basis_10 to the corresponding number in basis_modulo

main_bin2mod:
			lda number				// number to be converted	
			sta value
			lda number +1
			sta value +1
			lda #$00				// initialize string
			sta output_string
main_loop:
			lda #$00				// initialize remainder
			sta mod_n
			sta mod_n +1	
			clc

			ldx #$10				// 16 ROLs
div_loop:
			rol value				// rotate quotient and remainder
			rol value +1
			rol mod_n
			rol mod_n +1
			sec						// a, y = dividend - divisor
			lda mod_n
			sbc modulo
			tay						// save low byte
			lda mod_n +1			// unnecessary if mod = 1 byte
			sbc modulo +1
			bcc ignore_result		// if dividend < divisor we do not use carry, hence move subtraction result to modulo locations
			sty mod_n
			sta mod_n +1
			
ignore_result:			
			dex
			bne div_loop

			rol value
			rol value +1

			lda mod_n
			clc
			adc #'0'
			jsr build_string
			lda value				// if any remainder exist, move to next loop
			ora value +1
			bne main_loop

print_output_string:
			ldx #$00
print_output_string_loop:
			lda output_string,x
			cmp #$00
			beq print_output_string_exit	
			jsr lcd_text
			inx
			bne print_output_string_loop
print_output_string_exit:

end:
			jmp end

	// data is received from LSB to MSB; need to create a string and shift bytes "from left to right"
	// for every char pushed to string, must shift bytes until we find "0" value (init output_string)
build_string:
			ldy #$00
			pha						// save new char into stack ++
build_string_loop:
			lda output_string,y		// read char in existing message and save to X
			tax
			pla						// get char from stack (if Y=0 then ++, otherwise the one read in previuos cycle **) 
			sta output_string,y		// store in string
			iny
			txa
			pha						// save char read to stack ** 
			// cmp #$00
			bne build_string_loop	// if not a null char, then loop
			pla						// get last char and store to string
			sta output_string,y
			rts

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
			pha						// added 27-02-2022 because sometimes I forget that A is not restored  
			sta	PORT_B				// Store in PORT_B the char to be written to LCD
			lda #(RS | 0)			// RS HI (select DR);  R/!W LO (write operation)
			sta PORT_A
			ora #EN					// strobe EN
			sta PORT_A
			eor #EN
			sta PORT_A
			pla
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
			.text "Hello, world!"
			.byte $ff				

//	this will make a small (1K) .BIN
 			*=$83FE
			.byte $21				// I verify the contect of last two bytes in the log pane to see if write to EEPROM was OK
			.byte $54

//	remove the commenting out (//) to make a 32K ROM
// 			*=$fffc
//			.word reset
// 			.word $0000