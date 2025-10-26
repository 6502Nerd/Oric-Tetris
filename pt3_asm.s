#ifndef PT3_ASM_S
#define PT3_ASM_S

; =======================================================================================
; Vortex Tracker II v1.0 PT3 player for 6502
; ORIC 1/ATMOS (6502) version
; ScalexTrixx (A.C) - (c)2018
;
; Translated and adapted from ZX Spectrum Player Code (z80)  
; by S.V.Bulba (with Ivan Roshin for some parts/algorithm)
; https://bulba.untergrund.net/main_e.htm (c)2004,2007 
;
Revision = "0" 
; =======================================================================================
; REV 0: 
; ======
; rev 0.34 (WK/TS)  - correction / 1.773 (288=x256+0x32 -> 289=x256+x32+x01)
;                   => file_end = $8E68
;
; rev 0.33 (WK)     - optimizations: PTDECOD
;                   => file_end = $8E53
;
; rev 0.32 (WK)     - optimizations: PLAY
;                   => file_end = $8F43
;
; rev 0.31 (WK)     - optimizations: CHREGS
;                   => file_end = $8FC4
;
; rev 0.30 (WK)     - New base "full working" version for optimizations
;                   - optimizations: zp variables / CHECKLP / INIT (ALL)
;                   => file_end = $9027
;
; --------------------------------
; WK: working / TS: test version |
; =======================================================================================
; TODO:
; - lda ($AC),y -> lda ($AC,x)
; - NOISE Register opt (/2 ?)
; - déplacer / 1.773 avant CHREGS (cf CPC version) => vraiment utile ?!
; - dans PD_LOOP: vérifier si des jmp relatifs sont possibles
; - fix .bbs address
; - check zero pages addresses
; =======================================================================================
;
;	ORG $8000
;
; -------------------------------------
;        bss

PT3ZP = $b0  ; start of zero page vars (ZP $b0-$ff)
    
SETUP = PT3ZP+0   ; set bit0 to 1, if you want to play without looping
                  ; bit7 is set each time, when loop point is passed
; "registers" Z80
; A = A
; F = flags

z80_A   = PT3ZP+1      ; save A
z80_C   = PT3ZP+2      ; save C
z80_B   = PT3ZP+3      ; save B
z80_E   = PT3ZP+4      ; save E
z80_D   = PT3ZP+5      ; save D
z80_L   = PT3ZP+6      ; save L
z80_H   = PT3ZP+7      ; save H
z80_IX  = PT3ZP+8      ; save IX
z80_AP  = PT3ZP+10     ; save A'
; temp variable used during play
val1    = PT3ZP+11
val2    = PT3ZP+13
val3    = PT3ZP+15
val4    = PT3ZP+17
TA1 = val1
TA2 = val1+1
TB1 = val2
TB2 = val2+1
TC1 = val3
TC2 = val3+1
TB3 = val4
TC3 = val4+1

OricUserIRQ = $0245 ; location of user IRQ vector (low byte)

; =====================================
; module PT3 address
; MDLADDR = $2000
; =====================================
; For dflat, allow build of code using hires screen RAM
; #ifndef USEHIRES
;        *= $7900
; #else
;        *= $9800
; #endif

PT3Counter
  .dsb 2
OldIRQ
  .dsb 2
CurrentPT3IRQ
  jmp $0000

; pt3_init_irq();
; Set IRQ vector to our IRQ handler
_pt3_init_irq
        php
        sei
        ; Put system IRQ vector to our IRQ handler
        lda OricUserIRQ
        sta OldIRQ
        lda OricUserIRQ+1
        sta OldIRQ+1
        ; Put our IRQ handler to system IRQ vector
        lda #<(_pt3_do_irq)
        sta OricUserIRQ
        lda #>(_pt3_do_irq)
        sta OricUserIRQ+1
        ; Initially in mute mode which is just a simple return
        lda #<(MUTERTS)
        sta CurrentPT3IRQ+1
        lda #>(MUTERTS)
        sta CurrentPT3IRQ+2
        plp
        rts

_pt3_do_irq
        pha
        inc PT3Counter
        bne skip_pt3_hi
        inc PT3Counter+1
skip_pt3_hi
        lda #1
        and PT3Counter
        bne skip_pt3_irq
        txa
        pha
        tya
        pha
        ; Call current PT3 IRQ handler
        jsr CurrentPT3IRQ
        pla
        tay
        pla
        tax
skip_pt3_irq
        pla
        jmp (OldIRQ) ; jump to old IRQ handler

_pt3_init
; pt3_init(module_address, no_loop);
; For dflat, assume that A,X provides address of song module, Y is the looping preference (0=loop, 1=no loop)
;        lda #<(MDLADDR)                                               
;        sta z80_L
;        lda #>(MDLADDR)
;        sta z80_H
        php
        sei
        ldy #0
        lda (sp),y
        sta z80_L
        ldy #1
        lda (sp),y
        sta z80_H
        ldy #2
        lda (sp),y
        sta SETUP
        jsr INIT
        jsr _pt3_unmute
        plp
        rts

_pt3_unmute
        php
        sei
        lda #<(PLAY)
        sta CurrentPT3IRQ+1
        lda #>(PLAY)
        sta CurrentPT3IRQ+2
        plp
        rts

_pt3_mute
        php
        sei
        lda #<(MUTERTS)
        sta CurrentPT3IRQ+1
        lda #>(MUTERTS)
        sta CurrentPT3IRQ+2
        jsr MUTE
        plp
MUTERTS
        rts


CrPsPtr	.word 0 ; current position in PT3 module

;Identifier
	    .byt "=VTII PT3 Player r.",Revision,"="

CHECKLP
	                                                
        lda SETUP                                                   
        ora #%10000000                                              
        sta SETUP
	lda #%00000001                                                                                               
        bit SETUP
        bne s1                                                      
	rts
s1	pla                                                         
        pla       ; dépile 2 fois puisque rts shunté
	inc DelyCnt                                                                                                                                    
        inc ANtSkCn                                                 
MUTE	                                                            
        lda #00                                                     
        sta z80_H                                                   
	sta z80_L                                                   
	sta AYREGS+AmplA                                            
	sta AYREGS+AmplB                                            
        sta AYREGS+AmplC
	jmp ROUT                                              

INIT

	lda z80_L                                                   
	sta MODADDR+1
        sta MDADDR2+1
        sta z80_IX
        pha
        lda z80_H
        sta MODADDR+7
        sta MDADDR2+7
        sta z80_IX+1
        pha
        lda #<(100)                                                   
        sta z80_E
        lda #00
        sta z80_D
        tay
	clc                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H
        lda (z80_L),y                                               
	sta Delay+1                                                                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        sta CrPsPtr                                                 
        lda z80_H
        adc #00
        sta z80_H    
        sta CrPsPtr+1
	ldy #102               
        lda (z80_IX),y
        sta z80_E
	clc                                                         
        adc z80_L
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H       
	inc z80_L                                                   
        bne s2
        inc z80_H
