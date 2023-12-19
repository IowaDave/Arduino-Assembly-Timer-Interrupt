# Arduino-Assembly-Timer-Interrupt
**An assembly-only approach to a timer interrupt for an AVR-based Arduino**.

Situation: You want to include a timer interrupt service routine in an assembly language program for an AVR-based Arduino. The program will be written, assembled and uploaded using the Arduino IDE.

Information is available online but scattered about. It's a scavenger hunt. This article aims to pull the pieces together into a straightforward tutorial with a worked example. A list of references is provided at the end.

**Why Assembly?** Because it's there. Heck, why not? Look in the dictionary. "Learning" does not end with "C".

The example program is designed to run on a traditional Arduino Uno having an ATmega328P microcontroller clocked by a 16 MHz external crystal.

Timer/Counter1 is configured to generate an interrupt recurring at a specified frequency. The interrupt service routine initiates an action upon each occurrence. 

As is traditional for tutorials like this, the action is simply to toggle the onboard LED.

## How the Arduino IDE Does Assembly
It uses the GNU-ASM Assembler, just as it uses the GCC Compiler to process C and C++ code files. Both the Assembler and the Compiler produce object files that are then brought together by the Linker.

A reference for the Assembler is included at the end of this article. You'll also need the AVR Instruction Set Manual. I keep both of them open, along with the Data Sheet for the ATmega328P, when writing assembly programs. 

## Assembly-only Programming in the Arduino IDE
Start a new project as usual. Delete all contents from the editor window. I like to replace the contents with a single comment stating that this is an assembly-language project.

Create a new tab. Give the tab a name ending with the suffix, ".S". It must end with ".S". Why?

The IDE determines how to process each file in the project by examining its suffix.

".S" tells the IDE two things: 1) that the file contains only assembly code; and 2) that the code is able to participate in a C++ environment.

Begin the file by personalizing it for the target microcontroller.

```#include <avr/io.h>```

Note that the Arduino IDE will configure that "include" file based on the Board selection.

In this example, choosing **Tools > Board > AVR Arduino Boards > Arduino Uno** will configure the "io.h" file automatically for the ATmega328P.

Next, tell the IDE not to bring in any of the usual Arduino Core Library code. This is done by defining the "main" code block globally from within the assembly file. There must be a "main" code block. Arduino inserts its own C++ code for "main" into programs that do not define one. 

```
.global main	; tell the IDE to use this "main" rather than its C++ -based default
main:		; label the start of the main code block
```

Write the program entirely in that ".S" file, using only Assembly language. Follow the syntax spelled out in the AVR Instruction Manual, the GNU Assembler Manual and the ATmega328P Data Sheet. Compile and upload it the same, familiar way as done for programs written in C/C++, even though the main ".ino" file is empty.


## Interrupt Service Routine in Assembler
The Mazidi-Naimi book (listed in References, below) describes a four-step sequence following activation of an interrupt. Summarized, they are:

1. Finish the current instruction and save the address of the next instruction onto the stack.

2. Jump to a fixed location in a *interrupt vector table* encoded within the program's flash memory.   That location in turn directs program execution to the user-designated interrupt service routine (ISR).

3. Execute the ISR, until reaching the mandatory, concluding RETI instruction (RETurn from Interrupt).

4. Upon executing the RETI instruction, pull from the stack the address of the next instruction following the place where the interrupt occurred. Resume regular program execution with that instruction.


An assembly programmer faces two challenges here. Three, actually, when using the Arduino IDE.

&nbsp;&nbsp;&nbsp;&nbsp;First, how to designate which code belongs to the ISR.

&nbsp;&nbsp;&nbsp;&nbsp;Second, how to point the vector table to that code.

&nbsp;&nbsp;&nbsp;&nbsp;Third, how to do so specifically with Arduino IDE.


One answer satisfies all three challenges. 

In the example, the counter overflow of Timer1 generates an interrupt. The Data Sheet names this one the TIMER1\_OVF interrupt. 

Arduino IDE knows its entry in the vector table by the special name, "TIMER1\_OVF\_vect". 

Use this name twice in succession: first, to make it known globally in the surrounding C++ world of the Arduino IDE; then second, to label the start of the ISR code block.

```
.global TIMER1_OVF_vect	; give the name global scope in the program
TIMER1_OVF_vect:		; label the start of the ISR code with the same name
```

Then follow the label with the code for the ISR, concluding it with the RETI instruction.

```
reti
```

The Assembler, Compiler and Linker will prepare the interrupt vector table so that it directs the microcontroller to the ISR. 

That is simply the Arduino Way. There is no other practical way for user-written code to place the ISR address into the interrupt vector table, because user code cannot write to the program flash memory where the vector table is stored.

By the way, the Arduino IDE uses the same naming syntax when designating an ISR in a C++ code body. The ISR() macro processes the name of the procedure:

```
ISR(TIMER1_OVF_vect)
{

}
```

## ISRs and the Stack
Developers should take note of a difference between the ISR() macro in C++ compared to the way the Assembler handles things. 

The C macro "wraps" the ISR code between a preamble that pushes certain values onto the stack and a postcript that pops them off and restores them to their respective locations. 

By contrast, the Assembler does not.

To illustrate, here is an ISR in C++ that toggles pin PB5, the one tied to Digital Pin 13, the onboard LED of an Arduino Uno.

```
ISR(TIMER1_OVF_vect)
{
  PINB = (1<<PINB5);
}
```

The following is a disassembly of the code produced by the Compiler. Note that "\_\_vector\_13" is synonymous with TIMER1_OVF.

