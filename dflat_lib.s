#ifndef DFLAT_LIB_S
#define DFLAT_LIB_S

#include "pt3_asm.s"

;
; This is a simple display module
; called by the C part of the program
;
; PT3 player is needed for the IRQ handler which has a counter used for delay timers


;
; Various useful addresses
;
#define TEXTADDRESS $BB80
#define HIRESADDRESS $a000
#define TEXTCHAR $b400
#define HIRESCHAR $9800

#define screenAddr $00
#define screenPixMode $02
#define screenMask $03
#define screenTmp $04

#define screenMode $21f

; Text address tables
textAddrLow
	.dsb 28
textAddrHigh
	.dsb 28

; Hires address tables
hiresAddrLow
	.dsb 200
hiresAddrHigh
	.dsb 200

; HIres x coord to column offset
hiresColumn
	.dsb 240
; HIres x coord to pixel mask
hires_mask
	.dsb 240

; Call this routine to initialise the graphics system
_gr_init
	; Do text table
	lda #$80
	sta textAddrLow
	lda #$bb
	sta textAddrHigh
	ldx #1
textTableInit
	clc
	lda textAddrLow-1,x
	adc #40
	sta textAddrLow,X
	lda textAddrHigh-1,x
	adc #0
	sta textAddrHigh,X
	inx
	cpx #28
	bne textTableInit

	; Do hires table
	lda #$00
	sta hiresAddrLow
	lda #$a0
	sta hiresAddrHigh
	ldx #1
hiresTableInit
	clc
	lda hiresAddrLow-1,x
	adc #40
	sta hiresAddrLow,X
	lda hiresAddrHigh-1,x
	adc #0
	sta hiresAddrHigh,X
	inx
	cpx #200
	bne hiresTableInit

	; Do hires column table
	; Each text column is 6 pixels wide
	lda #0
	ldx #0
	ldy #0
columnTableInit
	sta hiresColumn,X
	iny
	cpy #6
	bcc columnTableInit_skip
	adc #0
	ldy #0
columnTableInit_skip
	inx
	cpx #240
	bne columnTableInit

	; Do hires mask table
	lda #$20
	ldx #0
maskTableInit
	sta hires_mask,X
	lsr
	bne maskTableInit_skip
	lda #$20
maskTableInit_skip
	inx
	cpx #240
	bne maskTableInit

	lda #1
	sta screenPixMode	; Default to OR mode
	rts

; Set the pixmode
_gr_pixmode
	ldy #0
	lda (sp),y				; Access pixmode parameter
	sta screenPixMode
	rts

;
; The message and display position will be read from the stack.
; sp+0 => X coordinate
; sp+2 => Y coordinate
; sp+4 => Adress of the message to display
;
_gr_plot
	; Check if in hires mode
	lda screenMode
	bne _gr_hplot

	; In text mode
_gr_tplot	
	ldy #2
	lda (sp),y				; Access Y coordinate
	tax
	lda screenMode
	beq tplot_skip_hires
	; If in hires then adjust Y by 25
	txa
	clc
	adc #25
	tax
tplot_skip_hires	
	lda textAddrLow,x		; Get the LOW part of the screen adress
	clc						; Clear the carry (because we will do an addition after)
	ldy #0
	adc (sp),y				; Add X coordinate
	sta write+1
	sta plot_single_text_char+1
	lda textAddrHigh,x		; Get the HIGH part of the screen adress
	adc #0					; Eventually add the carry to complete the 16 bits addition
	sta write+2				
	sta plot_single_text_char+2

	ldy #4
	lda (sp),y
	sta read+1
	iny
	lda (sp),y
	sta read+2
	beq single_text_char	; If high byte is zero then only one char to plot
	; Start at the first character
	ldx #0
loop_char
	; Read the character, exit if it's a 0
read
	lda $0123,x
	beq end_loop_char
	; Write the character on screen
write
	sta $0123,x
	; Next character, and loop
	inx
	bne loop_char  
	; Finished !
end_loop_char
	rts
single_text_char
	lda read+1
plot_single_text_char
	sta $0123
	rts
	

