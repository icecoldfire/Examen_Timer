$NOLIST
$nomod51
$INCLUDE (c:/reg832.pdf)
$LIST
;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; Main Program
;
; This Program will loop over the subsytems (see below)
; 1) Get the user input and save this
; 2) Check if we need to update the led's
; 3) Update the led's
;
; We use the subsystems: 'user' and 'led_api' 
;
; SETTINGS:
;
;	Pleas set the wright options for compiling

	DIL_ADuC832	SET	0 	; Set this if we use the DIL variant of the ADuC832
;						If DIL is set buzzer on port_map.2 
;						else Buzzer on buzzer jumper
;
	LCD		SET	0	; Set this if we use LCD and Buttons for comunication
	USB		SET	0	; Set this if we use USB for comunication 
;
;	YOU CAN CHANGE THE PORT IN OPTION port_map 
;
;********************************************************************************************** 

;********************************************************************************************** 
; Memory map:
;	Update input flag:		Every second
;		000h
;	Update LED flag;		Every minute
;		001h
;	Can we use the buzzer
;		002h
;	Are we using the usb
;		003h
;	Are we in the config menu of the usb
;		004h
;	Examentime to go in min:
;		030h
;	Value of how many times timer 1 has interupted
;		032h
;	Value of how many times timer 0 has interupted
;		033h
;	Seconds timer
;		034h
;	Total examen time:
;		035h
;	Total alarm time
;		036h
;	Led data:
;		040h per led 4 registers * led count
;			ex: led1: 040h(gl) 041h(b) 042h(g) 043h(r)
;			ex: led2: 044h(gl) 045h(b) 046h(g) 047h(r)
;********************************************************************************************** 

stack_init	equ	0b9h			; LED data will go until 0b7 for 30 led's
led_count	equ	030d			; Give the number of APA102 led's in the strip max 48 for this 8 bit driver
port_map	equ	p3			; Give the port we need to map 

;Defenition of the memory map:
input_flag		bit	000h
LED_flag		bit	001h
Buz_flag	 	bit	002h
USB_flag		bit	003h
USB_flag_config		bit	004h
examen_time		equ	030h
timer1_count	 	equ	032h
timer0_count		equ	033h
sec_timer		equ	034h
total_examen_time	equ	035h
total_alarm_time	equ	036h
LED_data_offset		equ	040h

		org	0000h
		ljmp	main_init
		
		org	000Bh			; Interupt timer 0
		ljmp	user_alarm_timer_intr

		org	001Bh			; Interupt timer 1
		ljmp	buzzer_intr		; Buzzer music
if USB=1
		org	023h			; user_input_USB_intr interupt
		ljmp	user_input_USB_intr
endif
; Init of the main program
main_init:	mov	sp,#stack_init
		mov	pllcon,#000h		; Clk on 16MH
		
		lcall	led_api_init		; Init the led's
		lcall   APA102_test_led_strip	; APA102_test programe of led's
		
		lcall	user_init		; Init the user interface
		lcall	buzzer_music_init	; Init the buzzer
		lcall	buzzer_music

		sjmp	main_loop		; Loop
		
		
; The main loop		
main_loop:	
		lcall	user_input		; Get the user input and save this
		
		jnb	LED_flag,main_loop	; Check if we need to  update the led's
		lcall	user_alarm		; Calculates the led data and set the buzzer on and off if needed
		lcall	led_api_out		; Sends out the calculated data 
		clr	LED_flag
		
		sjmp 	main_loop

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; class: user
; User function gets the user input and calculates the wright values for led_api
;
; Necessary:
;	CLK on 16 Mhz
;
; External functions: 
;	Doesn't break acc
;	Interupts allowed
; 
; 	user_init: Makes the user USB and LCD interface ready
; 	user_init_LCD: Makes the user LCD interface ready
; 	user_init_USB: Makes the user USB interface ready
; 	user_input: Stores the user input from USB and LCD
; 	user_input_LCD: Stores the user input from LCD
; 	user_input_USB: Stores the user input from USB
;	user_input_USB_d_out: Print a decimal out to the terminal
;	user_input_USB_intr: Gets the user input and stores this
;	user_input_USB_INBYTE: Gets from the terminal a number in format xxx (000-255) and stores this in a 
;	user_alarm_init: Init of the user alarm
;	user_alarm: Sends the alarm to the user
; 	user_alarm_timer_init: Decrease every minute the registers 030h and 031h. Makes use of timer 0
; 	user_alarm_timer_intr: The interupt routine for timer 0
;
; Internal functions:
;
;	user_input:
;		user_input_exit
;
; 	user_input_LCD:
;		user_input_LCD_loop_1
;		user_input_LCD_loop_2
;		user_input_LCD_exit
;		user_input_LCD_no_button
;		user_input_LCD_d_out
;		user_input_LCD_text_0
;		user_input_LCD_text_1
;		user_input_LCD_text_2
;
;	user_input_USB:
;		user_input_USB_exit
;		user_input_USB_text_0
;		user_input_USB_text_1
;		user_input_USB_text_2
;		user_input_USB_text_3
;
;	user_input_USB_intr:
;		user_input_USB_intr_e
;		user_input_USB_intr_a
;		user_input_USB_intr_exit
;		user_input_USB_intr_text_0
;		user_input_USB_intr_text_1
;		user_input_USB_intr_text_2
;		user_input_USB_intr_text_3
;		user_input_USB_intr_text_4
;
;	user_input_USB_INBYTE:
;		user_input_USB_INBYTE_10
;		user_input_USB_INBYTE_0
;		user_input_USB_INBYTE_100
;		user_input_USB_INBYTE_exit
;
; 	user_alarm:
;		user_alarm_time_0
;		user_alarm_time_exit
;		user_alarm_text_0
;		user_alarm_calc_led_n
;		user_alarm_calc_led_a
;		user_alarm_data
;		user_alarm_data_loop
;		user_alarm_data_mem
;		user_alarm_data_clr
;		user_alarm_data_clr_loop
;
; 	user_alarm_timer_intr:
;		user_alarm_timer_intr_min
;		user_alarm_timer_intr_min_2
;		user_alarm_timer_intr_exit
;		user_alarm_timer_intr_reload
;
;**********************************************************************************************  

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_init
; Makes the user interface ready
;
; Input: none
;
; Output: clears the screen
;
;********************************************************************************************** 

