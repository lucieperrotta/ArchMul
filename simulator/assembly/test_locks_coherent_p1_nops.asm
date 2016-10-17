        ;;- ROM  (address 0x0-0xFFF)
        ;;- RAM (addresses 0x1000-0x1FFF)
        ;;- LEDS[0] (address 0x2000-0x2003)
        ;;- LEDS[1] (address 0x2004-0x2007)
        ;;- LEDS[2] (address 0x2008-0x200B)
        ;;- BUTTONS (address 0x2030-0x2033)
        .equ LEDS, 0x2000 ; LEDs address
        .equ BUTTONS, 0x2030 ; Buttons address
        .equ EDGECAPTURE, 0x2034
        .equ MEM_ADDR_TEST, 0x1000
        .equ LOCK_FLAG_0, 0x1000
        .equ LOCK_FLAG_1, 0x1004
        .equ LOCK_TURN,   0x1008
        .equ SHARED_MEM,  0x100C
main:
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        addi t0, zero, 0
        addi t2, zero, 0
        addi t3, zero, 256
        ;; increment a memory counter 100 times in memory
for_0_to_100:
        call lock_acquire
        ldw t0, SHARED_MEM(zero)
        addi t0, t0, 1
        stw t0, SHARED_MEM(zero)
        call lock_release
        addi t2, t2, 1
        bne t2, t3, for_0_to_100
        ;; after the loop, show the value of the counter in leds
        ldw t0, SHARED_MEM(zero)
        stw t0, LEDS+4(zero)
        addi t0, zero, 1
        ;; show we are done
        stw t0, LEDS(zero)
end_pgm:
        nop
        br end_pgm


        ;; must save t0, t1 before calling
lock_acquire:
        addi t0, zero, 1
        stw t0, LOCK_FLAG_1(zero)
        stw t0, LOCK_TURN(zero)
while_locked:   
        ldw t0, LOCK_FLAG_0(zero)
        ldw t1, LOCK_TURN(zero)
        and t0, t0, t1
        bne t0, zero, while_locked ; wait while both are 1
        ;; lock was ackired
        ret 

        ;; must save t0 before calling
lock_release:
        addi t0, zero, 0
        stw t0, LOCK_FLAG_1(zero)
        ret
