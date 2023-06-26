.syntax unified
.global main

@ GPIOTE Constants
.set GPIOTE_EVENTS_IN0, 0x40006100
.set GPIOTE_INTENSET, 0x40006304
.set GPIOTE_CONFIG0, 0x40006510

@ NVIC Constants
.set NVIC_ISER0, 0xE000E100

.set RNG, 0x4000D000
.set RNG_OUTPUT, 0x4000D508 

@ Render overall times
.set RENDER_OVERALL_TIME, 0x500

@ Number of frames before the game changes state
.set SHIFT_CYCLE, 0x20 

@ Brightness value of the dropper, the higher the value the dimmer
.set DROPPER_BRIGHTNESS, 0x10 


.type main, %function
main:
  bl init_leds

  @ Starts the random number generator
  ldr r0, =RNG
  ldr r1, =0xFFFF
  str r1, [r0]

  @ button interrupt configurations
  ldr r0, =GPIOTE_CONFIG0
  ldr r1, =(1 | 14 << 8 | 1 << 16) @ |
  str r1, [r0]

  add r0, r0, 0x4
  ldr r1, =(1 | 23 << 8 | 1 << 16) @ |
  str r1, [r0]

  ldr r0, =GPIOTE_INTENSET
  ldr r1, =0b11
  str r1, [r0]

  ldr r0, =NVIC_ISER0
  ldr r1, =(1 << 6)
  str r1, [r0]

  ldr r8, =image
gameloop:
  @ sets start of render clock
  ldr r5, =RENDER_OVERALL_TIME
  @ sets render interval
  mov r6, #6
  udiv r7, r5, r6 

  @============================
  @ -1 to the shift_clock
  ldr r0, =shiftclock 
  ldr r1, [r0]
  sub r1, r1, #1
  str r1, [r0]
  @ compares shiftclock to 0
  cmp r1, #0
  bne render
  bl shift_down
