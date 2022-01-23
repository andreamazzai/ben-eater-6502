// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
// 			Main Program
//----------------------------------------------------
			*=$8000
.encoding	"ascii"
.const		PORT_A = $6001			// Registers control
.const		PORT_B = $6000			// Send commands + send/receive data, check Busy Flag
.const		DDR_A = $6003			// Data Direction Register A controls PORT_A pins; !I/O
.const		DDR_B = $6002			// Data Direction Register B controls PORT_B pins; !I/O
.const		EN = %10000000			// ENable bit
.const		RW = %01000000			// R/!W bit
.const		RS = %00100000			// RS bit
.const		reset = $8000

// Qui il Check Busy lo faccio prima di passare il comando / parametro all'LCD 

// RS = 0	Write command to LCD (Instruction Register, IR) or read Busy Flag and Address
// RS = 1	send/receive data to/from LCD (Data Register, DR)
// R/!W = 0	write operation 
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
			lda #%00111000			// prima si setta il comando: set 8 bit; 2 righe; 5x8
			jsr lcd_instruction

			// jmp no_clear
// ----- @Step 3a Clear display@ -----
			lda #%00000001			// Clear display, Address Counter (AC) = 0 
			jsr lcd_instruction

no_clear:
// ----- @Step 3b Display On Off Control@ -----
			lda #%00001110			// Display On; Curson On; Blink Off 
			jsr lcd_instruction

// ----- @Step 4 Entry Mode Set@ -----
			lda #%00000110			// 1 = Increment/ 0 = Decrement = prossimo carattere, dove lo mettiamo; no scroll
			jsr lcd_instruction

// ----- @Step TMP Display shift@ -----
//			lda #%00011000			// Scroll Display; left
//			sta	PORT_B
//			jsr lcd_instruction
						
// ----- @Step 5 Write Data@ -----
			lda #RS					// abilito registro RS = invio dati e non più istruzioni
			sta	PORT_A

			jmp direct_ddram_write	// per saltare la stampa di "hello world" 

			ldx #$00
print_char:
			lda helloworld,x
			cmp #$ff 
			beq exit			
			jsr lcd_text
			inx
			bne print_char 

exit:	
//			jmp direct_ddram_read
			
scroller:
/*			40 caratteri per riga = $27
			setto comando per fare read address
			leggo dato di primo indirizzo e salvo in PHA
			inizio ciclo da secondo indirizzo
			leggo dato
			scrivo su indirizzo -1
			next fino a che non arrivo a 40° carattere
			passo a seconda riga e ripeto fino a 39° carattere
			PLA e scrivo ultimo carattere */

// ----- @*** PROVIAMO A SCRIVERE ***@ -----
direct_ddram_write:			
			ldx #$00
ram_clean_loop_ddrw:
			lda #$00			
			sta $3000,x
			txa
			sta $3100,x
			inx
			bne ram_clean_loop_ddrw

			ldx #$00
direct_ddram_write_loop:
			txa
			ora #%10000000			// send Set DDRAM Address command + 7b x Address
			sta $3100,x 
			jsr lcd_instruction
			jsr check_busy
			lda #%11111111			// set PORT_B pins for output
			sta DDR_B
			lda #RS					// set RS HI (select DR), R/!W LO (write operation)			
			sta	PORT_A
			lda other_text,x
			cmp #$ff
			beq exit2
			sta PORT_B
			sta $3000,x				// copy here text values
			ora #EN					// strobe EN			
			sta	PORT_A
			eor #EN 
			sta	PORT_A
			inx
			bne direct_ddram_write_loop

/*			
			jsr check_busy
			sta	PORT_B				// store in PORT_B char to be written
			lda #(RS | EN)			// RS HI = select DR; strobe EN
			sta PORT_A
			lda #RS
			sta	PORT_A
*/			
			
exit2:
			jmp exit2

// ----- @*** PROVIAMO A LEGGERE ***@ -----
			ldx #$00
ram_clean:
			txa
			sta $3000,x
			inx
			bne ram_clean
			
direct_ddram_read:
			ldx #$00
direct_ddram_read_loop:
			txa
			ora #%10000000			// send Set DDRAM Address command + 7b x Address
			sta $3100,x				// Scrive X da qualche parte per controllarlo poi
			jsr lcd_instruction
// ----- @Read data from DDRAM@ -----
			jsr check_busy
			lda #%00000000			// set PORT_B pins for input, read from DDRAM
			sta DDR_B
			lda #(RS | RW)			// RS HI (select DR), R/!W HI (read operation)			
			sta	PORT_A
			ora #EN					// strobe EN 
			sta PORT_A
			eor #EN			
			sta	PORT_A			
			lda PORT_B				// read DDRAM value and save it somewhere
			sta $3000,x
			inx
			cpx #$27				// 40 columns
			bmi direct_ddram_read_loop
			
end_loop2:
			jmp end_loop2


// ----- @Invio istruzione a LCD@ -----
lcd_instruction:
			jsr check_busy
			sta PORT_B
			pha						// save A
			lda #$00				// RS LO = select IR; R/!W LO = write
			sta	PORT_A
			lda #EN					// Strobe EN to send command in PORT_B to LCD
			sta PORT_A
			lda #$00
			sta	PORT_A
			pla						// restore A
			rts

// ----- @Invio carattere a LCD@ -----
lcd_text:
			jsr check_busy
			sta	PORT_B				// store in PORT_B char to be written
			lda #(RS | EN)			// RS HI = select DR; strobe EN
			sta PORT_A
			lda #RS
			sta	PORT_A
			rts

check_busy:
			pha						// save into stack the command or data that has been sent from main prog to subroutine (lcd_instruction or lcd_text) 
			lda	DDR_B				// save DDR_B settings into stack
			pha
			lda #%00000000			// set PORT_B pins for input in order to read Busy Flag (also Address Counter, if desired)
			sta DDR_B
BF_busy:
			lda #(0 | RW | EN)		// Set RS LO (IR commands / read BF+AC), R/!W HI (in order to read from the LCD) and strobe EN to exec command			
			sta	PORT_A
			lda #0 
			sta	PORT_A
			lda #%10000000			// must check PORT_B MSb: bit 7 represents Busy Flag state; if 1, then LCD is busy
			bit PORT_B				// checking if MSb (7) is 1 (BIT sets Zero Flag if AND result between PORT_B MSb and %10000000 is true)   
			beq BF_busy				// Compared A and PORT_B (Zero Flag is true because they are Equal), means LCD is busy, hence jump back
			pla						// restore DDR_B from stack
			sta DDR_B 				// Data Direction Register B controlla la direzione di PORT_B; normalmente è sempre output 
			pla
			rts

helloworld:			
			.text "Hello, world!"
//			.text "|-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --|"
//			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe! EOM "			
//			.text "con lettere lunghe per capire come si comporta il display 5x8 o 5x10? "			
			.byte $ff				

other_text:
//			.text "|-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --|"			
//			.text "Hello, my world! "
//			.text "Hello, world! "
			.text "----------------"
//			.text "* Test Text * "
			.byte $ff

//	this will make a small (2K) .BIN; changing .bytes helps check if the programming operation was OK
 			*=$87FE
			.byte $22			
			.byte $29

//	remove the commenting out (//) to make a 32K ROM
// 			*=$fffc
//			.word reset
// 			.word $0000