user_init:	

		
if LCD = 1
		lcall	user_init_LCD
endif

if USB = 1
		lcall	user_init_USB
endif

		mov	examen_time,#099
		mov	total_examen_time,#099
		mov	total_alarm_time,#030
		lcall	user_alarm_init		; Init the alarms
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_input
; Gets the user input and stores this
;
; Input: From buttons and DIP-switchs or from USB
;	 SEE SETTINGS
;
; Output: Text to screen
;
; Internal functions:
;	user_input_exit
;********************************************************************************************** 

user_input:	
		jnb	input_flag,user_input_exit 		; update only 1 time per sec
		clr	input_flag
if LCD = 1
		lcall	user_input_LCD
endif

if USB = 1
		lcall	user_input_USB
endif

user_input_exit:
		ret
;***************
;* LCD SECTION *
;***************
if LCD = 1

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_init_LCD
; Makes the user LCD interface ready
;
; Input: none
;
; Output: clears the screen
;
;********************************************************************************************** 

user_init_LCD:	
		push	acc
		setb	Buz_flag	; Mute the buzzer 
		lcall	initlcd		; lcd init
		lcall	lcdlighton	; lcdlight on
		mov	a,#00ch		; clear screen and cursor on posistion 00
		lcall	outcharlcd
		mov	a,#013h		; cursor off
		lcall	outcharlcd
		clr	Buz_flag
		
		mov	examen_time,#099
		mov	total_examen_time,#099
		mov	total_alarm_time,#030
		pop	acc
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_input_LCD
; Gets the user input and stores this
;
; Input: From buttons and DIP-switchs
;	 SEE SETTINGS
;
; Output: Text to screen
;
; Internal functions:
;	user_input_LCD_loop_1
;	user_input_LCD_loop_2
;	user_input_LCD_no_button
;	user_input_LCD_d_out
;	user_input_LCD_text_0
;	user_input_LCD_text_1
;	user_input_LCD_text_2
;
;********************************************************************************************** 

user_input_LCD:	
		push	acc
		push	psw
		setb	psw.3
		
		setb	Buz_flag			; Mute the buzzer 
		mov	a,#00ch				; Clear screen and move cursor to 00
		lcall	outcharlcd
		mov	a,#013h				; Cursor off
		lcall	outcharlcd
		mov	dptr,#user_input_LCD_text_0		; text_0 out to screen
		lcall	outmsgalcd
		mov	b,examen_time
		lcall	user_input_LCD_d_out
		clr	Buz_flag
		
		mov	a,p3				; Get button (p3.7 - p3.4)
		cpl	a				; Inversion for active high
		swap	a				; Put data a in a.4 until a.0
		anl	a,#001h				; Clear upper 7 bits
		jz	user_input_LCD_no_button		; button p3.4 not pressed so no user input

		clr	tr0				; Stop the timer0
		setb	Buz_flag			; Mute the buzzer 
		mov	a,#00ch				; Clear screen and move cursor to 00
		lcall	outcharlcd
		mov	a,#013h				; Cursor off
		lcall	outcharlcd
		mov	dptr,#user_input_LCD_text_1		; text_1 out to screen
		lcall	outmsgalcd

user_input_LCD_loop_1:
		mov	b,p0
		mov	examen_time,b			; Get examen time
		mov	total_examen_time,b
		lcall	user_input_LCD_d_out
		mov	a,p3				; Get button (p3.7 - p3.4)
		cpl	a				; Inversion for active high
		swap	a				; Put data a in a.4 until a.0
		anl	a,#002h				; Clear upper 6 bits and bit 0		
		jz	user_input_LCD_loop_1		; button p3.5 not pressed so no user input
		
		mov	a,#00ch				; Clear screen and move cursor to 00
		lcall	outcharlcd
		mov	a,#013h				; Cursor off
		lcall	outcharlcd
		mov	dptr,#user_input_LCD_text_2		; text_1 out to screen
		lcall	outmsgalcd

user_input_LCD_loop_2:
		mov	b,p0				; Get alert time
		mov	total_alarm_time,b
		lcall	user_input_LCD_d_out
		mov	a,p3				; Get button (p3.7 - p3.4)
		cpl	a				; Inversion for active high
		swap	a				; Put data a in a.4 until a.0
		anl	a,#004h				; Clear upper 4 bits and lower 2 bits
		jz	user_input_LCD_loop_2		; button p3.4 not pressed so no user input
		
		clr	tr0
		mov	tl0,#000h
		mov	th0,#000h
		setb	tr0
		clr	Buz_flag
		setb	LED_flag			; Update the led's
		sjmp 	user_input_LCD_exit

; Exit the user_input_LCD function
user_input_LCD_exit:
		
		pop	psw
		pop	acc
		ret