; gr_hplot
; Plot character to hires X,Y coordinates with char code A
;
; sp+0 => X coordinate
; sp+2 => Y coordinate
; sp+4 => char code
;
_gr_hplot
	ldy #2
	lda (sp),y				; Access Y coordinate
	pha
	ldy #0
	lda (sp),y				; Access X coordinate
	pha
	ldy #4
	lda (sp),y				; Access char pointer
	sta tmp1
	iny
	lda (sp),y
	sta tmp1+1
	pla
	tax
	pla
	tay
	; Now X in X, Y in Y, char code in A
	; If pointer high is zero then it's a direct char code
	lda tmp1+1
	bne gr_hchar_ptr
	lda tmp1
	jmp gr_hchar
gr_hchar_ptr
	stx tmp2
	sty tmp2+1
	ldy #0
	sty gr_hchar_ptr_loop+1
gr_hchar_ptr_loop
	ldy #$ff
	lda (tmp1),y
	beq gr_hchar_ptr_done
	inc gr_hchar_ptr_loop+1
	ldx tmp2
	ldy tmp2+1
	jsr gr_hchar
	clc
	lda tmp2
	adc #6
	sta tmp2
	bcc gr_hchar_ptr_loop
gr_hchar_ptr_done
	rts


;****************************************
;* gr_hattr
;* Plot bytecode at hires X,Y coordinates with attribute A
;* Input : X,Y = coord, A = attribute code
;* Output : None
;* Regs affected : None
;****************************************
gr_hattr
	sta tmp0
	; Set up destination position tmpalo,hi and Y
	jsr gr_point_setup
	ldx #8				; Always do 8 rows like a character
gr_hcode_loop
	lda tmp0			; Get the code to place
	sta (screenAddr),y	; Store it in destination
	clc
	lda screenAddr			; Update base pointer to next row
	adc #40
	sta screenAddr
	lda screenAddr+1
	adc #0
	sta screenAddr+1
	dex
	bne gr_hcode_loop
	rts


; X,Y coord A=char code
gr_hchar
	; Check char code an attribute
	cmp #31
	bcc gr_hattr
	; Multiply char code by 8
	; and add to char font base
	; tmp_clo contains base address
	asl
	rol tmp0+1
	asl
	rol tmp0+1
	asl
	rol tmp0+1
	clc
	adc #<HIRESCHAR
	sta tmp0
	lda tmp0+1
	and #7
	adc #>HIRESCHAR
	sta tmp0+1

	; Set up destination position
	jsr gr_point_setup
	; tmp needs to contains address including column offset
	clc
	tya
	adc screenAddr
	sta screenAddr
	lda screenAddr+1
	adc #0
	sta screenAddr+1

	lda screenMask		; Get the mask
	ldx #7
gr_hchar_mask							; Calculate how many shifts to tmp
	dex
	lsr
	bne gr_hchar_mask
	stx screenTmp		; number between 1 and 6 : shift n-1 times

	; copy font bytes and shift the required number of times
	; go from bottom to top as data gets stored on the stack!
	ldy #7
gr_hchar_getfont
	lda (tmp0),y
	sta tmp4
	lda #0
	sta tmp4+1

	; shift the right number of times
	ldx screenTmp
gr_hchar_rot1bit
	dex
	beq gr_hchar_rot1bit_nx
	lsr tmp4					; Rotate left hand side
	lda tmp4+1				; Rotate right hand side
	bcc gr_hchar_rot1bit_bcc
	ora #$40					; account for 6 bits per byte
gr_hchar_rot1bit_bcc
	lsr
	sta tmp4+1
	bpl gr_hchar_rot1bit		; Always as lsr sets N=0
gr_hchar_rot1bit_nx
	lda tmp4+1				; Get RHS
	pha							; Push RHS on to stack
	lda tmp4					; Get LHS
	pha							; Push that too - LH gets pulled first
	dey							; Bottom to to lines
	bpl gr_hchar_getfont

	; Now copy shift source to destination, accounting for pixmode
	ldx #8
gr_hchar_copyline
	ldy screenPixMode			; Mode determines how to modify
	beq gr_hchar_copyline_erase
	bmi gr_hchar_copyline_eor

	; Mode = ~Z : OR
	ldy #0						; Get lh side source
	pla
	ora (screenAddr),y
	sta (screenAddr),y
	iny							; Get rh side source
	pla
	ora (screenAddr),y
	sta (screenAddr),y
	jmp gr_hchar_copyline_nx
