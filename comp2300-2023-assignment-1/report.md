## ALU instructions operate on immediate values

3 bit values can now be used in place of register addresses when using performing ALU operations. This provides convenience and removes the need for an additional operation, to store the value to be added.

new alu codes:
1. add: 1000 cond rd immbit ra immbit rb
2. sub: 1001 cond rd immbit ra immbit rb
3. and: 1010 cond rd immbit ra immbit rb
4. orr: 1011 cond rd immbit ra immbit rb

when the immbit is set to one, the alu will operate on the value specified in ra/rb directly.
eg. 

To find: r3 = 1 + 2
we could do,
- movl r1 1
- movl r2 2
- add r3 r1 r2 (1000 0011 0001 0010)

or,
- add r3 1 2 (1000 0011 1001 1010)


## Extended alu

More aluop operations have been implemented.

- 000 - add
- 001 - sub
- 010 - and
- 011 - or
- 100 - xor
- 101 - nand
- 110 - nor
- 111 - xnor

## Writes to FL register

The FL register can be written to like any general purpose register.

eg.
movl FL 5 will result in:
FL = 5

## Multi-cycle execution

Two additional dflipflops have been added to store additional sub-operations which can be executed for each PC increment, allowing for more complex operations. In the extended CPU, there are two instructions which make use of this multi-cycle execution.

 - **JCC instruction**

The jcc command compares the data in two registers and jumps to the address stored in a destination register if they are equal. 

syntax:
jcc - 0010 cond rd 0 ra 0 rb

A combination of two operations:
- CMP ra rb
- MOVL pc rd (with cond bit set to one)

The jcc command can also operate on immediate values similar to ordinary alu operations.

- **CALL instruction**

Stores PC+1 at the top of the stack. Then moves PC to an address specified

syntax:
- 0110 cond rd 0000 0001

A combination of three operations:
- TMP := PC + 1
- [top of stack] := TMP
- pc := rd

TMP is a temporary register that can only be accessed when the tmp flag is set. When set, this register is automatically written to(the register specified in write select is not) and on the next clk cycle, the data in the TMP register is automaically outputted into the RAM. This allows for data to be stored in a temporary place, and not overwite values in other registers.

## Extended ldr and str

The extended-cpu now connects the output of the ALU directly into the RAM. This allows for two registers to be added and then read by the RAM on the same clock cycle. Using this feature, the extended-cpu can now add the data in two registers and use the sum as an address to load and store values in the RAM.

- **Extended ldr**

original ldr code:
- 0101 cond rd 0 ra 0000

new ldr code:
- 0101 cond rd 0 ra 0 rb

rd := [ra + rb]

- **Extended str**

original str code:
- 0100 cond rd 0 ra 0000

new str code:
- 0100 cond rd 0 ra 0 rb

[ra + rb] := rd

## Stack

A stack register has been added that reads the current position of the top of the stack. It cannot
be written to normally but can be read. This feature allows for functions located at other memory locations to be executed, and for parameters to be passed to these functions. There are three primary operations that make use of the stack:

- **Push operation**

Push stores the data in a specified register at the top of the stack. The stack register then decrements by one. 

syntax:
- 0110 cond rd 0000 0000

[top of stack] := rd
Stack -= 1

- **Pop operation**

Pop stores the data at the top of the stack in a specified register. The stack register then increments by one.

syntax:
0111 cond rd 0000 0000

rd := [top of stack]
Stack += 1

- **Call operation**

See above.

A typical function call would work by first PUSHing all parameters into the stack. Next CALL is executed to PUSH the return address into the stack and JMP to the memory address of the function. The parameters can now be POPed from the top of the stack and operated on. After the function has executed, the return value can be PUSHed to the stack, and a JMP is executed to the return address.

## Smov command

Allows write access to three additional general purpose registers. 

syntax:
- 0011 cond rd 0 ra 0000

All registers
- 000 - RZ
- 001 - R1
- 010 - R2
- 011 - R3
- 100 - R4 
- 101 - Flag -> R5
- 110 - Stack -> R6
- 111 - PC -> R7
