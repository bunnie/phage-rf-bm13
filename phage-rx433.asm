;= phage-rx433.asm =============================================================
;
; Copyright (C) 2004 Nordic Semiconductor / (c) 2013 bunnie
;
; This file is distributed in the hope that it will be useful, but WITHOUT
; WARRANTY OF ANY KIND.
;
; Author(s): Ole Saether (original reference); bunnie (mod for phage);
;	Paul Stoffregen (rand16 library)
;
; DESCRIPTION:
;
; 	Derived from Nordic reference code, modified for phage application 	
;
; ASSEMBLER:
;
;   You need as31.exe to assemble this program. It can be downloaded from this
;   web page: http://www.pjrc.com/tech/8051/
;
; $Revision: 2 $
;
;===============================================================================

	;;  LED 4 for debug = P0.6
        .equ  EXIF, 0x91
        .equ  P0_DIR, 0x94
        .equ  P0_ALT, 0x95
        .equ  P1_ALT, 0x97
        .equ  SPI_DATA, 0xb2
        .equ  SPI_CTRL, 0xb3
        .equ  SPICLK, 0xb4

	.equ  STB_CHAR, 0xC3
	.equ  FRIEND_CHAR, 0xA1
	.equ  RAND_DIVISOR, 0x2

	.equ	rand16reg, 0x20		;two bytes
	.equ    randval, 0x22		;two bytes
	.equ    randdiv, 0x24

        ljmp  start

start:
	acall init
        clr   P2.4            ; TXEN = 0

rxpacket:
	setb  P2.5            ; TRX_CE = 1
waitdr:
	;; check to see if the strobe button was pressed
	mov   a, P0		; read port 0 register
	;;  port 0.3 is the NRF switch. 0 = depressed, 1 = idle
	mov   c, P0.3
	jnc   txstrobe

	;; slow down the interval by a factor loaded into randdiv
	mov   a, randdiv
	clr  c
	subb a, #1
	mov  randdiv, a
	jnz  main_cont2
	mov randdiv, #RAND_DIVISOR
	
	;; now, check if our random number generator has reached zero.
	mov   a, randval+1  	; first check msb
	jnz   main_cont
	mov   a, randval	; then check lsb
	jnz   main_cont

	ajmp  do_friend
	
main_cont:
	;; decrement random wait by 1
	mov   a, randval	; then check lsb
	clr   c
	subb  a, #1 		; subtract one
	mov   randval, a
	mov   a, randval+1
	subb  a, #0		; factor in the carry
	mov   randval+1, a

main_cont2:
	;; keep waiting for receive
	jnb   P2.5, waitdr    ; Wait for DR = 1

	;; !! we've received something, retrieve it !!
        clr   P2.3            ; RACSN = 0
        mov   a, #0x24        ; R_RX_PAYLOAD
        acall spi_wr
        mov   a, #0
        acall spi_rd
        setb  P2.3            ; RACSN = 1
        clr   P2.5            ; TRX_CE = 0

	;; received character is in a
        mov   r5, a		; store the character in r5
	clr   c
	subb  a, #STB_CHAR
	jz    strobe_action
	mov   a, r5		; recall the character
	clr   c
	subb  a, #FRIEND_CHAR
	jz    friend_action
        ajmp  rxpacket

strobe_action:			; strobe is P0.2
	clr   P0.2
	acall sig_delay
	setb  P0.2
	ajmp  rxpacket

friend_action:			; friend is P0.4
	clr   P0.4
	acall sig_delay
	setb   P0.4
	ajmp  rxpacket

txstrobe:
	;; first check for CD
tx_wait_clear:
	mov c, P2.6	
	jc tx_wait_clear

	;; now transmit knowing there is no carrier detect
        setb  P2.4            ; TXEN = 1

	clr   P2.3            ; RACSN = 0
        mov   a, #0x20        ; W_TX_PAYLOAD
        acall spi_wr
        mov   a, #STB_CHAR  	; transmit the 'strobe' character
        acall spi_wr
        setb  P2.3            ; RACSN = 1        setb  P2.5            ; TRX_CE = 1
        acall delay400

;        clr   P2.5            ; TRX_CE = 0
        clr   P2.4            ; TXEN = 0

	acall sig_delay 	; give the airways time to breathe when strobing
	acall sig_delay

        ajmp  rxpacket