gr_hchar_copyline_eor
	; Mode = N : EOR
	ldy #0						; Get lh side source
	pla
	eor (screenAddr),y
	sta (screenAddr),y
	iny							; Get rh side source
	pla
	eor (screenAddr),y
	sta (screenAddr),y
	jmp gr_hchar_copyline_nx
gr_hchar_copyline_erase
	; Mode = Z : erase
	ldy #0						; Get lh side source
	pla
	sta tmp4
	ora (screenAddr),y
	eor tmp4
	sta (screenAddr),y
	iny							; Get rh side source
	pla
	sta tmp4
	ora (screenAddr),y
	eor tmp4
	sta (screenAddr),y
gr_hchar_copyline_nx
	clc							; Next address
	lda screenAddr
	adc #40
	sta screenAddr
	lda screenAddr+1
	adc #0
	sta screenAddr+1
	dex
	bne gr_hchar_copyline
	rts							; Done after 8 lines

;****************************************
;* gr_point_setup
;* Calculate information about a pixel location
;* Input : X,Y = coord
;* Output : None
;* Regs affected :
;* gr_geom_tmp contains the row base address
;* gr_geom_tmp2 contains the mask
;* A contains the mask
;* X untouched
;* Y contains column offet from base address
;****************************************
gr_point_setup
	; Get row address
	lda hiresAddrLow,y
	sta screenAddr
	lda hiresAddrHigh,y
	sta screenAddr+1
	; Get the pixel mask
	lda hires_mask,x
	sta screenMask
	; Get the column offset to Y
	ldy hiresColumn,x
	rts

;* Get pixel value at X,Y in to A
gr_pixel
	jsr gr_point_setup				; Set up mask and addresses, Y=column, A=mask
	and (screenAddr),y				; And with screen byte
	rts

;* Plot a point based on X,Y coordinates
gr_point
	cpx #240						; Check bounds
	bcs gr_point_done
	cpy #200
	bcs gr_point_done

	jsr gr_point_setup				; Set up mask and addresses, Y=column, A=mask

;* Plot a point based on gr_geom_tmp base, Y offset and X index mask
	lda (screenAddr),y	; Get screen byte
	cmp #32							; If less than 32 (i.e. an attribute)
	bcs gr_point_skip_attr
	lda #64							; then make it a normal cell (else weird things happen)
gr_point_skip_attr
	ldx screenPixMode				; Look at the mode
	bmi gr_point_eor				; If eor mode then go and write
	ora screenMask					; Or with MASK
	cpx #0							; But if zero mode then eor
	bne gr_point_write
gr_point_eor
	eor screenMask					; EOR with MASK
gr_point_write
	sta (screenAddr),y
gr_point_done
	rts


; Input routines

;* The IO block is at $0300
-IO_0		= $0300

;* Standard definitions of 6522 registers
;* As found in the datasheets
-PRB			= $00
-PRA			= $01
-DDRB		= $02
-DDRA		= $03
-T1CL		= $04
-T1CH		= $05
-T1LL		= $06
-T1LH		= $07
-T2CL		= $08
-T2CH		= $09
-SR			= $0a
-ACR			= $0b
-PCR			= $0c
-IFR			= $0d
-IER			= $0e
-PRAH		= $0f

-IFR_CA2		= $01
-IFR_CA1		= $02
-IFR_CB1		= $10

;* AY-3-8912 definitions
;* The sound chip is accessed through VIA Port A
-SND_ADBUS	= IO_0+PRAH
-SND_MODE	= IO_0+PCR

; Values for the PCR register - always enable CB1 active edge (bit 4)
-SND_SELREAD			= %11011111		; CB2=low, CA2=high
-SND_SELWRITE		= %11111101		; CB2=high, CA2=low
-SND_SELSETADDR		= %11111111		; CB2=high, CA2=high
-SND_DESELECT		= %11011101		; CB2=low,CA2=low

