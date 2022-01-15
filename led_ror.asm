// start=$8000 (for Kick Assembler) 

//----------------------------------------------------
// 			Main Program
//----------------------------------------------------
			*=$8000

mainProg: 	{						// <- Here we define a scope
			lda #$ff
			sta $6002				// Data Direction Register B
}

			lda #$50
			sta $6000

loop1:		{			
			ror $6000
			jmp loop1
}

			*=$fffc
			.byte $00, $80, $00, $00