; No buttons pressed so stop
user_input_LCD_no_button:
		sjmp	user_input_LCD_exit
; Print a decimal out on second line of screen
; decimal is send trough by b
user_input_LCD_d_out:
		push	acc
		
		mov	a,#040h 			; Cursor on second line first posistion
		orl	a,#80h
		lcall	outcharlcd
		mov	a,b				; Put value of p0 in acc
		mov	b,#100				
		div	ab				; Divide a by 100
		lcall	outniblcd			; 100 out
		mov	a,#041h 			; Cursor on second line second posistion
		orl	a,#80h
		lcall	outcharlcd
		mov	a,b				; Put value of p0 in acc
		mov	b,#10				
		div	ab				; Divide a by 100
		lcall	outniblcd			; 10 out
			
		mov	a,#042h 			; Cursor on second line third posistion
		orl	a,#80h
		lcall	outcharlcd
		mov	a,b
		lcall	outniblcd			; 1 out
		
		pop	acc
		ret	

user_input_LCD_text_0:
		db	'Tijd te gaan:'
		db	0C0h				; Next line
		db	'    min. Druk 1'
		db	000h				; End

user_input_LCD_text_1:
		db	'Geef examentijd:'
		db	0C0h				; Next line
		db	'    min. Druk 2'
		db	000h				; End
		
user_input_LCD_text_2:
		db	'Geef alarmtijd:'
		db	0C0h				; Next line
		db	'    min. Druk 3'
		db	000h				; End

endif
;***************
;* USB Section *
;***************
if USB = 1

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_init_USB
; Makes the user USB interface ready
;
; Input: none
;
; Output: clears the screen
;
;**********************************************************************************************
 
user_init_USB:	
		lcall	initsio			; Init of the user_input_USB_intr
		clr	USB_flag
		clr	USB_flag_config
		setb	es
		setb	ea
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_input_USB
; Prints the time of to the terminal
;
; Input: From none
;
; Output: Text to screen
;
; Internal functions:
;	user_input_USB_exit
;	user_input_USB_text_0
;	user_input_USB_text_1
;	user_input_USB_text_2
;	user_input_USB_text_3
;
;**********************************************************************************************

user_input_USB: 
		push	acc
		jb	USB_flag,user_input_USB_exit
		jb	USB_flag_config,user_input_USB_exit
		
		setb	USB_flag
		
		mov	dptr,#user_input_USB_text_0
		lcall	outmsga

		mov	a,examen_time
		lcall	user_input_USB_d_out
		
		mov	dptr,#user_input_USB_text_1
		lcall	outmsga
		
		mov	a,total_examen_time
		lcall	user_input_USB_d_out
		
		mov	dptr,#user_input_USB_text_2
		lcall	outmsga	

		mov	a,total_alarm_time
		lcall	user_input_USB_d_out

		mov	dptr,#user_input_USB_text_3
		lcall	outmsga

		clr	USB_flag
user_input_USB_exit:
		pop	acc
		ret

user_input_USB_text_0:
		db	00ah				; Clear terminal
		db	'Druk op een toets om de tijd in te stellen.'
		db	00dh				; Next line
		db	'Nog: '
		db	000h				; End
		
user_input_USB_text_1:
		db	' minuten te gaan van de '
		db	000h
		
user_input_USB_text_2:
		db	' minuten. Alarm gaat af de laatste: '
		db	000h

user_input_USB_text_3:
		db	' minuten.'
		db	000h

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_input_USB_d_out
; Print a decimal out to the terminal
;
; Input: a
;
; Output: decimal to screen
;
;**********************************************************************************************

user_input_USB_d_out:
		push	acc
		mov	b,#100				
		div	ab				; Divide a by 100
		lcall	outnib				; 100 out
		mov	a,b				; Put value of p0 in acc
		mov	b,#10				
		div	ab				; Divide a by 100
		lcall	outnib				; 10 out	
		mov	a,b
		lcall	outnib				; 1 out
		pop	acc
		ret	

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_input_USB_intr
; Gets the user input and stores this
;
; Input: From terminal
;
; Output: Text to screen
;
; Internal functions:
;	user_input_USB_intr_e
;	user_input_USB_intr_a
;	user_input_USB_intr_exit
;	user_input_USB_intr_text_0
;	user_input_USB_intr_text_1
;	user_input_USB_intr_text_2
;	user_input_USB_intr_text_3
;	user_input_USB_intr_text_4
;
;**********************************************************************************************

user_input_USB_intr:
		push	acc
		push	psw
		clr	ti
		clr	ri
		jb	USB_flag,user_input_USB_intr_exit	; Check if we are transmiting, if yes we end the interupt routine
		setb	USB_flag_config
		setb	USB_flag

user_input_USB_intr_e:
		clr	c
		mov	dptr,#user_input_USB_intr_text_0
		lcall	outmsga
		
		lcall	user_input_USB_INBYTE
		jc	user_input_USB_intr_e			; Error restart
		mov	examen_time,a
		mov	total_examen_time,a
		
		mov	dptr,#user_input_USB_intr_text_1
		lcall	outmsga
		lcall	user_input_USB_d_out
		mov	dptr,#user_input_USB_intr_text_2
		lcall	outmsga