render:
  @ sub 1 to render clock
  subs r5, r5, 1

  @ once render has finished, returns back to gameloop
  bmi gameloop 

  @ if render has not finished, renders the image
  @ Address of image
  ldr r8, =image

  @ interval comparer
  mov r3, #0
  @ ===========================================
  ldr r0, [r8, #4]!
  mov r1, 0b00001
  mov r6, #5
repeat:
  @ once render interval has hit 0 render cycle has ended
  cmp r6, #0
  beq render
  
   @ column index
  ldr r2, [r8, #4]!
   @ column image
  ldr r0, [r8, #4]!

  @ if dropper column matches
  push {r1}
  ldr r1, =dropper
  ldr r1, [r1]
  cmp r2, r1
  bne repeatcontinue

  @ if render clock is divisible by 10 (pulse width modulating)
  ldr r1, =DROPPER_BRIGHTNESS
  udiv r2, r5, r1
  mul r2, r2, r1
  cmp r2, r5
  bne repeatcontinue

  @ generates dropper
  push {r1,r2,r3}
  bl shift_bit
  pop {r1,r2,r3}

repeatcontinue:
  @ set column
  pop {r1}

  @ compares interval comparer with render clock
  add r3, r7, r3
  cmp r5, r3
  blt light1 
  
  sub r6, r6, #1
  lsl r1, #1
  b repeat

light1:
  push {r1}
  bl write_row_pins
  pop {r0}
  bl write_column_pins
  b render
  mov r6, #0
.size main, .-main

.type shift_bit, %function
shift_bit:
  push {r4}

  @ which bit to shift
  ldr r1, =dropper
  ldr r2, [r1, 4]

  mov r3, 0b1
  lsl r3, r3, r2
  orr r0, r0, r3 @ actual frame

  ldr r3, =shiftclock
  ldr r3, [r3] 
  ldr r4, =SHIFT_CYCLE
  sub r4, r4, 1
  cmp r3, r4
  bne shift_end
  
  @ generates what the column will look like on the next frame
  mov r3, 0b1
  sub r2, r2, 1
  lsl r3, r3, r2
  orr r1, r0, r3 @ next frame

  @ if next frame and actual frame are the same (collision), stores the value
  cmp r1, r0
  beq store
  b shift_end
store:
  @ sets store_flag to 1
  ldr r2, =store_flag
  mov r1, 1
  str r1, [r2]

  @ stores frame into image
  str r0, [r8]
shift_end:
  pop {r4}
  bx lr

.size shift_bit, .-shift_bit

.type row_remove, %function
row_remove:
  ldr r0, =image
  mov r2, 0b11111

row_repeat:
  @ performs and "and" operation on all the columns
  ldr r1, [r0, 4]
  and r2, r2, r1
  ldr r1, [r0]
  cmp r1, #0x5
  beq row_com
  ldr r1, [r0, 8]!
  b row_repeat

row_com:
  @ compares result with #1
  cmp r2, #1

  @ if result == #1 zeroes out the entire first row
  beq zero_out
  b row_end

zero_out:
  ldr r0, =image
  ldr r1, [r0, 8]!
  mov r2, #1

zero_out_repeat:
  ldr r1, [r0, 4]
  lsr r1, r1, r2
  str r1, [r0, 4]
  ldr r1, [r0]
  cmp r1, #0x5
  beq row_end
  ldr r1, [r0, 8]!
  b zero_out_repeat
row_end:
  bx lr
.size row_remove, .-row_remove

.type shift_down, %function
shift_down:
  @ reset shift_clock
  ldr r0, =shiftclock
  ldr r1, =SHIFT_CYCLE 
  str r1, [r0]

  @ reduces dropper by 1
  ldr r1, =dropper
  ldr r2, [r1, 4]
  sub r2, r2, #1
  str r2, [r1, 4]

  @ if store flag has been set resets the dropper
  ldr r1, =store_flag
  ldr r1, [r1]
  cmp r1, #1
  beq reset_shifting
  bx lr

reset_shifting:
  ldr r1, =store_flag
  mov r2, 0
  str r2, [r1]
  push {lr}
  push {r0, r1, r2}
  bl row_remove
  pop {r0, r1, r2}
  
  @ generate a random column between 1 and 5 for the dropper to start at
  push {r4}
  ldr r4, =RNG_OUTPUT
  ldr r4, [r4]
  mov r2, #5
  udiv r1, r4, r2
  mul r2, r1, r2
  sub r4, r4, r2
  add r4, r4, #1

  ldr r1, =dropper
  str r4, [r1]
  ldr r2, = 0x5
  str r2, [r1, 4]
  pop {r4}
  pop {lr}
  bx lr
.size shift_down, .-shift_down



.global GPIOTE_IRQHandler
.type GPIOTE_IRQHandler, %function
GPIOTE_IRQHandler:
  ldr r0, =GPIOTE_EVENTS_IN0
  ldr r0, [r0]

  @ if left button is pressed, subtracts dropper column by 1, 
  @ if right button is pressed, adds dropper column by 1
  cmp r0, #1
  beq gpiote_sub
gpiote_add:
  @ clear event
  ldr r0, =GPIOTE_EVENTS_IN0
  ldr r1, =0
  str r1, [r0]
  str r1, [r0, 4]
  
  ldr r1, =dropper
  ldr r2, [r1]
  add r2, r2, #1
  cmp r2, #5
  bgt gpiote_finish
  str r2, [r1]
  bx lr
gpiote_sub:
  @ clear event
  ldr r0, =GPIOTE_EVENTS_IN0
  ldr r1, =0
  str r1, [r0]
  str r1, [r0, 4]

  ldr r1, =dropper
  ldr r2, [r1]
  sub r2, r2, #1
  cmp r2, #1
  blt gpiote_finish
  str r2, [r1]
gpiote_finish:
  bx lr
.size GPIOTE_IRQHandler, .-GPIOTE_IRQHandler

.data
image:
  .word 0x0 
  .word 0b00001 @ not displayed
  .word 0x1
  .word 0b00001 @ Column 1, Button A
  .word 0x2 
  .word 0b00000 @ Column 2
  .word 0x3 
  .word 0b00000 @ Column 3
  .word 0x4 
  .word 0b00000 @ Column 4
  .word 0x5 
  .word 0b00000 @ Column 5, Button B

.data
shiftclock:
  .word 0x50

.data
dropper:
  .word 0x3 @ column
  .word 0x5 @ row

.data
store_flag:
  .word 0