s2	lda z80_L                                                   
        sta LPosPtr+1
        lda z80_H
        sta LPosPtr+5
	pla                                                         
        sta z80_D
        pla
        sta z80_E
	ldy #103               
        lda (z80_IX),y
	clc                                                         
        adc z80_E
        sta PatsPtr+1   
        ldy #104                  
        lda (z80_IX),y
        adc z80_D
        sta PatsPtr+8
        lda #<(169)                                                   
        clc                                                         
        adc z80_E
        sta OrnPtrs+1   
        lda #00
        adc z80_D
        sta OrnPtrs+8
        lda #<(105)                                                   
        clc                                                         
        adc z80_E
        sta SamPtrs+1
        lda #00
        ;INIT zeroes from VARS to VAR0END-1 (area < $80)           
        ldy #(VAR0END-VARS-1)
LOOP_LDIR 
        sta VARS,y
        dey         ; (carry not modified)
        bpl LOOP_LDIR
        ; A = #00  
        adc z80_D
        sta SamPtrs+8                                        
        lda SETUP                                                   
        and #%01111111
        sta SETUP
        
	lda #<(T1_)
        sta z80_E
        lda #>(T1_)
        sta z80_D
        lda #$01                                   
	sta DelyCnt                                                                                                  
        sta ANtSkCn
        sta BNtSkCn
        sta CNtSkCn
        lda #$F0
	sta AVolume                                                 
	sta BVolume                                                 
	sta CVolume                                                 
        lda #<(EMPTYSAMORN)                                           
        sta z80_L
        sta AdInPtA+1
        sta AOrnPtr
        sta BOrnPtr
        sta COrnPtr
        sta ASamPtr
        sta BSamPtr
        sta CSamPtr
        lda #>(EMPTYSAMORN)
        sta z80_H
	sta AdInPtA+5                                               
	sta AOrnPtr+1                                               
	sta BOrnPtr+1                                               
	sta COrnPtr+1                                               
	sta ASamPtr+1                                               
	sta BSamPtr+1                                               
	sta CSamPtr+1                                               
	    			                                                
        
	ldy #13                    
        lda (z80_IX),y
        sec                                                         
        sbc #$30        ; ascii value - 30 = version number (1-7)
	bcc L20         ; inverse (pour SUB aussi)                  
	cmp #10                                                     
	bcc L21         ; < 10                                      
L20	    
        lda #6          ; version par defaut si incorrect           
L21	    
        sta Version+1                                               
	pha             ; save version nb
        cmp #4          ; version 4 ?                               
        bcc s7b         ; < 4 (inverse carry)
        clc
        bcc s8b         ; always
s7b     sec
s8b     ldy #99                 
        lda (z80_IX),y  
        rol            ; carry !                                   
	and #7          ; clear all bit except 0-1-2                
        tax             ; save A
;NoteTableCreator (c) Ivan Roshin
;A - NoteTableNumber*2+VersionForNoteTable
;(xx1b - 3.xx..3.4r, xx0b - 3.4x..3.6x..VTII1.0)

     	lda #<(NT_DATA)											    
     	sta z80_L
     	lda #>(NT_DATA)
     	sta z80_H
     	lda z80_E													
     	sta z80_C
     	lda z80_D
     	sta z80_B
     	lda #00
        tay           ; ldy #00	        
     	sta z80_D
     	txa           ; restore A									
     	asl 															
     	sta z80_E													
     	clc                                                         
        adc z80_L
        sta z80_L
        lda z80_D
        adc z80_H
        sta z80_H													
     	lda (z80_L),y												
     	sta z80_E
     	inc z80_L                                                   
        bne s9b
        inc z80_H
s9b 
	lsr z80_E											    				     				
	bcs sb		; si c = 0 => $EA (NOP) / si c = 1 => $18 (clc)
sa  	lda #$EA 	; -> $EA (NOP)
        bne sb1		; always	
sb	lda #$18	; -> $18 (clc) 									
sb1	sta L3		            									
	lda z80_E													
	ldx z80_L
	sta z80_L
	stx z80_E
	lda z80_D
	ldx z80_H
	sta z80_H
	stx z80_D
	clc                                                         
    	lda z80_C
    	adc z80_L
    	sta z80_L
    	lda z80_B
    	adc z80_H
    	sta z80_H

	lda (z80_E),y												
	clc                                                         
        adc #<(T_)
	sta z80_C
        pha                                                   
        adc #>(T_)                                                    
	sec                                                         
        sbc z80_C
        sta z80_B                                                   												
	pha

	lda #<(NT_)											
	sta z80_E
	pha															
	lda #>(NT_)
	sta z80_D
	pha
	lda #12														
	sta z80_B
L1	    
        lda z80_C													
	pha
	lda z80_B
	pha
	lda (z80_L),y												
	sta z80_C
	inc z80_L                                                   
        bne sc
        inc z80_H
sc     
	lda z80_L												    
	pha
	lda z80_H
	pha
	lda (z80_L),y												
	sta z80_B

	lda z80_E       												
	sta z80_L
        pha
	lda z80_D
	sta z80_H
        pha
	lda #<(23)		    										
	sta z80_E
	lda #>(23)
	sta z80_D
	lda #8														
	sta z80_IX+1
        
L2	    
        lsr z80_B													
	ror z80_C													
L3	    
	.byt $AC			; clc ($18) or NOP ($EA)
	lda z80_C													
	adc #00  		    								    	
	sta (z80_L),y												
	inc z80_L                                                   
        bne sd
        inc z80_H
sd      
        lda z80_B													
	adc #00 													
	sta (z80_L),y												
	clc                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        lda z80_D
        adc z80_H
        sta z80_H
	dec z80_IX+1											    
	bne L2														

	pla															
	sta z80_D
	pla         
        adc #02     
        sta z80_E   
        bcc sf      
        inc z80_D 

sf     
	pla												    	    
	sta z80_H
	pla
	sta z80_L
	inc z80_L                                                   
        bne sg
        inc z80_H
sg     
	pla												    	    
	sta z80_B
	pla
	sta z80_C
	dec z80_B													
	beq sg1
        jmp L1
sg1        
	pla															
	sta z80_H
	pla
	sta z80_L
	pla															
	sta z80_D
	pla
	sta z80_E
        								
	cmp #<(TCOLD_1)		        								
        bne CORR_1													
	lda #$FD													
	sta NT_+$2E									 				

CORR_1	
        clc                                                         
        lda (z80_E),y																										
	beq TC_EXIT													
	ror 															
	php			    ; save carry														
	asl 															
	sta z80_C													
	clc                                                         
        adc z80_L
        sta z80_L
        lda z80_B
        adc z80_H
        sta z80_H                                
	plp             ; restore carry (du ror)	                
	bcc CORR_2                                                  
	lda (z80_L),y												
	sec															
	sbc #$02
	sta (z80_L),y
	
CORR_2	
        lda (z80_L),y												
	clc			
	adc #$01
	sta (z80_L),y
        sec   		                                                
	lda z80_L                                                   
	sbc z80_C
	sta z80_L
	lda z80_H
	sbc z80_B
	sta z80_H
	inc z80_E                                                   
        bne sh
        inc z80_D
sh     
	jmp CORR_1												    

TC_EXIT
	pla			; restore version number						

;VolTableCreator (c) Ivan Roshin
;A - VersionForVolumeTable (0..4 - 3.xx..3.4x;
;5.. - 3.5x..3.6x..VTII1.0)

	cmp #5		; version 										
	lda #<($11)                                                   
	sta z80_L
        lda #>($11)													
	sta z80_H													
	sta z80_D                                                   
	sta z80_E													
	lda #$2A	; ($2A = rol A)								    
	bcs M1		; CP -> carry inverse (CP 5)					
	dec z80_L													
	lda z80_L													
	sta z80_E
	lda #$EA	; ($EA = NOP)			    					