user_input_USB_intr_a:
		clr	c
		mov	dptr,#user_input_USB_intr_text_3
		lcall	outmsga
		
		lcall	user_input_USB_INBYTE
		jc	user_input_USB_intr_a			; Error restart
		mov	total_alarm_time,a

		mov	dptr,#user_input_USB_intr_text_1
		lcall	outmsga
		lcall	user_input_USB_d_out
		mov	dptr,#user_input_USB_intr_text_4
		lcall	outmsga
				
		clr	USB_flag
		clr	USB_flag_config

		clr	tr0
		mov	tl0,#000h
		mov	th0,#000h
		setb	tr0
user_input_USB_intr_exit:

		pop	psw
		pop	acc
		reti

user_input_USB_intr_text_0:
		db	00ah				; Clear terminal
		db	'Welkom in het configuratie menu!'
		db	00ah				; Next line
		db	'Geef de duur van het examen in (max 255): '
		db	00ah,000h				; End
		
user_input_USB_intr_text_1:
		db	00ah
		db	'We hebben '
		db	000h
		
user_input_USB_intr_text_2:
		db	' minuten ingesteld als de examen tijd.'
		db	000h
user_input_USB_intr_text_3:
		db	00ah
		db	'Geef nu het alarm tijd (max 255): '
		db	000h
user_input_USB_intr_text_4:
		db	' minuten ingesteld als de alarm tijd.'
		db	00ah
		db	'Einde van configuratie menu.'
		db	00dh,000h

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_input_USB_INBYTE
; Gets from the terminal a number in format xxx (000-255) and stores this in a 
; binair number in a
;
; Input: text form terminal
;
; Output: 	cary if error
;	 	the number a
;
; Internal functions:
;	user_input_USB_INBYTE_10
;	user_input_USB_INBYTE_0
;	user_input_USB_INBYTE_100
;	user_input_USB_INBYTE_exit
;
;********************************************************************************************** 

user_input_USB_INBYTE:      
		push	b
		lcall	INBUFA		; Wait on the user input
		
		dec	r0		; Pointer to the first number
		mov	a,@r0		; Put het 1 in the acc
		lcall	LOWUPTR		; Change to UPPERCASE
		lcall	ASCBINTRANS	; Change ascii to a binair number
		jc	user_input_USB_INBYTE_exit	;ERROR
		mov	b,a		; Save number in B
		
		dec	r0		; Pointer to the second number
		mov	a,@r0		; Put het 10 in the acc
		lcall	LOWUPTR		; Change to UPPERCASE
		lcall	ASCBINTRANS	; Change ascii to a binair number
		jc	user_input_USB_INBYTE_exit	;ERROR
		jz	user_input_USB_INBYTE_0		; We don't need to add
		mov	r1,a
		mov	a,b
user_input_USB_INBYTE_10:
		add	a,#10
		djnz	r1,user_input_USB_INBYTE_10
		mov	b,a
		
user_input_USB_INBYTE_0:
		dec	r0
		mov	a,@r0		; Put het 10 in the acc
		lcall	LOWUPTR		; Change to UPPERCASE
		lcall	ASCBINTRANS	; Change ascii to a binair number

		jc	user_input_USB_INBYTE_exit	;ERROR
		jz	user_input_USB_INBYTE_exit	; Check if zero
		mov	r1,a
		mov	a,b
user_input_USB_INBYTE_100:
		add	a,#100
		djnz	r1,user_input_USB_INBYTE_100
		mov	b,a
		
user_input_USB_INBYTE_exit:
		mov	a,b
		pop     b
		ret
endif

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_alarm_init
; Initialisation of the user alarm
;
; Input: none
;
; Output: none
;
; Necessary:
;	Makes use of timer 0
;
;********************************************************************************************** 

user_alarm_init:
		lcall	user_alarm_timer_init
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_alarm
; Set the right data in memory for the led driver
; Set the sound alarm
; Show screen that we are updating the screen
;
; Input: none
;
; Output: Text to screen
;
; Internal functions:
;	user_alarm_time_0
;	user_alarm_exit
;	user_alarm_text_0
;	user_alarm_calc_led_n
;	user_alarm_calc_led_a
;	user_alarm_calc_led_a_1
;	user_alarm_calc_led_a_2
;	user_alarm_data
;	user_alarm_data_loop
;	user_alarm_data_exit
;	user_alarm_data_no_led
;	user_alarm_data_mem
;	user_alarm_data_clr
;	user_alarm_data_clr_loop
;
;********************************************************************************************** 

user_alarm:
		push	acc
		push	psw
		
		setb	Buz_flag			; Mute the buzzer 
		mov	a,#00ch				; Clear screen and move cursor to 00
		lcall	outcharlcd
		mov	a,#013h				; Cursor off
		lcall	outcharlcd
		mov	dptr,#user_alarm_text_0		; text_0 out to screen
		lcall	outmsgalcd
		clr	Buz_flag
		
		mov	a,examen_time			; Get examen time
		subb	a,total_alarm_time		; Subtract alarm time
		
		jc	user_alarm_time_0		; If zero show alarm
		
		lcall	user_alarm_calc_led_n

		mov	r3,#01Fh		; Put the led's in green
		mov	r4,#00fh
		mov	r5,#0FFh
		mov	r6,#00fh
		lcall	user_alarm_data
		sjmp	user_alarm_exit

user_alarm_time_0:
		lcall	user_alarm_calc_led_a
		mov	r3,#01Fh		; Put the led's in red
		mov	r4,#000h
		mov	r5,#00fh
		mov	r6,#0FFh
		lcall	user_alarm_data
		lcall	buzzer_music
		sjmp	user_alarm_exit

user_alarm_exit:		
		pop	psw
		pop	acc
		ret
		
