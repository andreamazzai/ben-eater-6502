// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
// 			Main Program
//			Questo codice funziona fino a 210 KHz
//----------------------------------------------------
			*=$8000
.encoding	"ascii"
.const		PORT_A = $6001			// la uso per configurare i registri
.const		PORT_B = $6000			// la uso per inviare le istruzioni e i dati
.const		DDR_A = $6003
.const		DDR_B = $6002
.const		EN = %10000000			// ENable bit
.const		RW = %01000000			// R/W| bit
.const		RS = %00100000			// RS bit
.const		reset = $8000

// Qui il Check Busy lo faccio prima di passare il comando / parametro all'LCD 

// RS = 0 Write del comando al display o Read dal diplay di Busy Flag e Address
// RS = 1 stiamo mandando / ricevendo dati al/dal display
// R/W|   se è a 0 sarà una write, se è a 1 sarà una read 

init:
			ldx #$ff
			txs
// ----- @Step 1 Configure 6522@ -----
			lda #%11111111			// set all PORT_B pins for output
			sta DDR_B 				// Data Direction Register B controlla la direzione di PORT_B
			lda #%11100000			// set first three PORT_A pins for output
			sta DDR_A 				// Data Direction Register A controlla la direzione di PORT_A

// ----- @Step 2 Function Set@ -----
			lda #%00111000			// prima si setta il comando: set 8 bit; 2 righe; 5x8
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step 3a Clear Display@ -----
			lda #%00000001			// Clear Display, set DDRAM Address 0 in AC 
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step 3b Display On Off@ -----
			lda #%00001110			// Display On; Curson On; Blink Off 
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step 4 Entry Mode Set@ -----
			lda #%00000110			// 1 = Increment/ 2 = Decrement = prossimo carattere, dove lo mettiamo; no scroll
			sta	PORT_B
			jsr lcd_instruction
						
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
			jmp loop

lcd_instruction:
			jsr check_busy
			lda #0					// clear RS RW EN 
			sta	PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta	PORT_A
			rts

lcd_text:
			jsr check_busy
			sta	PORT_B				// scrive il carattere sulla porta B
			lda #RS					// abilitiamo anche EN = GO per dare il via al comando
			sta PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta	PORT_A
			rts

check_busy:
			pha
			lda #%00000000			// set pins for input per leggere il Busy Flag (e l'Address Counter, se desiderato)
			sta DDR_B 				// Data Direction Register B
BF_busy:
			lda #(0 | RW)
			sta	PORT_A
			ora #EN					// Strobe EN
			sta PORT_A
			eor #EN
			sta	PORT_A
			lda #%10000000			// leggo lo stato della porta B, il cui bit 7 è il Busy Flag; se è a 1 allora l'LCD è busy
			bit PORT_B				// verifico se l'MSb (7) è a 1 (BIT setta Z se il risultato dell'AND del settimo bit è vero)   
			beq BF_busy				// salta se il risultato dell'operazione è zero e dunque il flag Z è 1
			lda #%11111111			// set all PORT_B pins for output
			sta DDR_B 				// Data Direction Register B controlla la direzione di PORT_B
			pla
			rts

helloworld:			
			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe!"			
			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe!"
			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe!"			
			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe!"
			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe!"
			.text "Hello, world! Vediamo se questa volta il meccanismo funziona come dovrebbe!"
			.byte $ff				

//	this will make a small (2K) .BIN; changing .bytes helps check if the programming operation was OK
 			*=$8FFE
			.byte $22			
			.byte $29

//	remove the commenting out (//) in order to make a 32K ROM
// 			*=$fffc
//			.word reset
// 			.word $0000