M1          
        sta M2														
	lda #<(VT_+16)												
	sta z80_IX
	lda #>(VT_+16)
	sta z80_IX+1
	lda #$10													
	sta z80_C

INITV2  
        clc
        lda z80_L													
	pha
        adc z80_E
        sta z80_E
	lda z80_H
	pha
        adc z80_D
        sta z80_D
	    
        lda #00														
	sta z80_L
	sta z80_H
        clc
INITV1  
        lda z80_L													
M2          
        .byt $AC	    ; $EA (nop) ou $2A (rol)
	lda z80_H													
	adc #00			; + carry                                  	
	sta (z80_IX),y												
	inc z80_IX                                                  
        bne si
        inc z80_IX+1
si     
	clc                                                         
        lda z80_E
        adc z80_L
        sta z80_L
        lda z80_D
        adc z80_H
        sta z80_H
	inc z80_C												    
	lda z80_C													
	and #15														
        clc         ; carry cleared by and
	bne INITV1													

	pla															
	sta z80_H
	pla
	sta z80_L
	lda z80_E													
	cmp #$77													
	bne M3														
	inc z80_E													
M3      
        clc                                                         
        lda z80_C																								
	bne	INITV2													

	jmp ROUT													
; ==============================================================================================
; Pattern Decoder
PD_OrSm	
        ldy #Env_En     										    
	lda #00
	sta (z80_IX),y
	jsr SETORN													
	ldy #00					; lda ($AC,x)									
	lda (z80_C),y
	inc z80_C                                                   
        bne sj
        inc z80_B
sj     
	lsr 													    
        bcc sj1
        ora #$80
sj1     
PD_SAM	
        asl  											    		
PD_SAM_	
        sta z80_E													
SamPtrs		
	lda #$AC				
        clc
        adc z80_E
	sta z80_L
	lda #$AC
        adc #00
	sta z80_H

        ldy #00
	lda (z80_L),y
MODADDR		
	adc #$AC												
	tax             ; save
	iny                                                         
	lda (z80_L),y
        adc #$AC								    			

	ldy #SamPtr+1         										
	sta (z80_IX),y
	dey															
	txa         
	sta (z80_IX),y
	jmp PD_LOOP													

PD_VOL	
        asl 															
        adc #00
	asl 															
        adc #00
	asl 															
        adc #00
	asl 															
        adc #00
	ldy #Volume         										
	sta (z80_IX),y
        jmp PD_LP2													
	
PD_EOff	
        ldy #Env_En		    	        							
	sta (z80_IX),y
	ldy #PsInOr   			    					    		
	sta (z80_IX),y
	jmp PD_LP2													

PD_SorE	
        sec															
	sbc #01
        sta z80_A
	bne PD_ENV													
	ldy #00			        ; lda ($AC,x)												
	lda (z80_C),y
	inc z80_C                                                   
        bne sl
        inc z80_B
sl     
	ldy #NNtSkp    		        								
	sta (z80_IX),y
        jmp PD_LP2													

PD_ENV	
        jsr SETENV													
	jmp PD_LP2													

PD_ORN	
        jsr SETORN													
	jmp PD_LOOP													

PD_ESAM	
        ldy #Env_En	             									
	sta (z80_IX),y
	ldy #PsInOr	    		        							
	sta (z80_IX),y
	lda z80_A           
        beq sm														
	jsr SETENV
sm	ldy #00			    ; lda ($AC,x)												
	lda (z80_C),y
	inc z80_C                                                   
        bne sn
        inc z80_B
sn     
        jmp PD_SAM_								     			    

PTDECOD 
        ldy #Note   							    				
	lda (z80_IX),y
	sta PrNote+1												
	ldy #CrTnSl    		    						    		
	lda (z80_IX),y                                              
	sta PrSlide+1												
        iny 
	lda (z80_IX),y											
	sta PrSlide+8

PD_LOOP	
        lda #$10													
	sta z80_E
	
PD_LP2	
        ldy #00			    ; lda ($AC,x)												
	lda (z80_C),y
	inc z80_C                                                   
        bne so
        inc z80_B
so
	clc															
	adc #$10
	bcc so1
        sta z80_A            
        jmp PD_OrSm
so1     adc #$20                                                    
	bne so11													
        jmp PD_FIN
so11	bcc so2													    
        jmp PD_SAM
so2	adc #$10                                                    
	beq PD_REL													
	bcc so3 													
        jmp PD_VOL
so3	adc #$10                                                    
	bne so4										    			
        jmp PD_EOff
so4	bcc	so5												    	
	jmp PD_SorE
so5     adc #96                                                     
	bcs PD_NOTE													
	adc #$10                                                    
	bcc so6
        sta z80_A												    	
        jmp PD_ORN													
so6	adc #$20                                                    
	bcs PD_NOIS													 														
	adc #$10                                                    
        bcc so7
        sta z80_A												    	
        jmp PD_ESAM
so7	asl 															
	sta z80_E
        clc                                                   
        adc #<(SPCCOMS+$FF20)							        
        sta z80_L
	lda #>(SPCCOMS+$FF20)
        adc #00
	sta z80_H
        ; on doit inverser le PUSH car l'adresse sera utilisée après rts
        ldy #01	
	lda (z80_L),y												
	pha             ; push D
	dey                                                         
	lda (z80_L),y										        
	pha             ; push E
	jmp PD_LOOP													

PD_NOIS									
        sta Ns_Base                                                 
	jmp PD_LP2													

PD_REL	
        ldy #Flags   								    			
	lda (z80_IX),y
	and #%11111110
	sta (z80_IX),y
	jmp PD_RES													
	
PD_NOTE	
        ldy #Note    	 				    						
	sta (z80_IX),y	
	ldy #Flags      											
	lda (z80_IX),y
	ora #%00000001
	sta (z80_IX),y
	    													
PD_RES												
        lda #00	
        sta z80_L
	sta z80_H
	ldy #11
bres
	sta (z80_IX),y          
	dey
        bpl bres
PD_FIN	
	ldy #NNtSkp     						    				
	lda (z80_IX),y
	ldy #NtSkCn     		    								
	sta (z80_IX),y
	rts 														

C_PORTM
	ldy #Flags  												
	lda (z80_IX),y
	and #%11111011
	sta (z80_IX),y
	ldy #00			    ; lda ($AC,x)												
	lda (z80_C),y
        ldy #TnSlDl     				    			    		
	sta (z80_IX),y
        ldy #TSlCnt	        			    						
	sta (z80_IX),y

        clc
        lda z80_C
        adc #03
        sta z80_C
        bcc st
        inc z80_B
st     
	lda #<(NT_)			; OPT										
	sta z80_E
	lda #>(NT_)           ; OPT
	sta z80_D
	ldy #Note	        										
	lda (z80_IX),y
	ldy #SlToNt         										
	sta (z80_IX),y
	asl 																																																				
	clc                                                         
        adc z80_E           ; OPT
        sta z80_L
        lda z80_D           ; OPT
        adc #00           
        sta z80_H
        ldy #00	
	lda (z80_L),y 												
	pha	
	iny                                                         
	lda (z80_L),y 												
	pha