user_alarm_text_0:
		db	'Led-strip aan het'
		db	0C0h				; Next line
		db	'updaten.'
		db	000h

; This function calaculates the number of led's that still need to shine
; For in normal mode
user_alarm_calc_led_n:
		mov	a,total_examen_time		; Get the examen time
		sjmp	user_alarm_calc_led_a_1

; This function calaculates the number of led's that still need to shine
; For in alarm mode
user_alarm_calc_led_a:
		mov	a,total_alarm_time		; Get the alarm time

user_alarm_calc_led_a_1:
		mov	b,#led_count	; Get the ledocunt
		div	ab		; Divide
		jnz	user_alarm_calc_led_a_2		; Allwas have a one in the acc
		inc	a		; round up

user_alarm_calc_led_a_2:
		mov	b,a		; Qoutiont load (min/led) this will be now the divider
		mov	a,examen_time		; Time to go
		div	ab		; in a the number of led's that need to light up
		mov	r7,a
		subb	a,#led_count
		jc	user_alarm_calc_led_a_3
		mov	r7,#led_count
user_alarm_calc_led_a_3:
		mov	a,r7
		ret

; Fill the led's data with values in register until the upper led given by a
; a is the number of led's that need to shine
; r3-r6 is the color gl b g r
; r7 the number of led's that need to shine
; Makes use of r0,r1,r2
user_alarm_data:
		push	acc
		push	psw

		
		lcall	user_alarm_data_clr
		

		mov	a,r7
		jz	user_alarm_data_no_led	; Check if we need to do anything if not clear all the led's


user_alarm_data_loop:

		
		mov	r1,a			; Get the number of led's still needing commands
		
		lcall	user_alarm_data_mem	; Get the base memory location of the led


		
		add	a,#000h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,r3			; Get the global value			
		mov	@r0,a			; Put the value in mem
		
		mov	a,r2			; Get the base memory location of the led
		add	a,#001h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,r4			; Get the blue value			
		mov	@r0,a			; Put the value in mem
		
		mov	a,r2			; Get the base memory location of the led
		add	a,#002h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,r5			; Get the green value			
		mov	@r0,a			; Put the value in mem
		
		mov	a,r2			; Get the base memory location of the led
		add	a,#003h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,r6			; Get the red value			
		mov	@r0,a			; Put the value in mem
		
		mov	a,r1			; Led's that still need controll
		djnz	acc,user_alarm_data_loop; Decrement and loop again
		
user_alarm_data_exit:		

		pop	psw
		pop	acc
		ret

user_alarm_data_no_led:
		mov	r3,#000h
		mov	r4,#000h
		mov	r5,#000h
		mov	r6,#000h
		mov	r7,#led_count
		mov	a,#led_count
		sjmp 	user_alarm_data_loop

; Gets the next memory location and put this in r5
user_alarm_data_mem:
		mov	a,#led_count		; Get the total number of led's
		subb	a,r1			; Subbtract the number of led's still need to command
		mov	b,#004h			; The offeset multiplier
		mul	ab			
		add	a,#LED_data_offset			; Add the base register
		mov	r2,a
		ret
; Clears all the led data
user_alarm_data_clr:
		mov	a,#led_count		; Get the total number of led's
		mov	b,#004h			; The offeset multiplier
		mul	ab
		add	a,#LED_data_offset			; a = the max led register	
						
user_alarm_data_clr_loop:
		mov	r0,a			; Move the value adress in r0ue			
		mov	@r0,#000h		; Clear the cell
		dec	a
		cjne	a,#LED_data_offset - 1,user_alarm_data_clr_loop
		ret	

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_alarm_timer_init
; Initialization of timer 0 
;
; Input: none
;
; Output: none
;
; Necessary:
;	Makes use of timer 0
;
;********************************************************************************************** 

user_alarm_timer_init:
		mov	tl0,#000h		; Clear
		mov	th0,#000h
		mov	a,tmod
		orl	a,#00000001b
		mov	tmod,a
		setb	TR0			; Timer 1 on
		setb	et0
		setb	ea
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: user_alarm_timer_intr
; The interupt routine for timer 0
; Will set every second and minute the right flags
;
; Input: none
;
; Output: none
;
; Necessary:
;	CLK on 16 Mhz
;	Makes use of timer 0
;
; Internal functions:
;	user_alarm_timer_intr_min
;	user_alarm_timer_intr_min_2
;	user_alarm_timer_intr_exit
;	user_alarm_timer_intr_reload
;
;********************************************************************************************** 

user_alarm_timer_intr:
		push	acc
		push	psw
		mov	a,timer0_count					; Get the interupt count
		cjne	a,#21,user_alarm_timer_intr_reload 	; Do we have got almost a second? (counted until 0.98304.. sec?) 
								; (16.777216Mhz/12)^-1=715,255737ns *2^16 = 0.046875s (per timer interupt)
								;  
		clr	tr0
		mov	tl0,#0AAh				; 2^16 - 21845.333 instructions = 43691 instructions
		mov	th0,#0ABh
		setb	TR0
		mov	timer0_count,#000h

; Check if we hava minute
user_alarm_timer_intr_min:
		setb	input_flag					; Update the lcd 
		inc	sec_timer
		mov	a,sec_timer
		cjne	a,#060,user_alarm_timer_intr_exit
		setb	LED_flag					; Update the led's
		mov	a,examen_time

		jz	user_alarm_timer_intr_min_2		; If time 0 dun't subtract
		subb	a,#001
		mov	examen_time,a
		
user_alarm_timer_intr_min_2:
		mov	sec_timer,#000h