-SND_REG_CHAPL	= $00
-SND_REG_CHAPH	= $01
-SND_REG_CHBPL	= $02
-SND_REG_CHBPH	= $03
-SND_REG_CHCPL	= $04
-SND_REG_CHCPH	= $05
-SND_REG_CHNP	= $06
-SND_REG_CTL		= $07
-SND_REG_CHAVOL	= $08
-SND_REG_CHBVOL	= $09
-SND_REG_CHCVOL	= $0a
-SND_REG_ENVPL	= $0b
-SND_REG_ENVPH	= $0c
-SND_REG_ENVCYC	= $0d

-SND_REG_IOA	= $0e
-SND_REG_IOB	= $0f


;* Port B
-KB_PRB		= $b0			; Upper nibble of PRB default state (for correct operation of periperhals)
-KB_SENSE	= $08			; Input - Bit 3 port A
-KB_CAPSLK	= $01			; Id of Caps Lock
-KB_IJK		= %00100000	; IJK joystick detect bit

;****************************************
;* kb_stick
;* Check for fire | down | up | right | left
;*        bit  4     3      2     1       0
;* A = Returns bit mask of keys pressed
;* Y corrupted, X=0
;****************************************
_kb_stick
	php
	sei
	; Select Row 4 only, all keys on this row
	lda #4+KB_PRB			; Maintain upper nibble of PRB
	sta IO_0+PRB
	lda #SND_REG_IOA		; Select AY Port A for columns
	jsr snd_sel_reg
	lda #0					; Result will be in A
	pha
	ldy #4					; Go through the 5 cols on row 4
kb_stick_pos
	lda kb_stick_mask,y		; Get the column mask
	jsr snd_set_reg			; Activate column
	nop
	nop
	nop
	nop
	lda #KB_SENSE			; Something pressed?
	and IO_0+PRB			; Read Port B
	cmp #KB_SENSE			; C=1 if set else 0
	pla
	rol						; Get C in to A
	pha
	dey
	bpl kb_stick_pos		; Do all 5 positions
	pla						; Result in X
	tax
	plp
	rts

;****************************************
;* snd_sel_reg
;* Select AY register from A
;* Input : A = Value
;* Output : None
;* Regs affected : None
;****************************************
snd_sel_reg
	pha
	sta SND_ADBUS			; Put reg # on Port A (sound bus)

	lda #SND_SELSETADDR		; Get ready to select the reg
	sta SND_MODE			; Latch the reg # on Port A

	lda #SND_DESELECT		; Deselect AY
	sta SND_MODE

	pla
	rts

;****************************************
;* snd_set_reg
;* Set previosuly selected AY register
;* Input : A = Value to set
;* Output : None
;* Regs affected : None
;****************************************
snd_set_reg
	pha

	sta SND_ADBUS			; Put reg value on Port A (sound bus)
	lda #SND_SELWRITE		; Select mode for writing data
	sta SND_MODE			; Latch reg value on Port A	
	lda #SND_DESELECT		; Deselect AY
	sta SND_MODE

	pla
	rts


kb_stick_mask
	.byt %11011111		; Left 	= Bit 0
	.byt %01111111		; Right = Bit 1
	.byt %11110111		; Up	= Bit 2
	.byt %10111111		; Down	= Bit 3
	.byt %11111110		; Space	= Bit 4


;****************************************
;* Character based sprites for text mode only
;****************************************
; Sprite data stored in 1 page
spr_curX	 .dsb 32			; Sprite current X pos
spr_newX	 .dsb 32			; Sprite new X pos
spr_curY	 .dsb 32			; Sprite current Y pos
spr_newY	 .dsb 32			; Sprite new Y pos
spr_chr		 .dsb 32			; Sprite character
spr_bgnd	 .dsb 32			; Background character under sprite
spr_baseadrl .dsb 32			; Y low address of sprite screen (with X=0)
spr_baseadrh .dsb 32			; Y high address of sprite screen (with X=0)

;* Initialisation
_gr_spr_init
	ldx #31							; Start at last sprite
gr_spr_init_loop
	lda #$ff						; Put -1 in the x coords
	sta spr_curX,x
	sta spr_newX,x
	dex								; Next sprite
	bpl gr_spr_init_loop			; Until all 32 sprites initialised
	rts


;* Erase all active sprites
_gr_spr_erase
gr_spr_erase
	; First restore background from sprites
	; that are active and new pos is different from current
	ldx #31							; Start at last sprite