PrNote	
        lda #$3E													
	ldy #Note   					    						
	sta (z80_IX),y
	asl 																																			
	clc                                                         
        adc z80_E           ; OPT
        sta z80_L
        lda z80_D           ; OPT
        adc #00
        sta z80_H
	ldy #00
        lda (z80_L),y												
	sta z80_E
	iny                                                         
	lda (z80_L),y											    
	sta z80_D
	ldy #TnDelt 
        pla															
	sta z80_H
	pla       
	sec                                                                                                       
        sbc z80_E
        sta z80_L
        sta (z80_IX),y
        lda z80_H
        sbc z80_D
        sta z80_H 
        iny                                                         
        sta (z80_IX),y
	ldy #CrTnSl                                                 
        lda (z80_IX),y
        sta z80_E
	iny                                                         
        lda (z80_IX),y
        sta z80_D
Version
	lda #$3E                                                    
	cmp #6                                                      
	bcc OLDPRTM     ; < 6
        ldy #CrTnSl                                       
PrSlide	
        lda #$AC                                                    
        sta z80_E
        sta (z80_IX),y
        iny
        lda #$AC
        sta z80_D
        sta (z80_IX),y
	                                                  
OLDPRTM	
        ldy #00                                                     
        lda (z80_C),y
        iny                                                                                                                        
        sta z80_AP                                                  
	lda (z80_C),y                                               
	sta z80_A
        lda z80_C
        clc
        adc #02
        sta z80_C
        bcc sw
        inc z80_B
sw
	lda z80_A                                                   
	beq NOSIG                                                   
	lda z80_E													
	ldx z80_L
	sta z80_L
	stx z80_E
	lda z80_D
	ldx z80_H
	sta z80_H
	stx z80_D
NOSIG	
        sec                            
        lda z80_L
        sbc z80_E
        sta z80_L
        lda z80_H
        sbc z80_D
        sta z80_H
	bpl SET_STP                                                 
	lda z80_A                                                   
        eor #$FF                                                    
        ldx z80_AP                                                  
        sta z80_AP
        txa
	eor #$FF                                                    
        clc             
        adc #01                                                
        tax                                                         
        lda z80_AP
        stx z80_AP
        sta z80_A
SET_STP	
        ldy #(TSlStp+1)                                             
        lda z80_A
        sta (z80_IX),y                                              
        tax                                                         
        lda z80_AP
        stx z80_AP
        sta z80_A
	    dey                       
        sta (z80_IX),y
        ldy #COnOff                                                 
        lda #00
        sta (z80_IX),y
	rts                                                         

C_GLISS	
        ldy #Flags       											
	lda (z80_IX),y
	ora #%00000100
	sta (z80_IX),y
	ldy #00                 ; lda ($AC,x)	                                    
        lda (z80_C),y
        sta z80_A
        inc z80_C                                                   
        bne sy
        inc z80_B
sy     
	ldy #TnSlDl                                                 
        sta (z80_IX),y
	clc                                                         
        lda z80_A                                                   
	bne GL36                                                    
	lda Version+1                                               
	cmp #7                                                      
	bcs sz                                                      
        lda #00         ; si A < 7  , A = 0 ($FF+1)                 
        beq saa
sz      lda #01         ; si A >= 7 , A = 1 ($00+1)
saa	    
GL36	
        ldy #TSlCnt                                                 
	sta (z80_IX),y                                              
        ldy #00                                                     
        lda (z80_C),y
        sta z80_AP
        iny
        lda (z80_C),y
        sta z80_A
        clc
        lda z80_C
        adc #02
        sta z80_C                                                   
        bcc sac
        inc z80_B
sac     
	jmp SET_STP                                                 

C_SMPOS	
        ldy #00                  ; lda ($AC,x)	                                   
        lda (z80_C),y
        inc z80_C                                                   
        bne sad
        inc z80_B
sad     
	ldy #PsInSm                                                 
        sta (z80_IX),y
	rts                                                         

C_ORPOS	
        ldy #00                 ; lda ($AC,x)	                                              
        lda (z80_C),y
        inc z80_C                                                   
        bne sae
        inc z80_B
sae     
	ldy #PsInOr                                                 
        sta (z80_IX),y
	rts                                                         
    
C_VIBRT	
        ldy #00                 ; lda ($AC,x)	                                             
        lda (z80_C),y
        inc z80_C                                                   
        bne saf
        inc z80_B
saf     
	ldy #OnOffD                                                 
        sta (z80_IX),y
        ldy #COnOff                                                 
        sta (z80_IX),y
	ldy #00                 ; lda ($AC,x)	                                          
        lda (z80_C),y
        inc z80_C                                                   
        bne sag
        inc z80_B
sag     ldy #OffOnD                                                 
        sta (z80_IX),y
        lda #00                                                     
        ldy #TSlCnt                                                 
        sta (z80_IX),y
	ldy #CrTnSl                                                 
        sta (z80_IX),y
	iny                                                         
        sta (z80_IX),y
	rts                                                         

C_ENGLS	
        ldy #00                                                     
        lda (z80_C),y
        sta Env_Del+1                                               
	sta CurEDel
        iny
        lda (z80_C),y
        sta z80_L                                                   
        sta ESldAdd+1
        iny
        lda (z80_C),y
        sta z80_H                                                   
	sta ESldAdd+9
        clc
        lda z80_C 
        adc #03
        sta z80_C
        bcc sah
        inc z80_B
sah	                                                   
	rts                                                              

C_DELAY	
        ldy #00                 ; lda ($AC,x)	                                         
        lda (z80_C),y
        inc z80_C                                                   
        bne sak
        inc z80_B
sak
	sta Delay+1                                                 
	rts                                                         

SETENV	
        ldy #Env_En                                                 
        lda z80_E
        sta (z80_IX),y
        lda z80_A                ; OPT (inverser et mettre sta AYREGS+EnvTP au début)                                   
        sta AYREGS+EnvTp
	ldy #00                                                     
        lda (z80_C),y           
	sta z80_H                                                   
        sta EnvBase+1                                               
	iny                                                     
        lda (z80_C),y
	sta z80_L                                                   
	sta EnvBase
        lda z80_C
        clc
        adc #02
        sta z80_C
        bcc sam
        inc z80_B                                                 
sam	lda #00                                                     
	ldy #PsInOr                                                 
        sta (z80_IX),y
	sta CurEDel                                                 
	sta z80_H                                                   
        sta CurESld+1                                               
	sta z80_L                                                   
        sta z80_A
	sta CurESld                                                 
C_NOP	
        rts                                                         

SETORN	
        lda z80_A
        asl                                                          
	sta z80_E                                                   
	lda #00             ; OPT (inutile ?)                                             
        sta z80_D
	ldy #PsInOr                                                 
        sta (z80_IX),y
OrnPtrs
	    lda #$AC           
        clc
        adc z80_E                                           
        sta z80_L
        lda #$AC
        adc #00
        sta z80_H
	ldy #00                                                     
        lda (z80_L),y
MDADDR2
	adc #$AC
        tax             ; save
	iny                                                         
	lda (z80_L),y
        adc #$AC                                               
	    
	ldy #OrnPtr+1                                                 
        sta (z80_IX),y
        dey
	txa                                                   
        sta (z80_IX),y
	rts                                                              