; Context switch on end interrupt.
user_alarm_timer_intr_exit:	
		pop	psw
		pop	acc
		reti

user_alarm_timer_intr_reload:
		clr	TR0
		mov	tl0,#000h		; Clear
		mov	th0,#000h
		setb	TR0			; Timer 0 on
		inc	a			; increment the counter
		mov	timer0_count,a			; save the counter
		sjmp	user_alarm_timer_intr_exit

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; class: led_api
; Led driver API for the APA102 driver class and user class
;
; Necessary:
;	CLK on 16 Mhz for delay1s function
;	led_count defined for led_api_out
;	port_map.0 for clk port (APA102)
;	port_map.1 for data port (APA102)
;	Makes use of class: APA102
;
; External functions: 
;	Doesn't break acc
;	Takes use of register bank 1
;	Interupts allowed
; 
;	led_api_init: Init of the led api and strip
;
;	led_api_out: Sends the data in memory out to the driver
;		Arguments:
;		see memory map
;
;	Internal functions:
;
;	led_api_out:
;		led_api_out_loop
;		led_api_calc_mem
;
;********************************************************************************************** 

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: led_api_init
; Initialization of the led api and strip
;
; Input: none
;
; Output: none
;
; Necessary:
;	Makes use of class: APA102 <-- See documentation
;
;********************************************************************************************** 

led_api_init:
		lcall	APA102_init
		setb	LED_flag
		ret
		
;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: led_api_out
; Sends the data in memory out to the driver
;
; Input: the led data in memory
;
; Output: led data to led-strip
;
; Necessary:
; 	Makes use of register bank 1
;	Makes use of class: APA102 <-- See documentation
;
; Internal functions:
;	 led_api_out_loop
;	 led_api_out_calc_mem
;
;********************************************************************************************** 

led_api_out:	
		push	acc
		push	psw
		setb	psw.3
				
		lcall	APA102_start_frame
		
		mov	a,#led_count		; Get the total number of LED's
				
led_api_out_loop:

		mov	r4,a			; Get the number of led's still needing commands
		
		lcall	led_api_out_calc_mem	; Get the base memory location of the led
		
		add	a,#001h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,@r0			; Get the value for the led (b)
		mov	r1,a			; Put value in r1 (b)
		
		mov	a,r5			; Get the base memory location of the led
		add	a,#002h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,@r0			; Get the value for the led (g)
		mov	r2,a			; Put value in r2 (g)
		
		mov	a,r5			; Get the base memory location of the led
		add	a,#003h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,@r0			; Get the value for the led (r)
		mov	r3,a			; Put value in r3 (r)
		
		mov	a,r5			; Get the base memory location of the led
		add	a,#000h			; Add the offset
		mov	r0,a			; Move the value adress in r0
		mov	a,@r0			; Get the value for the led (gl)
		mov	r0,a			; Put value in r0 (gl)
		
		lcall	APA102_led_frame
		
		mov	a,r4			; Led's that still need controll
		djnz	acc,led_api_out_loop	; Decrement and loop again
		
		lcall	APA102_end_frame
		pop	psw
		pop	acc
		
		ret

; Gets the next memory location and put this in r5
led_api_out_calc_mem:
		mov	a,#led_count		; Get the total number of led's
		subb	a,r4			; Subbtract the number of led's still need to command
		mov	b,#004h			; The offeset multiplier
		mul	ab			
		add	a,#LED_data_offset			; Add the base register
		mov	r5,a
		ret
		
;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; class: APA102
; APA102 driver and test of led-strip
;
; Necessary:
;	 Uses register bank 3
;	 CLK on 16 Mhz for delay1s function
;	 led_count defined for APA102_out_all
;	 port_map.0 for clk port (APA102)
;	 port_map.1 for data port (APA102)
;
; External functions: 
;	 Doesn't break acc
;	 Doesn't break register bank in normal use (not APA102_test function)
;	 Take use of register bank 3 for the APA102_test functions only
;	 Interupts allowed
; 
;	 delay1s: Do 1 sec no instructions
;
;	 APA102_test functions:
;		  APA102_test_led_strip: APA102_test the LED-strip
;		  APA102_test_led_strip_N: Set all the led's out
;		  APA102_test_led_strip_B: Set all the led's on blue
;		  APA102_test_led_strip_G: Set all the led's on green
;		  APA102_test_led_strip_R: Set all the led's on red
;		  APA102_test_led_strip_W: Set all the led's on white
;
;	 Led-strip drivers:
;		 APA102_out_all: Set same color on all the led's
;			  Arguments:
;				  r0: global brightness
;				  r1: blue
;				  r2: green
;				  r3: red
;
;	 APA102 drivers:
;		 APA102_start_frame: Sends the start frame out
;		 APA102_end_frame: Sends the end frame out
;		 APA102_led_frame: Sends one led frame
;			 Arguments:
;				 r0: global brightness (5bit MSB xxxgl glglglgl LSB)
;				 r1: blue (8bit MSB bbbb bbbb LSB)
;				 r2: green (8bit MSB gggg gggg LSB)
;				 r3: red (8bit MSB rrrr rrrr LSB)
;
;		 APA102_select_bit: sends the MSB in the acc to the APA102 and rotates the acc one time left
;			 Arguments:
;				 acc: the bit to send out.
;
;		 APA102_0: Sends a 0 bit to APA102
;		 APA102_1: Sends a 1 bit to APA102
;		 APA102_init: Initialization of port_map.0 (clk) and port_map.1 (data)
;
; Internal functions:
;
;	 delay1s:
;		 delay1s_loop1
;		 delay1s_looport_map
;
;	 APA102_out_all:
;		  APA102_out_all_loop
;
;	 APA102_select_bit:
;		 APA102_select_bit_0
;
;********************************************************************************************** 

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: delay1s
; Do 1 sec nothing
;
; Input: none
;
; Output: none
;
; Necessary:
;	 CLK on 16 Mhz
;
; Internal functions:
;	 delay1s_loop1
;	 delay1s_looport_map
;
;********************************************************************************************** 
		
