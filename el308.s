	.title "EL308 Experiment Board"
	.sbttl "Initialization Code"
	.equ __24FJ256GB110, 1
	.include "p24FJ256GB110.inc"

	.global __reset          ;The label for the first line of code. 
	.global __T1Interrupt    ;Declare Timer 1 ISR name global

.bss
	LCD_line1:	.space 16
	LCD_line2:	.space 16
	LCD_ptr:	.space 2
	LCD_cmd:	.space 2
	LCD_offset: .space 2
.section .const,psv
	line1:		.ascii "PIC24 Board v1.0"
	line2:		.ascii "Keyboard  -->   "
	lookup:		.ascii "0123456789ABCDEF"
.text                             ;Start of Code section
__reset:
	mov 	#__SP_init, W15		; Initalize the Stack Pointer
	mov 	#__SPLIM_init, W0	; Initialize the Stack Pointer Limit Register
	mov 	W0, SPLIM
	nop							; Add NOP to follow SPLIM initialization
        
        ;<<insert more user code here>>

	mov.b WREG, 0x0800

	call	init_PSV
	call	init_LED
	call	init_LCD
	call	init_message
	call	init_keypad
	call	init_buzzer

	call	init_timer

	bset	PORTF, #3

check_keypad:
	btss	PORTD, #6	; keypad entry?
	bra		check_keypad

	mov		PORTD, W0
;	mov		#0x000F, W1
;	and		W0, W1, W0
    mov     W0, PORTF
	bset	PORTD, #13		; turn the buzzer on
	
wait_release:
	btsc	PORTD, #6		; key released?
	bra		wait_release
	bclr	PORTD, #13		; turn the buzzer off

	bra		check_keypad


;wait_0:
;	btsc 	PORTC, #5
;	bra 	wait_0

;	mov.b 	#'A', WREG0H

; -----------------------------------------------------
; !!!!!!!!!!!!!!!!!! Functions !!!!!!!!!!!!!!!!!!!!!!!!
; -----------------------------------------------------

init_PSV:
	mov		#psvpage(line1), W0
	mov		W0, PSVPAG		; set PSVPAG to page that contains hello
	bset.b	CORCONL,#PSV	; enable Program Space Visibility
	return

init_timer:
	bclr	T1CON, #TON		; turn timer1 OFF
	
	bset	T1CON, #TCKPS1
	bset	T1CON, #TCKPS0	; set prescaler to 256

	bclr	T1CON, #TCS		; select internal clock

	mov		#0x0000, W0 
	mov		W0, TMR1		; clear TMR1 register
	mov		#0x0040, W0
	mov		W0, PR1			; set timer1 period to 0x0040 -> f=2e6/256/64=122 Hz

	bclr	IPC0, #14
	bclr	IPC0, #13
	bset	IPC0, #12		; set timer1 priority to 001
	bclr	IFS0, #T1IF		; clear timer1 interrupt status flag
	bset	IEC0, #T1IE		; enable timer1 interrupts
	
	bset	T1CON, #TON		; turn timer1 ON
	return

init_LED:
	bclr	TRISF, #0
	bclr	TRISF, #1
	bclr	TRISF, #2
	bclr	TRISF, #3		; LED array
	return

init_LCD:
	bclr	TRISB, #15
	bclr	PORTD, #4		; make sure LCD is disabled before port is set to output mode
	bclr	TRISD, #4
	bclr	TRISD, #5
	mov		#0xFF00, W0
	mov		W0, TRISE

	bclr	PORTD, #5		; select LCD WR mode

	mov		#0x0038, W0		; init LCD
	call	sendcomm
	call	dly
	call	dly
	call	dly

	mov		#0x000E, W0		; LCD on, cursor on
	call	sendcomm
	mov		#0x0001,W0		; clear LCD
	call 	sendcomm
	return

sendcomm:
	bclr	PORTB,#15	; select LCD command register
	mov		W0, PORTE	; output command
	bset	PORTD, #4
	call	dly
	nop
	bclr	PORTD, #4
	call	dly
	return

dly:
	mov 	#0x2000,W0
dlyloop:
	sub		W0, #1, W0
	bra		NZ, dlyloop
	return

init_message:
	mov		#0x0000, W0
	mov		W0, LCD_ptr
	mov		W0, LCD_offset
	mov		#0x00C0, W0
	mov		W0, LCD_cmd
	mov		#psvoffset(line1), W1
	mov		#LCD_line1, W2
	repeat	#15
	mov.b	[W1++], [W2++]
	mov		#psvoffset(line2), W1
	mov		#LCD_line2, W2
	repeat	#15
	mov.b	[W1++], [W2++]
	return

init_keypad:
	bset	TRISD,#0	; DATA A
	bset	TRISD,#1	; DATA B
	bset	TRISD,#2	; DATA C
	bset	TRISD,#3	; DATA D
	bset	TRISD,#6	; DATA Available
	return

init_buzzer:
	bclr	PORTD, #13	; buzzer initially OFF
	bclr	TRISD, #13	; enable output
	return
	

;..............................................................................
;Timer 1 Interrupt Service Routine
;Example context save/restore in the ISR performed using PUSH.D/POP.D
;instruction. The instruction pushes two words W4 and W5 on to the stack on
;entry into ISR and pops the two words back into W4 and W5 on exit from the ISR
;..............................................................................
__T1Interrupt:
	push.s
	push.d	W4                  ; Save context using double-word PUSH
	
        ;<<insert user code here>>
	bclr	IFS0, #T1IF           ; Clear the Timer1 Interrupt flag Status
                                  ; bit.

	mov		LCD_ptr, W2
	mov		#0x0010, W1
	cp		W1, W2
	bra		NZ, send_LCD_data
	mov		LCD_cmd, W0
	bclr	PORTB, #15		; select LCD command register
	mov		W0, PORTE		; output command
	bset	PORTD, #4
	nop
	bclr	PORTD, #4
	btg		W0, #6
	mov		W0, LCD_cmd
	mov		#0x0000, W2
	mov		W2, LCD_ptr
	mov		LCD_offset, W0
	btg		W0, #4
	mov		W0, LCD_offset
;	btg		PORTF, #2
	bra		done_T1interrupt
send_LCD_data:
	mov		LCD_offset, W3
	add		W3, W2, W3
	mov		#LCD_line1, W1
	mov.b	[W1+W3], W0
	bset	PORTB, #15		; select LCD data register
	mov		W0, PORTE		; output command
	bset	PORTD, #4
	nop
	bclr	PORTD, #4
	inc		W2, W2
	mov		W2, LCD_ptr

done_T1interrupt:
	pop.d W4                   ;Retrieve context POP-ping from Stack
	pop.s
	retfie                     ;Return from Interrupt Service routine

;--------End of All Code Sections ---------------------------------------------

.end                               ;End of program code in this file