;ALL 16 ADDRESSES TO PROTECT FROM BROKEN PT3 MODULES
SPCCOMS 
        .word C_NOP-1
	.word C_GLISS-1
	.word C_PORTM-1
	.word C_SMPOS-1
	.word C_ORPOS-1
	.word C_VIBRT-1
	.word C_NOP-1
	.word C_NOP-1
	.word C_ENGLS-1
	.word C_DELAY-1
	.word C_NOP-1
	.word C_NOP-1
	.word C_NOP-1
	.word C_NOP-1
	.word C_NOP-1
	.word C_NOP-1
; ==============================================================================================
CHREGS	
        lda #00                                                  
	    sta z80_A       ; save
        sta Ampl                                                 
	    lda z80_L                                            
        sta val3                                                 
        lda z80_H
        sta val3+1
        ldy #Flags                                               
        lda #%00000001
        sta val1
        lda (z80_IX),y
        bit val1
	    bne saq
        jmp CH_EXIT                                              
saq     	
                                                                 
	    ldy #OrnPtr                                              
        lda (z80_IX),y
        sta z80_L
        sta val1            ; save L
        iny                                                      
        lda (z80_IX),y
        sta z80_H
        sta val1+1          ; save H
	                                                             
        ldy #00
        lda (z80_L),y                                            
        sta z80_E
        iny
        lda (z80_L),y
        sta z80_D
	    ldy #PsInOr                                              
        lda (z80_IX),y
	    sta z80_L                                                
        sta z80_A                                        
	    clc
        lda val1
        adc z80_L
        sta z80_L
        lda val1+1
        adc #00                
        sta z80_H                                               
        lda z80_L
        adc #02
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H
        lda z80_A                                                
        adc #01
        cmp z80_D                                                
	    bcc CH_ORPS                                              
	    clc
        lda z80_E                                                
CH_ORPS	
        ldy #PsInOr                                              
        sta (z80_IX),y
	    ldy #Note                                                
        lda (z80_IX),y
	    ldy #00                                                  
        adc (z80_L),y       ; adc ($AC,x)	
	    bpl CH_NTP                                               
	    lda #00                                                  
CH_NTP	
        cmp #96                                                  
	    bcc CH_NOK                                               
	    lda #95                                                  
CH_NOK	
        asl                                                      
        sta z80_AP                                               
	    ldy #SamPtr                                              
        lda (z80_IX),y
        sta z80_L
	    sta val1            ; save L
        iny                                                      
        lda (z80_IX),y
        sta z80_H
        sta val1+1          ; save H
	    ldy #00
        lda (z80_L),y                                            
        sta z80_E   
        iny
        lda (z80_L),y
        sta z80_D   

	    ldy #PsInSm                                              
        lda (z80_IX),y
	    sta z80_B                                                
	    asl                                                       
	    asl                                                       
	    sta z80_L                                                                                           
        clc
        adc val1
        sta z80_L
        lda val1+1
        adc #00
        sta z80_H                                                     
        lda z80_L
        adc #02
        sta z80_L
        lda z80_H
        adc #00
        sta z80_H

	    lda z80_B                                                                                                      
        adc #01
	    cmp z80_D                                                
	    bcc CH_SMPS                                              
	    lda z80_E                                                
CH_SMPS	
        ldy #PsInSm                                              
        sta (z80_IX),y
        ldy #00
        lda (z80_L),y                                            
        sta z80_C
        iny
        lda (z80_L),y
        sta z80_B

        ldy #TnAcc                                               
        lda (z80_IX),y
        sta z80_E
        iny
        lda (z80_IX),y
	    sta z80_D                                                
	    clc                                                      
        ldy #02
        lda (z80_L),y                                            
        adc z80_E
        tax
        iny
        lda (z80_L),y
        adc z80_D
        sta z80_H
        sta z80_D
        txa
        sta z80_L
        sta z80_E

        lda #%01000000                                           
        bit z80_B
	    beq CH_NOAC                                              
	    ldy #TnAcc                                               
        lda z80_L
        sta (z80_IX),y
	    iny                                                      
        lda z80_H
        sta (z80_IX),y
CH_NOAC 												             
        lda z80_AP                                               
        sta z80_A                                                
        sta z80_L                                                
        clc
        lda #<(NT_)
        adc z80_L
        sta z80_L
        lda #>(NT_)
        adc #00
        sta z80_H
        ldy #00
        lda (z80_L),y                                            
        adc z80_E
        tax
        iny
        lda (z80_L),y
        adc z80_D                                               
        sta z80_H
        txa
        sta z80_L
        clc
	    ldy #CrTnSl                                              
        lda (z80_IX),y
        sta z80_E
        adc z80_L
        sta z80_L
	    sta val3
        iny                                                      
        lda (z80_IX),y
        sta z80_D
        adc z80_H
        sta z80_H
        sta val3+1
;CSP_	    
	   
        lda #00                                                  
	    ldy #TSlCnt                                              
        ora (z80_IX),y
	    sta z80_A
        bne saq1                                                 
        jmp CH_AMP
saq1	lda (z80_IX),y                                           
        sec
        sbc #01
        sta (z80_IX),y
	    bne CH_AMP                                               
	    ldy #TnSlDl                                              
        lda (z80_IX),y
        ldy #TSlCnt                                              
        sta (z80_IX),y
	    clc
        ldy #TSlStp                                              
        lda (z80_IX),y
        adc z80_E
        sta z80_L
	    iny                                                      
        lda (z80_IX),y
        adc z80_D
        sta z80_H 
	    sta z80_A       ; save                                   
	    ldy #CrTnSl+1                                              
        sta (z80_IX),y
        dey                                                
        lda z80_L
        sta (z80_IX),y
	    lda #%00000100                                           
        sta val1
        ldy #Flags
        lda (z80_IX),y
        bit val1
	    bne CH_AMP  	                                         
	    ldy #TnDelt                                              
        lda (z80_IX),y
        sta z80_E
	    iny                                                      
        lda (z80_IX),y
        sta z80_D
	lda z80_A                                                
	beq CH_STPP                                              
	lda z80_E												
	ldx z80_L
	sta z80_L
	stx z80_E
	lda z80_D
	ldx z80_H
	sta z80_H
	stx z80_D
CH_STPP
        sec           ; carry = 0 becoze And A                   
        lda z80_L
        sbc z80_E
        sta z80_L
        lda z80_H
        sbc z80_D
        sta z80_H
        bmi CH_AMP                                               
	ldy #SlToNt                                              
        lda (z80_IX),y
	ldy #Note                                                
        sta (z80_IX),y
	lda #00                                                  
	ldy #TSlCnt                                              
        sta (z80_IX),y
	ldy #CrTnSl                                              
        sta (z80_IX),y
        iny                                                      
        sta (z80_IX),y

CH_AMP	
        ldy #CrAmSl                                              
        lda (z80_IX),y
	    sta z80_A       ; save
        lda #%10000000                                           
        bit z80_C
	    beq CH_NOAM                                              
	    lda #%01000000                                           
        bit z80_C
	    beq CH_AMIN                                              
	    lda z80_A                                                
        cmp #15
	    beq CH_NOAM                                              
	    clc                                                      
        adc #01
	    jmp CH_SVAM                                              