delay1s:	
		push	acc
		mov	a,#004

delay1s_loop1:	
		mov	b,#250
		
delay1s_looport_map:	
 		lcall	delay2ms
		djnz	b,delay1s_looport_map
		djnz	acc,delay1s_loop1	
		
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_test_led_strip
; APA102 test the led-strip
;
; Input: none
;
; Output: colors on the led-strip
;
; Necessary:
;	 Uses register bank 3
;	 CLK on 16 Mhz for delay1s function
;
;********************************************************************************************** 
	
APA102_test_led_strip:	

		lcall	APA102_test_led_strip_R
		lcall	delay1s

		lcall	APA102_test_led_strip_G
		lcall	delay1s
		
		lcall	APA102_test_led_strip_B
		lcall	delay1s

		lcall	APA102_test_led_strip_W
		lcall	delay1s
		
		lcall	APA102_test_led_strip_N
		lcall	delay1s

		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_test_led_strip_N
; APA102 test the led-strip with setting all the led's on nothing
;
; Input: none
;
; Output: black on the led-strip
;
; Necessary:
;	 Uses register bank 3
;
;********************************************************************************************** 

APA102_test_led_strip_N:
		push	acc
		push	psw
		
		setb	psw.4
		setb	psw.3
		
		mov	r0,#000h
		mov	r1,#000h
		mov	r2,#000h
		mov	r3,#000h
		
		lcall	APA102_out_all
		
		pop	psw
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_test_led_strip_B
; APA102 test the led-strip with setting all the led's on blue
;
; Input: none
;
; Output: blue on the led-strip
;
; Necessary:
;	 Uses register bank 3
;
;********************************************************************************************** 

APA102_test_led_strip_B:
		push	acc
		push	psw
		
		setb	psw.4
		setb	psw.3
		
		mov	r0,#01Fh
		mov	r1,#0FFh
		mov	r2,#055h
		mov	r3,#000h
		
		lcall	APA102_out_all
		
		pop	psw
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_test_led_strip_G
; APA102 test the led-strip with setting all the led's on green
;
; Input: none
;
; Output: green on the led-strip
;
; Necessary:
;	 Uses register bank 3
;
;********************************************************************************************** 

APA102_test_led_strip_G:
		push	acc
		push	psw
		
		setb	psw.4
		setb	psw.3
		
		mov	r0,#01Fh
		mov	r1,#000h
		mov	r2,#0FFh
		mov	r3,#000h
		
		lcall	APA102_out_all
		
		pop	psw
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_test_led_strip_R
; APA102 test the led-strip with setting all the led's on red
;
; Input: none
;
; Output: red on the led-strip
;
; Necessary:
;	 Uses register bank 3
;
;********************************************************************************************** 

APA102_test_led_strip_R:
		push	acc
		push	psw
		
		setb	psw.4
		setb	psw.3
		
		mov	r0,#01Fh
		mov	r1,#000h
		mov	r2,#000h
		mov	r3,#0FFh
		
		lcall	APA102_out_all
		
		pop	psw
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_test_led_strip_W
; APA102_test the led-strip with setting all the led's on white
;
; Input: none
;
; Output: white on the led-strip
;
; Necessary:
;	 Uses register bank 3
;
;********************************************************************************************** 

APA102_test_led_strip_W:
		push	acc
		push	psw
		
		setb	psw.4
		setb	psw.3
		
		mov	r0,#01Fh
		mov	r1,#0FFh
		mov	r2,#0FFh
		mov	r3,#0FFh
		
		lcall	APA102_out_all
		
		pop	psw
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_out_all
; Put one color on all the led's
;
; Input: gl = Global brightness r0
;		b = blue r1
;		g = green r2
;		r = red r3
;
; Output: one color on all the led's
;
; Internal functions:
;	 APA102_out_all_loop
;
;********************************************************************************************** 

APA102_out_all:
		push	acc
		
		lcall	APA102_start_frame
		mov	a,#led_count

APA102_out_all_loop:
		lcall	APA102_led_frame		
		djnz	acc,APA102_out_all_loop
		lcall	APA102_end_frame
		pop	acc
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_start_frame	
; Start frame  to APA102 is: 00000000 00000000 00000000 00000000
;
; Input: none
;
; Output: none
;
;********************************************************************************************** 

APA102_start_frame:
		mov	a,#000h
		lcall	APA102_0_send_byte
		
		mov	a,#000h
		lcall	APA102_0_send_byte
		
		mov	a,#000h
		lcall	APA102_0_send_byte
		
		mov	a,#000h
		lcall	APA102_0_send_byte
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_end_frame
; End frame  to APA102 is: 11111111 11111111 11111111 11111111
;
; Input: none
;
; Output: none
;
;**********************************************************************************************

