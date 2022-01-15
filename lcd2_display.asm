// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
// 			Main Program
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

// qui non ci sono controlli sui timing, dunque funziona solo a frequenze basse (no 1 MHz)

// con RS = 0 Write istruzione al display o read Busy Flag e Address
// con RS = 1 stiamo mandando / ricevendo dati al/dal display
// R/W|  se è a 0 sarà una write, se è a 1 sarà una read 

init:
			ldx #$ff
			txs
// ----- @Step 1 Configure 6522@ -----
			lda #%11111111			// Set all pins for output
			sta DDR_B 				// Data Direction Register B
			lda #%11100000			// Set first three pins for output
			sta DDR_A 				// Data Direction Register A

// ----- @Step 2 Function Set@ -----
			lda #%00111000			// Prima si setta il comando: set 8 bit; 2 righe; 5x8
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step 3 Display On Off@ -----
			lda #%00001110			// Display On; Curson On; Blink Off 
			sta	PORT_B
			jsr lcd_instruction

// ----- @Step 4 Entry Mode Set@ -----
			lda #%00000110			// 1 = Increment/ 2 = Decrement = prossimo carattere, dove lo mettiamo; no scroll
			sta	PORT_B
			jsr lcd_instruction
						
// ----- @Step 5 Write Data@ -----
			lda #RS					// Abilito registro RS = invio dati e non più istruzioni
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
			lda #0					// Clear RS RW EN 
			sta	PORT_A
			lda #EN					// Abilitiamo EN = GO per il comando
			sta PORT_A
			lda #0					// Clear RS RW EN 
			sta	PORT_A
			rts

lcd_text:
			sta	PORT_B
			lda #(RS | EN)			// Abilitiamo anche EN = GO per il comando
			sta PORT_A
			lda #RS 				// Disabilito EN
			sta	PORT_A
			rts

helloworld:			
			.text "Hello, world!"			
			.byte $ff				
							
			*=$fffc
			.word reset
			.word $0000