CH_AMIN	
        lda z80_A                                                
        cmp #$F1            ; -15
	    beq CH_NOAM                                              
	    sec                                                      
        sbc #01
CH_SVAM	
        ldy #CrAmSl                                              
        sta (z80_IX),y
        sta z80_A
CH_NOAM	
        lda z80_A
        sta z80_L                                                
	    lda z80_B                                                
	    and #15                                                  
	    clc                                                      
        adc z80_L
	    bpl CH_APOS                                              
	    lda #00                                                  
CH_APOS	
        cmp #16                                                  
	    bcc CH_VOL                                               
	    lda #15                                                  
CH_VOL	
        ldy #Volume                                              
        ora (z80_IX),y
	    sta z80_L
        clc                                                
	lda #<(VT_)                                                
        sta z80_E
        adc z80_L
        sta z80_L
        lda #>(VT_)
        sta z80_D
        adc #00
        sta z80_H
	    ldy #00                                                  
        lda (z80_L),y       ; lda ($AC,x)	
        sta z80_A       ; save
CH_ENV	
        lda #%00000001                                           
        bit z80_C
	    bne CH_NOEN                                              
	    ldy #Env_En                                              
        lda z80_A
        ora (z80_IX),y
        sta z80_A

CH_NOEN	
        lda z80_A
        sta Ampl                                                 
        lda z80_C                                                
        sta z80_A
        lda #%10000000                                           
        bit z80_B
	    beq NO_ENSL                                              
        lda z80_A
        rol                                                  
	    rol
	    cmp #$80                                                 
        ror
	    cmp #$80                                                 
        ror
	    cmp #$80                                                 
        ror
	    ldy #CrEnSl                                              
        clc
        adc (z80_IX),y
        sta z80_A
        lda #%00100000                                           
        bit z80_B
	    beq NO_ENAC                                              
	    ldy #CrEnSl                                              
        lda z80_A
        sta (z80_IX),y
NO_ENAC	
        lda #<(AddToEn+1)       ; OPT ?                                    
        sta z80_L
        lda #>(AddToEn+1)
        sta z80_H
        lda z80_A
        ldy #00                                                  
		                                                         
        clc
        adc (z80_L),y           ; OPT ?
        sta (z80_L),y                                            
	    jmp CH_MIX                                               
NO_ENSL 
        lda z80_A
        ror                                                       
	    ldy #CrNsSl                                              
        clc
        adc (z80_IX),y
	    sta AddToNs                                              
        sta z80_A       ; save
	    lda #%00100000                                           
        bit z80_B
	    beq CH_MIX                                               
	    ldy #CrNsSl                                              
        lda z80_A
        sta (z80_IX),y
CH_MIX	
        lda z80_B                                                
	    ror                                                       
	    and #$48                                                 
        sta z80_A
CH_EXIT	
        lda #<(AYREGS+Mixer)                                     
        sta z80_L
        lda #>(AYREGS+Mixer)
        sta z80_H
	    lda z80_A
        ldy #00                                                  
        ora (z80_L),y       ; ora ($AC,x)	
	    lsr                                                       
        bcc saq2
        ora #$80
saq2	sta (z80_L),y                                            
	    lda val3+1                                               
        sta z80_H
        lda val3 
        sta z80_L
	    lda #00                                                  
	    ldy #COnOff                                              
        ora (z80_IX),y
	    sta z80_A       ; save
        bne sas                                                  
        rts
sas 	ldy #COnOff                                              
        lda (z80_IX),y
        sec
        sbc #01
        sta (z80_IX),y
	    beq sat                                                  
        rts
sat 	ldy #Flags                                               
        lda z80_A
        eor (z80_IX),y                                           
        sta (z80_IX),y                                           
	    ror                                                       
	    ldy #OnOffD                                              
        lda (z80_IX),y
	    bcs CH_ONDL                                              
	    ldy #OffOnD                                              
        lda (z80_IX),y
CH_ONDL	
        ldy #COnOff                                              
        sta (z80_IX),y
        rts                                                         
; ==============================================================================================
PLAY    
        lda #00                                                  
	    sta AddToEn+1                                            
	    sta AYREGS+Mixer                                         
	    lda #$FF                                                 
	    sta AYREGS+EnvTp                                         
	    dec DelyCnt                                              
	    beq sat1                                                 
        jmp PL2
sat1	dec ANtSkCn                                              
	    beq sat2                                                 
        jmp PL1B
AdInPtA
sat2	lda #01                                                  
        sta z80_C
        lda #01
        sta z80_B
	    ldy #00                                                                                                      
        lda (z80_C),y       ; lda ($AC,x)	                                      
	    beq sat3            ; test 0                                                
        jmp PL1A
sat3	sta z80_D                                                
	    sta Ns_Base                                              
	    lda CrPsPtr                                              
        sta z80_L
        lda CrPsPtr+1
        sta z80_H
	    inc z80_L                                                
        bne sar
        inc z80_H
sar                                                     
        lda (z80_L),y                                            
	    clc                                                      
        adc #01
        sta z80_A
        bne PLNLP                                                
	    jsr CHECKLP                                              
LPosPtr
	    lda #$AC                                                 
        sta z80_L
        lda #$AC
        sta z80_H
	    ldy #00                 ; OPT ?                                           
        lda (z80_L),y       ; lda ($AC,x)	                                     
	    clc                                                      
        adc #01
        sta z80_A           ; save
PLNLP	
        lda z80_L                                                
        sta CrPsPtr
        lda z80_H
        sta CrPsPtr+1
	    lda z80_A                                                
        sec
        sbc #01
	    asl                                                       
	    sta z80_E                                                
        sta z80_A
	    rol z80_D                                                
PatsPtr
	    lda #$AC
        clc
        adc z80_E                                                  
        sta z80_L
        lda #$AC
        adc z80_D
        sta z80_H
	    
	    lda MODADDR+1                                            
        sta z80_E
        lda MODADDR+7
        sta z80_D
                       	                                                             
	    ldy #00                 ; OPT ?
        lda (z80_L),y           ; lda ($AC,x)	                                 
        clc                                                      
        adc z80_E               ; OPT (adc MODADDR+1)
        sta z80_C
        iny
        lda (z80_L),y
        adc z80_D               ; OPT (adc MODADDR+7)
        sta z80_B   
        iny
        lda (z80_L),y                                            
        clc                     ; OPT ?
        adc z80_E               ; IDEM...
        sta AdInPtB+1   
        iny
        lda (z80_L),y
        adc z80_D
        sta AdInPtB+5     
        iny
        lda (z80_L),y                                            
        clc
        adc z80_E               ; IDEM
        sta AdInPtC+1   
        iny
        lda (z80_L),y
        adc z80_D
        sta AdInPtC+5
                                                 
PSP_	

PL1A	
        lda #<(ChanA)                                              
        sta z80_IX
        lda #>(ChanA)
        sta z80_IX+1
	jsr PTDECOD                                              
	lda z80_C                                                
        sta AdInPtA+1
        lda z80_B
        sta AdInPtA+5

PL1B	
        dec BNtSkCn                                              
	bne PL1C                                                 
	lda #<(ChanB)                                              
        sta z80_IX
        lda #>(ChanB)
        sta z80_IX+1