APA102_end_frame:
		mov	a,#0ffh
		lcall	APA102_0_send_byte
		
		mov	a,#0ffh
		lcall	APA102_0_send_byte
		
		mov	a,#0ffh
		lcall	APA102_0_send_byte
		
		mov	a,#0ffh
		lcall	APA102_0_send_byte
		
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_led_frame
; sends led frame to APA102 is: 111glglglglgl bbbbbbbb gggggggg rrrrrrrr
;
; Input: gl = Global brightness r0
;		b = blue r1
;		g = green r2
;		r = red r3
;
; Output: one led will light up
;
;********************************************************************************************** 

APA102_led_frame:
		push	acc
		mov	a,r0
		orl	a,#11100000b			;First 3 global bits not used
		lcall	APA102_0_send_byte
		
		mov	a,r1
		lcall	APA102_0_send_byte

		mov	a,r2
		lcall	APA102_0_send_byte
		
		mov	a,r3
		lcall	APA102_0_send_byte
		pop	acc
		ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: APA102_init
; Set clk and data port on zero
;
; Input: none
;
; Output: sends a initalisation signal to the APA102
;
; Necessary:
;	 port_map.0 for clk port (APA102)
;	 port_map.1 for data port (APA102)
;********************************************************************************************** 

APA102_init:	
		setb	port_map.0
		clr	port_map.1
		ret

;*********************************************************************************************
; Daniel Pauwels
;
; APA102_0_send_byte 
; Stuurt een databyte naar de SPI bus (MSB eerst) 
; Input  :  Acc - Databyte die verstuurd wordt, sd_clk moet al nul gemaakt zijn 
;
; Output : geen
;
; Internal functions:
;	 APA102_0_send_byte_0
;
; Necessary:
;	 port_map.0 for clk port (APA102)
;	 port_map.1 for data port (APA102)
;**********************************************************************************************

APA102_0_send_byte:
			push	b			;bewaar registers
			push	psw
			mov	b,#8			   	;bit teller

APA102_0_send_byte_0:
			rlc	a			;msb in c, cin lsb
			mov	port_map.1,c		 	;hoge bit naar sd_dout 
			clr	port_map.0				;negatieve flank van CLK puls genereren
			setb	port_map.0			 	;positieve flank van CLK puls genereren
			djnz	b,APA102_0_send_byte_0	;hele byte getransfereerd? nee: nog een bit
			pop	psw			;herstel registers
			pop	b
			ret
			
;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; class: buzzer
; plays a music on the buzzer
;
; Necessary:
;	 Uses timer 1
;	 CLK on 16 Mhz for timer 1
;	 Buzzer on buzzer port of i2c (lcd)
;
; External functions: 
;	Doesn't break acc
; 
;	buzzer_music_init: Set the buzzer sound off
;	nuzzer_music: Set the buzzer music on
;	buzzer_on: Set the buzzer on
;	buzzer_off: Set the buzzer off
;
; Internal functions:
;	 buzzer_intr
;	 buzzer_intr_2
;	 buzzer_intr_3
;	 buzzer_intr_exit
;********************************************************************************************** 

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: buzzer_music_init
; Stops the music on the buzzer
;
; Necessary:
;	 Buzzer on buzzer port of i2c (lcd)
;
; Input: none
;
; Output: Buzzer off
;
;********************************************************************************************** 

buzzer_music_init:
	lcall	buzzer_off
	ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: buzzer_music
; Plays the music on the buzzer
;
; Necessary:
;	 Uses timer 1
;	 CLK on 16 Mhz for timer 1
;	 Buzzer on buzzer port of i2c (lcd)
;
; Internal functions:
;	 buzzer_intr:
;	 buzzer_intr_2
;	 buzzer_intr_3
;	 buzzer_intr_exit
;
; Input: none
;
; Output: Buzzer on
;
;********************************************************************************************** 

buzzer_music:
	mov	timer1_count,#000h	; Starts the music clock
	mov	a,tmod
	orl	a,#00000001b
	mov	tmod,a
	clr	tr1
	mov	tl1,#000h
	mov	th1,#000h
	setb	tr1			; We can now send assymetric music out
	setb	et1
	setb	ea
	clr	Buz_flag
	ret
	
buzzer_intr:
	push	acc
	push	psw
	clr	tr1
	mov	tl1,#000h
	mov	th1,#000h
	setb	tr1
	jb	Buz_flag,buzzer_intr_exit
	lcall	buzzer_off
	
	mov	a,total_alarm_time
	subb	a,examen_time
	subb	a,timer1_count
	jnc	buzzer_intr_2		; Sends for every minute a beep out
	clr	tr1			; Then we stop
	lcall	buzzer_off
	sjmp	buzzer_intr_exit
buzzer_intr_2:
	mov	a,timer1_count
	inc	timer1_count
	anl	a,#00010000b
	jz	buzzer_intr_3
	lcall	buzzer_on
	sjmp	buzzer_intr_exit
	
buzzer_intr_3:
	lcall	buzzer_off
	
buzzer_intr_exit:
	pop	psw
	pop	acc
	reti


;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: buzzer_on
; Sets the buzzer on
;
; Input: none
;
; Output: Buzzer on
;
;********************************************************************************************** 
buzzer_on:
if DIL_ADuC832 = 1
	clr	port_map.2
else
	lcall	lcdbuzon
endif
	ret

;********************************************************************************************** 
; Stijn Goethals and Nele Annaert (C) 2016
; function: buzzer_off
; Sets the buzzer off
;
; Input: none
;
; Output: Buzzer off
;
;********************************************************************************************** 
buzzer_off:
if DIL_ADuC832 = 1
	setb	port_map.2
else
	lcall	lcdbuzoff
endif
	ret

$INCLUDE (c:/aduc800_mideA.inc)
end