```
00000124 <__vector_13>:
 # preamble, push certain values onto the stack
 124:	1f 92       	push	r1
 126:	0f 92       	push	r0
 128:	0f b6       	in	r0, 0x3f		; the STATUS register
 12a:	0f 92       	push	r0
 12c:	11 24       	eor	r1, r1
 12e:	8f 93       	push	r24

 # actual interrupt handling code
# toggle the LED by writing "1" to bit 5 of the PINB register
 130:	80 e2       	ldi	r24, 0x20	; 0b00100000 = bit 5's position
 132:	83 b9       	out	0x03, r24	; write it to I/O register 3, PINB

 # postscript, restore values from the stack, in the reverse order of saving
 134:	8f 91       	pop	r24
 136:	0f 90       	pop	r0
 138:	0f be       	out	0x3f, r0	
 13a:	0f 90       	pop	r0
 13c:	1f 90       	pop	r1

 13e:	18 95       	reti			; return from the interrupt

```

The Assembler will encode only the code that actually toggles the LED, like this:

```
# code as written in the Arduino IDE editor

.global TIMER1_OVF_vect
TIMER1_OVF_vect:
  ldi r24, (1<<PINB5)
  out PINB-0x20, r24
  reti

# disassembly of the resulting code after compilation

00000084 <__vector_13>:
  84:	80 e2       	ldi	r24, 0x20
  86:	83 b9       	out	0x03, r24
  88:	18 95       	reti
```

It means that the program writer must exercise due care to save and restore any operationally important data registers that might get changed during execution of the ISR. 

The Status Register and any general purpose registers that may get changed during the ISR, such as r24 in this example, should be considered for preservation.

## The Example Program

All of the program code is in the tab named "assembly.S".

It begins by importing a set of definitions for the ATmega328P target.

Three ".equ" assembler directives define macros for certain constants, making it possible to refer to them by name in the code. They are:

* ```.equ DIV1024, 0b101``` used to "prescale" (divide) the 16 MHz system clock frequency by 1024, so that Timer1 receives only 15625 "clocks" per second.

* ```.equ DELAY, 15625/4``` defines the number of clocks making up the desired interval of time between interrupts. In this case, the interval will be 1/4 of a second.

* ```.equ START_COUNT, ((2^16) - DELAY)``` subtracts the number of clocks in the interval from the overflow value of the Timer1 counter. The macro resolves as a value that will be written into the Timer's counter at the start of each successive interval.

Program code follows after the label, "main:" Understanding this code requires reference to the Data Sheet and the AVR Instruction Manual.

* Pin PB5 is set to OUTPUT.
* Power is turned on to the Timer/Counter1 peripheral.
* Timer1 is halted and initialized to operate in "normal mode".
* The counter register in Timer1 is given its initial value.
* The timer's overflow flag is cleared.
* The overflow interrupt is enabled.
* Interrupts are then enabled globally.
* Timer1 is started by writing the prescale value.

The main "loop" is empty. All this code does is to repeat itself. It is like leaving the "loop()" part of a regular Arduino program empty.

Comes finally the ISR. 

* The LED pin is toggled with a single instruction, ```sbi PINB-0x20, PINB5```.
* Timer1's counter register is re-initialized to start the next interval.
* The ISR returns from the interrupt.

## Conclusion
I hope that study of this example may reward the reader with a better understanding of how to write an Arduino program using only Assembly language and how to include interrupt service routines in it.

Discussion of advantages and disadvantages for using interrupts or for writing programs in Assembly lay thick on the ground all across the Internet and need no regurgitation here.

## References
Elsner, Dean; Fenlason, Jay; et. al. "The gnu Assembler (Sourcery G++ Lite 2010q1-188) Version 2.19.51". 2009. The Free Software Foundation. PDF file available for free download online.

"AVR® Instruction Set Manual", version DS40002198A. 2020. Microchip Technology Inc. PDF file available for free download online.

"megaAVR® Data Sheet" (for ATmega48A/PA/88A/PA/168A/PA/328/P), version DS40002061B. 2020. Microchip Technology Inc. PDF file available for free download online.

Mazidi, Muhammad Ali; Naimi, Sepehr; Naimi, Sarmad. "The AVR Microcontroller and Embedded Systems Using Assembly and C". Second Edition (Based on ATmega328 and Arduino Boards). 2017. ISBN-13: 978-0997925968. ISBN-10: 0997925965. Appears to be self-published. Previous (first) edition published by Pearson Education, Inc. A very good book, in print at the time of this writing and available for purchase from Amazon and possibly others.

Note that Mazidi and Naimi use the Atmel Studio Assembler which has a different set of directives and style in contrast to the GNU Assembler used by the Arduino IDE. I have Atmel Studio on a Windows machine and intend to explore it someday. When I do, it will be their book that guides me. For the time being, Arduino IDE on my Mac satisfies my amateur requirements.

Here are some links I found helpful, that were still active at the time of writing in December 2023.

* [An online version of the GNU Assembler Manual](https://sourceware.org/binutils/docs/as/index.html)

* [AVR Asm - 101, an introduction written for beginners](https://jaxcoder.com/Post/Index?guid=3cf50808-430f-4d55-992e-856930a33864)

* [Microchip's online AVR Assembler manual. It's written for the Atmel Studio assembler.](https://onlinedocs.microchip.com/pr/GUID-E06F3258-483F-4A7B-B1F8-69933E029363-en-US-2/index.html)

* [A discussion of the Stack Pointer, which might be important. I don't know, yet.](http://www.rjhcoding.com/avr-asm-functions.php)

* [Combining C and assembly source files, from the AVR-LIBC repository at nongnu.org. These are the nice people behind the Arduino Core libraries. They know a thing or two.](https://www.nongnu.org/avr-libc/user-manual/group__asmdemo.html)