AdInPtB
	lda #01                                                  
        sta z80_C
        lda #01
        sta z80_B
	jsr PTDECOD                                              
	lda z80_C                                                
        sta AdInPtB+1
        lda z80_B
        sta AdInPtB+5

PL1C	
        dec CNtSkCn                                              
	bne PL1D                                                 
	lda #<(ChanC)                                              
        sta z80_IX
        lda #>(ChanC)
        sta z80_IX+1
AdInPtC
	lda #01                                                  
        sta z80_C
        lda #01
        sta z80_B
	jsr PTDECOD                                              
	lda z80_C                                                
        sta AdInPtC+1
        lda z80_B
        sta AdInPtC+5

Delay
PL1D	
        lda #$3E                                                 
	    sta DelyCnt                                              

PL2	
        lda #<(ChanA)                                              
        sta z80_IX
        lda #>(ChanA)
        sta z80_IX+1
	    lda AYREGS+TonA                                          
        sta z80_L
        lda AYREGS+TonA+1
        sta z80_H
	    jsr CHREGS                                               
	    lda z80_L                                                
        sta AYREGS+TonA
        lda z80_H
        sta AYREGS+TonA+1
	    lda Ampl                                                 
	    sta AYREGS+AmplA                                         
	
        lda #<(ChanB)                                              
        sta z80_IX
        lda #>(ChanB)
        sta z80_IX+1
	    lda AYREGS+TonB                                          
        sta z80_L
        lda AYREGS+TonB+1
        sta z80_H
	    jsr CHREGS                                               
	    lda z80_L                                                
        sta AYREGS+TonB
        lda z80_H
        sta AYREGS+TonB+1
	    lda Ampl                                                 
	    sta AYREGS+AmplB                                         
	    
        lda #<(ChanC)                                              
        sta z80_IX
        lda #>(ChanC)
        sta z80_IX+1
	    lda AYREGS+TonC                                          
        sta z80_L
        lda AYREGS+TonC+1
        sta z80_H
	    jsr CHREGS                                               
	    lda z80_L                                                
        sta AYREGS+TonC
        lda z80_H
        sta AYREGS+TonC+1

	    lda Ns_Base_AddToNs                                      
        sta z80_L
        lda Ns_Base_AddToNs+1
        sta z80_H                                              
	    clc                                                      
        adc z80_L
	    sta AYREGS+Noise                                         

AddToEn
	    lda #$3E                                                 
	    sta z80_E                                                
	    asl                                                       
	    bcc sau                                                  
        lda #$FF
        bne sau1      ; always
sau     lda #00
sau1	sta z80_D                                                
        lda EnvBase+1
        sta z80_H           ; OPT ?
        lda EnvBase                                              
        sta z80_L           ; OPT ?
	    clc                                                      
        adc z80_E
        sta z80_L
        lda z80_D
        adc z80_H           ; OPT ?
        sta z80_H 
        lda CurESld+1
        sta z80_D
        lda CurESld                                              
        sta z80_E
	    clc                                                      
        adc z80_L
        sta AYREGS+Env                                           
        lda z80_D
        adc z80_H
	    sta AYREGS+Env+1                                         

        lda #00                                                  
        ora CurEDel         ; OPT ?                                       
	    beq ROUT                                                 
	    dec CurEDel                                              
	    bne ROUT                                                 
Env_Del
	    lda #$3E                                                 
	    sta CurEDel                                              
ESldAdd
	    lda #$AC                                                 
        clc
        adc z80_E       
        sta CurESld
        lda #$AC
        adc z80_D
	    sta CurESld+1                                             
; ==============================================================================================
; ORIC 1/ATMOS VIA addresses:
;VIA_PCR = $30C
VIA_ORA = $30F
; Values for the PCR register - always enable CB1 active edge (bit 4)
SND_SELREAD		= %11011111		; CB2=low, CA2=high
SND_SELWRITE		= %11111101		; CB2=high, CA2=low
SND_SELSETADDR		= %11111111		; CB2=high, CA2=high
SND_DESELECT		= %11011101		; CB2=low,CA2=low
ROUT
        ldx AYREGS+1    ; hi ToneA
        lda AYREGS+0    ; lo ToneA
        jsr FIX16BITS
        
        lda #00             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        sty VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #01             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        stx VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR
        
        ldx AYREGS+3    ; hi ToneA
        lda AYREGS+2    ; lo ToneA
        jsr FIX16BITS 

        lda #02             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        sty VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #03             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        stx VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        ldx AYREGS+5    ; hi ToneA
        lda AYREGS+4    ; lo ToneA
        jsr FIX16BITS 

        lda #04             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        sty VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #05             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        stx VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #06             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda AYREGS+6    ; data
        ;jsr FIX8BITS
        lsr              ; /2 
        sta VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #07
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda AYREGS+7    ; data
        ora #$40                ; dflat needsb AY port A enabled for output             
        sta VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #08             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda AYREGS+8    ; data
        sta VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #09             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda AYREGS+9    ; data
        sta VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #10             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda AYREGS+10   ; data
        sta VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        ldx AYREGS+12   ; hi Env
        lda AYREGS+11   ; lo Env
        jsr FIX16BITS 

        lda #11             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        sty VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        lda #12             
        sta VIA_ORA     ; register number
        lda #SND_SELSETADDR        ; fct: SET PSG REG#
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        stx VIA_ORA
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR

        ; shunte R13 si $FF (Y=13) => plus généralement >=$80
        lda AYREGS+13
        bpl OUT_S
        rts
OUT_S   ldy #13
        sty VIA_ORA     ; 
        ldy #SND_SELSETADDR        ; fct: SET PSG REG#
        sty VIA_PCR
        ldy #SND_DESELECT        ; fct: INACTIVE
        sty VIA_PCR

        sta VIA_ORA     ; a = data
        lda #SND_SELWRITE        ; fct: WRITE DATA
        sta VIA_PCR
        lda #SND_DESELECT        ; fct: INACTIVE
        sta VIA_PCR
        rts
; -------------------------------------
FIX16BITS       ; INT(256*2*1000/1773) = 289 = 256 + 32 + 1
                ; IN:  register A is low byte
                ;      register X is high byte
                ; OUT: register Y is low byte
                ;      register X is high byte

        ; x256
        stx TA1
        sta TB1
        stx TB2
        sta TC2
        stx TB3
        sta TC3
        lda #00
        sta TA2
        
        ; x32
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        asl TC2
        rol TB2
        rol TA2
        
        ; x32 + x01
        clc
        lda TC3
        adc TC2
        ; sta TC2
        lda TB3
        adc TB2
        sta TB2
        lda TA2
        adc #00
        sta TA2

        ; + x256 
        clc         
        lda TB2
        adc TB1
        tay         ; sta TB1
        lda TA2
        adc TA1
        ; sta TA1

        ; / 2 (16bits)
        lsr          ; lsr TA1
        tax         ; ldx TA1
        tya         ; lda TB1     
        ror          ; ror TB1
        tay         ; ldy TB1
        rts 