init:
	mov   P0_ALT, #0x00
        mov   P0_DIR, #0xAB	; 0 is output. bits 2 & 4 are output, so 1010_1011
	;; bit 6 also being used for debug status, but not used in final board
        mov   SPICLK, #0x00
        mov   SPI_CTRL, #0x02

	mov   P0, #0x54 	; initial P0 states should be high, so 0101_0100

	;; clear the RNG current value register
	mov randval, #0x00
	mov randval+1, #0x10
	mov randdiv, #RAND_DIVISOR	;initial divisor for rand number generator

        clr   P2.3            ; RACSN = 0
        mov   a, #0x03        ; Config address 3 (Rx payload)
        acall spi_wr
        mov   a, #0x01        ; One byte Rx payload
        acall spi_wr
        mov   a, #0x01        ; One byte Tx payload
        acall spi_wr
        setb  P2.3            ; RACSN = 1
	
        ;; Configure frequency and power
        clr   P2.3            ; RACSN = 0
        mov   a, #0x11        ; Read config address 1
        acall spi_wr
        acall spi_wr          ; Read config byte
        mov   r0, a
        setb  P2.3            ; RACSN = 1

        clr   P2.3            ; RACSN = 0
        mov   a, #0x01        ; Write config address 1
        acall spi_wr
        mov   a, r0
        anl   a, #0xf1	; 1111 0001
        orl   a, #0x08        ; Max power, 433MHz = 1100, -2dBm, 433MHz = 0100
	;; 6dBm, 433MHz = 1000
        acall spi_wr
        setb  P2.3            ; RACSN = 1
	
        ret

delay400:
	mov   r7, #130 ; 4 MHz CPU speed, 3 cycles per djnz 13 clocks = 123 cycles/400us
delay401:
	djnz  r7, delay401
        ret

sig_delay:			; target a delay of 10ms = 10k instruction cycles
	mov r6, #12		; 12 ms total -- est 9ms for 5m attiny85 drive loop
sig_delay2:	
	mov r7, #250		; 1 inner loop is 1 ms
sig_delay1:
	nop			; 1 cycle
	djnz r7, sig_delay1	; 3 cycles
	djnz r6, sig_delay2
	ret

spi_rd:
spi_wr:
	anl   EXIF, #0xdf     ; Clear SPI interrupt
        mov   SPI_DATA, a     ; Move byte to send into SPI_DATA
spi_rdwr1:
	mov   a, EXIF         ; Wait until...
        jnb   acc.5, spi_rdwr1; ...SPI_RX bit is set
        mov   a, SPI_DATA     ; Move byte received into acc
        ret

ledflash:
	clr P0.6
	acall sig_delay
	setb P0.6
	acall sig_delay
	ajmp ledflash


ledpulse:
	clr P0.6
	acall sig_delay
	setb P0.6
	acall sig_delay
	ret

do_friend:
	acall rand16		; get a random number
	mov  randval, a 	; lsb
	orl  b, #0x80		; guarantee a minimum delay
	mov  randval+1, b	; msb

	acall ledpulse
	
friend_wait_clear:
	mov c, P2.6	
	jc friend_wait_clear

	;; now transmit knowing there is no carrier detect
        setb  P2.4            ; TXEN = 1

	clr   P2.3            ; RACSN = 0
        mov   a, #0x20        ; W_TX_PAYLOAD
        acall spi_wr
        mov   a, #FRIEND_CHAR  	; transmit the 'friend' character
        acall spi_wr
        setb  P2.3            ; RACSN = 1
        setb  P2.5            ; TRX_CE = 1
        acall delay400
        clr   P2.5            ; TRX_CE = 0
	
        clr   P2.4            ; TXEN = 0
        ajmp  rxpacket
	

rand16:
	mov	a, rand16reg
	jnz	rand16b
	mov	a, rand16reg+1
	jnz	rand16b
	cpl	a
	mov	rand16reg, a
	mov	rand16reg+1, a
rand16b:
	anl	a, #11010000b
	mov	c, p
	mov	a, rand16reg
	jnb	acc.3, rand16c
	cpl	c
rand16c:
	rlc	a
	mov	rand16reg, a
	mov	b, a
	mov	a, rand16reg+1
	rlc	a
	mov	rand16reg+1, a
	xch	a, b
	ret
