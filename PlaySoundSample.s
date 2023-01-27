;------------------------------
; Play a sound sample.
;
; AUD0PER is set using the Clock Constant / Sample Rate in Hz
; e.g. 3546895 / 16000 = 221
;
; Samples add an interrupt handler, this plays an empty
; sample and increments a count so we can test this and know
; we are safe to exit if the value is 2 or more.
;
;---------- Includes ----------
		INCDIR      "include"
		INCLUDE     "hw.i"
		INCLUDE     "funcdef.i"
		INCLUDE     "exec/exec_lib.i"
		INCLUDE     "graphics/graphics_lib.i"
		INCLUDE     "hardware/cia.i"
;---------- Const ----------

CIAA            EQU	$bfe001
ExecSupervisor	EQU	-30
exec_AttnFlags	EQU	296
IRQ4			EQU	$70

init:
		movem.l d0-a6,-(sp)				 save registers

		move.l	4.w,a6					; Execbase in a6
		sub.l	a0,a0					; zero a0, this will hold the VBR (vector base register). On a 68000 this is always 0
		btst.b	#0,exec_AttnFlags(a6)	; check if 68010 processor or above
		beq.b	.NoVBR					; skip if just a 68000
		lea.l	GetVBR(PC),a5			; function to call as supervisor
		jsr		ExecSupervisor(a6)		; call supervisor function in a5
		move.l	d0,a0					; a0 = VBR (vector base register), not always 0 if 68010 or above
.NoVBR:
		lea		CUSTOM,a5				; load the base of the custom chip registers into a5
		move.w	INTENAR(a5),d7			; store original INTENA value	
		or.w	#$8000,d7				; set the SET bit
		move.l	IRQ4(a0),OldVector		; store the original interrupt vector

		move.l	#AudioHandler,IRQ4(a0)	; set the new interrupt vector 
		move.w	#$8080,INTENA(a5)		; enable interupt for audio channel 0


		; turn off the audio
		move.w	#$0001,CUSTOM+DMACON	; DMACON disable audio channel 0

		; load our sample up in audio channel 0.
		lea.l	sample,a1				; move sample address into a1
		move.l	a1,CUSTOM+AUD0LC		; AUD0LCH/AUD0LCL set audio channel 0 location to sample address
		move.w	#7941,CUSTOM+AUD0LEN	; AUD0LEN set audio channel 0 length to 7941 words (twice number of bytes in sample)
		move.w	#221,CUSTOM+AUD0PER		; AUD0PER set audio channel 0 period to 221 clocks (less is faster)
		move.w	#64,CUSTOM+AUD0VOL		; AUD0VOL set audio channel 0 volume to 64 (64 is max volume)

		; enabling audio on DMACON plays the sample.
		move.w	#$8001,CUSTOM+DMACON	; DMACON enable audio channel 0

.wait
		move.w	AIH_Count,d0			; get the audio interrupt count	
		cmpi.w	#2,d0					; if two interupt have occured, we can end
		bge		.end				
		btst	#6,CIAA					; wait for the left mouse button
		bne.s	.wait					; not pressed? loop back to .wait

.end
		; turn off the sound
		move.w	#$0001,CUSTOM+DMACON	; DMACON disable audio channel 0
		move.w	#$0080,CUSTOM+INTENA	; disable interrupt for audio channel 0
		move.l	OldVector(PC),IRQ4(a0)	; restore original interrupt vector
		move.w	d7,INTENA(a5)			; restore interrupts

		movem.l	(sp)+,a6-d0				; restore registers
		moveq.l	#0,d0					; 0 means all OK
		rts								; return to the OS

;---------------------------------------------------------------
; Get the vector base register for 68010 processors and above.
GetVBR:
		dc.l	$4e7a0801				; movec vbr,d0	(68010 and above)
		rte								; note rte as run from supervisor mode

;---------------------------------------------------------------

AudioHandler:
		move.w	#$0080,CUSTOM+INTREQ	; acknowledge interrupt
		move.l	#emptysample,CUSTOM+AUD0LC	; next audio location, silence
		move.w	#1,CUSTOM+AUD0LEN		; 1 word of data (2 bytes)
		addq.w	#1,AIH_Count			; increment the count, we check this in the main loop to know it's safe to stop.
		rte								; note rte as run from interrupt

;---------------------------------------------------------------

AIH_Count:
		dc.w	0						; used to store how many times the audio interrupt has occured.
OldVector:
		dc.l	0						; store the original interrupt vector		

;---------------------------------------------------------------

		SECTION soundsample,DATA_C

emptysample:
		dc.w	0					; an empty single word sample.
sample:
		INCBIN	"ThisIsTheWay.raw"	; exported as RAW 8bit signed PCM