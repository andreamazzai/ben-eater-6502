// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
// 			Main Program
//----------------------------------------------------
			*=$8000
.encoding	"ascii"
.const		PORT_A = $6001			// si usa per configurare i registri
.const		PORT_B = $6000			// si usa per inviare le istruzioni e i dati, o leggere dati e Busy Flag
.const		DDR_A = $6003			// seleziona il comportamento di PORT_A
.const		DDR_B = $6002			// seleziona il comportamento di PORT_B
.const		EN = %10000000			// ENable bit
.const		RW = %01000000			// R/!W bit
.const		RS = %00100000			// RS bit
.const		reset = $8000

// Qui il Check Busy lo faccio prima di passare il comando / parametro all'LCD 

// RS = 0 Write del comando al display o Read dal diplay di Busy Flag e Address
// RS = 1 stiamo mandando / ricevendo dati al/dal display
// R/!W   se è a 0 sarà una Write, se è a 1 sarà una Read 

init:
			ldx #$ff
			txs
// ----- @Step 1 Configure 6522@ -----
			lda #%11111111			// set all PORT_B pins for output
			sta DDR_B 				// Data Direction Register B controlla la direzione di PORT_B (data, commands, BF)
			lda #%11100000			// set first three PORT_A pins for output
			sta DDR_A 				// Data Direction Register A controlla la direzione di PORT_A (control registers)

// ----- @Step 2 Function Set@ -----
			lda #%00111000			// prima si setta il comando: set 8 bit; 2 righe; 5x8
			sta	PORT_B
			jsr lcd_instruction

			// jmp no_clear
// ----- @Step 3a Clear display@ -----
			lda #%00000001			// Clear display, Address Counter (AC) = 0 
			sta	PORT_B
			jsr lcd_instruction
no_clear:

// ----- @Step 3b Display On Off Control@ -----
			lda #%00001110			// Display On; Curson On; Blink Off 
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step 4 Entry Mode Set@ -----
			lda #%00000110			// 1 = Increment/ 0 = Decrement = prossimo carattere, dove lo mettiamo; no scroll
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step TMP Display shift@ -----
//			lda #%00011000			// Scroll Display; left
//			sta	PORT_B
//			jsr lcd_instruction
						
// ----- @Step 5 Write Data@ -----
			lda #RS					// abilito registro RS = invio dati e non più istruzioni
			sta	PORT_A

			ldx #$00
print_char:
			lda helloworld,x
			cmp #$ff 
			beq loop			
			jsr lcd_text
			inx
			bne print_char 

loop:	
//			jmp loop

scroller:
/*			40 caratteri per riga
			setto comando per fare read address
			leggo dato di primo indirizzo e salvo in PHA
			inizio ciclo da secondo indirizzo
			leggo dato
			scrivo su indirizzo -1
			next fino a che non arrivo a 40° carattere
			passo a seconda riga e ripeto fino a 39° carattere
			PLA e scrivo ultimo carattere
*/

// A = registri, B = DATI COMANDI FLAG

// ----- @Set DDRAM Address@ -----
			lda #%10000001			// Voglio leggere contenuto DDRAM Address 0 (MSb è il comando SET Address e gli altri 7 bit sono l'indirizzo) 
			sta PORT_B
			jsr lcd_instruction
// ----- @Read data from DDRAM@ -----
			jsr check_busy
			lda #%00000000			// set PORT_B pins for input in order to read DDRAM Counter content
			sta DDR_B
			lda #(RS | RW | EN)		// set RS HI (means Data Register operation), R/!W HI (means Read operation) and set EN HI to exec command			
			sta	PORT_A
			lda PORT_B
			sta $3000
			lda #0					// clear RS, R/!W, EN 
			sta	PORT_A
loop2:
			jmp loop2

// ----- @Invio istruzione a LCD@ -----
lcd_instruction:
			jsr check_busy
			pha						// save A
			lda #0					// clear RS R/!W EN 
			sta	PORT_A
			lda #EN					// set EN = 1, passiamo all'LCD il comando presente in PORT_B
			sta PORT_A
			lda #0					// clear RS R/!W EN
			sta	PORT_A
			pla						// restore A
			rts

lcd_text:
			jsr check_busy
			sta	PORT_B				// scrive il carattere sulla porta B
			lda #(RS | EN)			// abilitiamo anche EN = GO per dare il via al comando
			sta PORT_A
			lda #RS 				// disabilito EN
			sta	PORT_A
			rts

check_busy:
			pha						// save into stack command or data that has been sent from main prog to subroutine (lcd_instruction or lcd_text) 
			lda	DDR_B				// save DDR_B settings into stack
			pha
			lda #%00000000			// set PORT_B pins for input in order to read Busy Flag (also Address Counter, if desired)
			sta DDR_B
BF_busy:
			lda #(0 | RW | EN)		// Set RS LO (IR commands / read BF+AC), R/!W HI (in order to read from the LCD) and set EN HI to exec command			
			sta	PORT_A
			lda #0					// clear RS, R/!W, EN 
			sta	PORT_A
			lda #%10000000			// must check PORT_B MSb: bit 7 represents Busy Flag state; if 1, then LCD is busy
			bit PORT_B				// checking if MSb (7) is 1 (BIT sets Zero Flag if AND result between PORT_B MSb and %10000000 is true)   
			beq BF_busy				// Compared A and PORT_B (Zero Flag = true because they are Equal), means LCD is busy, hence jump back
			pla						// restore DDR_B from stack
			sta DDR_B 				// Data Direction Register B controlla la direzione di PORT_B; normalmente è sempre output 
			pla
			rts

helloworld:			
			.text "Hello, world! "
//			.text "|-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --||-- 10 --|"
//			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe! EOM "			
//			.text "con lettere lunghe per capire come si comporta il display 5x8 o 5x10? "			
			.byte $ff				

//	this will make a small (2K) ROM; changing .bytes helps check if the programming operation was OK
 			*=$87FE
			.byte $66			
			.byte $77

//	remove the commenting out (//) to make a 32K ROM
// 			*=$fffc
//			.word reset
// 			.word $0000