; =============================================================================
NT_DATA	
        .byt (T_NEW_0-T1_)*2
	    .byt TCNEW_0-T_
	    .byt (T_OLD_0-T1_)*2+1
	    .byt TCOLD_0-T_
	    .byt (T_NEW_1-T1_)*2+1
	    .byt TCNEW_1-T_
	    .byt (T_OLD_1-T1_)*2+1
	    .byt TCOLD_1-T_
	    .byt (T_NEW_2-T1_)*2
	    .byt TCNEW_2-T_
	    .byt (T_OLD_2-T1_)*2
	    .byt TCOLD_2-T_
	    .byt (T_NEW_3-T1_)*2
	    .byt TCNEW_3-T_
	    .byt (T_OLD_3-T1_)*2
	    .byt TCOLD_3-T_

T_

TCOLD_0	.byt $00+1,$04+1,$08+1,$0A+1,$0C+1,$0E+1,$12+1,$14+1
	    .byt $18+1,$24+1,$3C+1,0
TCOLD_1	.byt $5C+1,0
TCOLD_2	.byt $30+1,$36+1,$4C+1,$52+1,$5E+1,$70+1,$82,$8C,$9C
	    .byt $9E,$A0,$A6,$A8,$AA,$AC,$AE,$AE,0
TCNEW_3	.byt $56+1
TCOLD_3	.byt $1E+1,$22+1,$24+1,$28+1,$2C+1,$2E+1,$32+1,$BE+1,0
TCNEW_0	.byt $1C+1,$20+1,$22+1,$26+1,$2A+1,$2C+1,$30+1,$54+1
	    .byt $BC+1,$BE+1,0
TCNEW_1 = TCOLD_1
TCNEW_2	.byt $1A+1,$20+1,$24+1,$28+1,$2A+1,$3A+1,$4C+1,$5E+1
	    .byt $BA+1,$BC+1,$BE+1,0

EMPTYSAMORN = *-1
	    .byt 1,0,$90 ;delete #90 if you don't need default sample

;first 12 values of tone tables

T1_ 	
        .word $1DF0
        .word $1C20
        .word $1AC0
        .word $1900
        .word $17B0
        .word $1650
        .word $1510
        .word $13E0

        .word $12C0
        .word $11C0
        .word $10B0
        .word $0FC0
        .word $1A7C
        .word $1900
        .word $1798
        .word $1644

        .word $1504
        .word $13D8
        .word $12B8
        .word $11AC
        .word $10B0
        .word $0FC0
        .word $0EDC
        .word $0E08

        .word $19B4
        .word $1844
        .word $16E6
        .word $159E
        .word $1466
        .word $1342
        .word $122E
        .word $1128

        .word $1032
        .word $0F48
        .word $0E6E
        .word $0D9E
        .word $0CDA
        .word $1A20
        .word $18AA
        .word $1748

        .word $15F8
        .word $14BE
        .word $1394
        .word $127A
        .word $1170
        .word $1076
        .word $0F8A
        .word $0EAA

        .word $0DD8

T_OLD_1	= T1_
T_OLD_2	= T_OLD_1+24
T_OLD_3	= T_OLD_2+24
T_OLD_0	= T_OLD_3+2
T_NEW_0	= T_OLD_0
T_NEW_1	= T_OLD_1
T_NEW_2	= T_NEW_0+24
T_NEW_3	= T_OLD_3

FILE_END =*
; ===========================

;.bss        ; uninitialized data stuff

;vars from here can be stripped
;you can move VARS to any other address

VARS
;ChannelsVars

; STRUCT "CHP"
PsInOr	= 0
PsInSm	= 1
CrAmSl  = 2
CrNsSl	= 3
CrEnSl	= 4
TSlCnt	= 5
CrTnSl	= 6
TnAcc	= 8
COnOff	= 10
OnOffD	= 11
OffOnD	= 12
OrnPtr	= 13
SamPtr	= 15
NNtSkp	= 17
Note	= 18
SlToNt	= 19
Env_En	= 20
Flags	= 21
TnSlDl	= 22
TSlStp	= 23
TnDelt	= 25
NtSkCn	= 27
Volume	= 28
; end STRUCT

; CHANNEL A
ChanA	
;reset group
APsInOr	.byt 0
APsInSm	.byt 0
ACrAmSl	.byt 0
ACrNsSl	.byt 0
ACrEnSl	.byt 0
ATSlCnt	.byt 0
ACrTnSl	.word 0
ATnAcc	.word 0
ACOnOff	.byt 0
;reset group

AOnOffD	.byt 0

AOffOnD	.byt 0
AOrnPtr	.word 0
ASamPtr	.word 0
ANNtSkp	.byt 0
ANote	.byt 0
ASlToNt	.byt 0
AEnv_En	.byt 0
AFlags	.byt 0
 ;Enabled - 0,SimpleGliss - 2
ATnSlDl	.byt 0
ATSlStp	.word 0
ATnDelt	.word 0
ANtSkCn	.byt 0
AVolume	.byt 0
	
; CHANNEL B
ChanB
;reset group
BPsInOr	.byt 0
BPsInSm	.byt 0
BCrAmSl	.byt 0
BCrNsSl	.byt 0
BCrEnSl	.byt 0
BTSlCnt	.byt 0
BCrTnSl	.word 0
BTnAcc	.word 0
BCOnOff	.byt 0
;reset group

BOnOffD	.byt 0

BOffOnD	.byt 0
BOrnPtr	.word 0
BSamPtr	.word 0
BNNtSkp	.byt 0
BNote	.byt 0
BSlToNt	.byt 0
BEnv_En	.byt 0
BFlags	.byt 0
 ;Enabled - 0,SimpleGliss - 2
BTnSlDl	.byt 0
BTSlStp	.word 0
BTnDelt	.word 0
BNtSkCn	.byt 0
BVolume	.byt 0

; CHANNEL C
ChanC
;reset group
CPsInOr	.byt 0
CPsInSm	.byt 0
CCrAmSl	.byt 0
CCrNsSl	.byt 0
CCrEnSl	.byt 0
CTSlCnt	.byt 0
CCrTnSl	.word 0
CTnAcc	.word 0
CCOnOff	.byt 0
;reset group

COnOffD	.byt 0

COffOnD	.byt 0
COrnPtr	.word 0
CSamPtr	.word 0
CNNtSkp	.byt 0
CNote	.byt 0
CSlToNt	.byt 0
CEnv_En	.byt 0
CFlags	.byt 0
 ;Enabled - 0,SimpleGliss - 2
CTnSlDl	.byt 0
CTSlStp	.word 0
CTnDelt	.word 0
CNtSkCn	.byt 0
CVolume	.byt 0

; ------------

;GlobalVars
DelyCnt	.byt 0
CurESld	.word 0
CurEDel	.byt 0
Ns_Base_AddToNs
Ns_Base	.byt 0
AddToNs	.byt 0

; ===========================
AYREGS ; AY registers

TonA	= 0
TonB	= 2
TonC	= 4
Noise	= 6
Mixer	= 7
AmplA	= 8
AmplB	= 9
AmplC	= 10
Env	    = 11
EnvTp	= 13
; ---

Ampl	= AYREGS+AmplC
; ===========================
VT_	.dsb 256 ;CreatedVolumeTableAddress

EnvBase	= VT_+14
VAR0END	= VT_+16 ;INIT zeroes from VARS to VAR0END-1

; ===========================
NT_	.dsb 192 ;CreatedNoteTableAddress

VARS_END = *

#endif