gr_spr_erase_loop
	lda spr_curX,x					; Is sprite active?
	bmi gr_spr_erase_next
	tay								; x pos in to Y
gr_spr_erase_do
	lda spr_bgnd,x					; Get the background
	jsr gr_spr_put					; And restore it
gr_spr_erase_next
	dex
	bpl gr_spr_erase_loop
	rts

;* Get ready for new position
_gr_spr_new
gr_spr_new
	ldx #31							; Start at last sprite
gr_spr_new_loop
	lda spr_newY,x					; Get new Y
	sta spr_curY,x					; Update new->cur Y
	tay								; Used for address calc.
	lda spr_newX,x					; Get new X
	sta spr_curX,x					; Update new->cur X
	bmi gr_spr_new_next				; Is the new position active?
	pha 							; x pos saved for later
	; Calculate screen address
	; save as part of sprite data and in zp area
	clc
	lda textAddrLow,y
	sta tmp0
	sta spr_baseadrl,x
	lda textAddrHigh,y
	sta tmp0+1
	sta spr_baseadrh,x
	pla								; Get x pos back in to Y reg
	tay
	lda (tmp0),y					; Get background
	sta spr_bgnd,x					; And save this
gr_spr_new_next
	dex
	bpl gr_spr_new_loop
	rts


; Draw all active sprites
; Active sprites are always drawn - 0 = highest priority
_gr_spr_draw
gr_spr_draw
	ldx #31							; Start at last sprite
gr_spr_draw_loop
	lda spr_newX,x					; Is sprite active?
	bmi gr_spr_draw_next
	tay								; X pos in to Y
	lda spr_chr,x					; Get the sprite char
	jsr gr_spr_put
gr_spr_draw_next
	dex
	bpl gr_spr_draw_loop
	rts


;* Common routine to put A to screen address
;* Used for erase and draw of sprites
;* X=index in to sprite table
;* Y=X offset from screen pointer
gr_spr_put
	pha
	lda spr_baseadrl,x				; Get the screen pointer
	sta tmp0
	lda spr_baseadrh,x
	sta tmp0+1
	pla								; Get back the char to
	sta (tmp0),y					; put on to screen
	rts


;* Update spr A with char X
_gr_spr_char
	ldy #2
	lda (sp),y				; Access spr char
	tax						; Save in X
	ldy #0
	lda (sp),y				; Access spr num
	tay
	txa						; Restore X->A
	sta spr_chr,y
	rts

;* Locate what is at the location of sprite A, returned in A
;* C=1 if sprite it not active
_gr_spr_hit
	tax
	lda spr_curX,x
	cmp #$80						; If A>=0x80 then C=1
	lda spr_bgnd,x
	rts

;* Update spr A with coords X,Y
_gr_spr_pos
	ldy #4							; Get Y coord
	lda (sp),y
	sta tmp0						; Save Y
	ldy #2							; Get X coord
	lda (sp),y
	tax
	ldy #0							; Get spr num
	lda (sp),y
	ldy tmp0						; Recall Y
gr_spr_pos
	sty tmp0
	tay
	txa								; X coord still in X reg
	sta spr_newX,y
	lda tmp0						; Y coord from temp
	sta spr_newY,y
	rts

;* Update sprites
_gr_spr_upd
	jsr gr_spr_erase
	jsr gr_spr_new
	jmp gr_spr_draw

mod_sz_sprite_e

;* Timer by initialising value to current timer
_gr_resetTimer
	php
	ldy #0			; Get low value of pointer
	lda (sp),y
	sta tmp0
	iny				; Get high value of pointer
	lda (sp),y
	sta tmp0+1
	dey
	sei				; Need to get 2 bytes of timer
	lda PT3Counter	; Get current value of PT3Counter to 
	sta (tmp0),y	; Value pointed to by address
	iny
	lda PT3Counter+1
	sta (tmp0),y
	plp
	rts

;* Elapsed time
_gr_elapsed
	sec
	php
	sei				; Need to get 2 bytes of timer
	lda PT3Counter
	sbc tmp0
	tax
	lda PT3Counter+1
	sbc tmp0+1
	plp
	rts

#endif
