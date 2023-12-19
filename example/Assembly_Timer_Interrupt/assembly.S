/*
  Assembly_Blink_Interrupt
  Copyright (c) 2023 David G Sparks.  All right reserved.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

  Designed to run on a traditional Arduino Uno 
  having an ATmega328P processor
  clocked at 16 MHz by an external crystal.

  Select the Uno using the Arduino IDE Tool Menu:
  Tools > Board > Arduino AVR Boards > Arduino Uno
*/

#include <avr/io.h>

.equ DIV1024, 0b101         ; prescaler value for /1024

# The timer is operating in normal mode,
# receiving 15,625 clocks/second.
# 1/4 second is 15625/4 clocks.
.equ DELAY, 15625/4

# Start and restart the counter at 2^16 - DELAY.
# Subtract DELAY from 2^16
# and write the difference to the counter register.
.equ START_COUNT, ((2^16) - DELAY)

.global main
main:

  # initialize Uno onboard LED (PB5) to output
  sbi DDRB-0x20, DDB5       ; write pin 5 to logic 1

  # initialize Timer1
  lds r16, PRR              ; read PRR
  cbr r16, (1<<PRTIM1)      ; clear bit to enable Timer1
  sts PRR, r16              ; write PRR
  ldi r16, 0                ; initial value for these registers
  sts TCCR1B, r16           ; zero stops Timer
  sts TCCR1A, r16           ; normal mode, no compare outputs
  sts TCCR1C, r16           ; no forced comparisons
  sts TIMSK1, r16           ; turn off Timer 1 interrupts
  # initialize the timer counter
  ldi r16, hi8(START_COUNT) ; write the high byte first
  sts TCNT1H, r16
  ldi r16, lo8(START_COUNT) ; then write the low byte
  sts TCNT1L, r16  
  # clear the overflow flag
  ldi r16, (1<<TOV1)      ; write TOV1 bit logic 1
  out (TIFR1-0x20), r16   ; to clear the Timer1 OVF flag
  # enable the overflow interupt
  lds r16, TIMSK1
  ori r16, (1<<TOIE1)
  sts TIMSK1, r16
  # enable global interrupts
  sei
  # start the timer by writing prescale value for /1024
  ldi r16, 0 + DIV1024    ; for normal mode, prescale /1024
  sts TCCR1B, r16         ; write this value to TCCR1B
  
loop:
  rjmp loop

.global TIMER1_OVF_vect
TIMER1_OVF_vect:
  # Timer1 Overflow interrupt has occurred.
  
  # toggle the LED
  sbi PINB-0x20, PINB5
  
  # re-initialize the timer counter
  ldi r16, hi8(START_COUNT) ; write the high byte first
  sts TCNT1H, r16
  ldi r16, lo8(START_COUNT) ; then write the low byte
  sts TCNT1L, r16  
  
  reti
  

  
