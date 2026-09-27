; frasm self-test: every instruction below is assembled and then
; re-disassembled by the NikonHacker Dfr to confirm the encoding.
.org 0x40000
start:
    ldi8  #0x1E, r4
    ldi8  #0xC4, r0
    ldi20 #0x05DC0, r1
    ldi20 #0x00110, r6
    ldi32 #0x00621DE2, r12
    ldi32 #0x84E6C020, r0
    ldi32 #0xCAFE0001, r1
    mov   r7, r11
    mov   r5, r7
    st    r1, @r0
    ld    @r0, r1
    st    rp, @-r15
    ld    @r15+, rp
    stm1  (r8,r9,r10,r11)
    ldm1  (r8,r9,r10,r11)
    enter #4
    leave
    nop
    int   #0x40
    cmp   #0x0, r9
    cmp   #0x4, r4
    cmp   r1, r0
    add   #0x1, r5
    add   r5, r4
    sub   r0, r4
    and   r1, r0
    or    r1, r0
    eor   r1, r0
    lsr   #0x3, r4
    lsl   #0x2, r5
    asr   #0x1, r6
    jmp   @r12
    jmp:d @r12
    call  @r12
    call:d @r12
    ret
    retd
back:
    bra   start
    beq   start
    bne   start
    bc    start
    bnc   start
    bra:d start
