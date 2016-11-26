        ;;- ROM  (address 0x0-0xFFF)
        ;;- RAM (addresses 0x1000-0x1FFF)
        ;;- LEDS[0] (address 0x2000-0x2003)
        ;;- LEDS[1] (address 0x2004-0x2007)
        ;;- LEDS[2] (address 0x2008-0x200B)
        ;;- BUTTONS (address 0x2030-0x2033)
        .equ LEDS, 0x2000 ; LEDs address
		.equ LEDS_DUTY, 0x200C
        .equ BUTTONS, 0x2030 ; Buttons address
        .equ EDGECAPTURE, 0x2034
        .equ ARRAY_DEST, 0x1000
        .equ LOCK_FLAG_0, 0x1000
        .equ LOCK_FLAG_1, 0x1004
        .equ LOCK_TURN,   0x1008
        .equ SHARED_MEM,  0x100C
		.equ FINISHED_FLAG_0, 0x1010
		.equ FINISHED_FLAG_1, 0x1014
main:
		addi t0, zero, 255
		stw t0, LEDS_DUTY(zero)
        addi t0, zero, 0
        stw t0, SHARED_MEM(zero)
		stw t0, LOCK_FLAG_0(zero)
		stw t0, LOCK_FLAG_1(zero)
		stw t0, LOCK_TURN(zero)
		stw t0, FINISHED_FLAG_0(zero)
		stw t0, FINISHED_FLAG_1(zero)
		addi t3, zero, 0
        addi t4, zero, 256
        ;; increment a memory counter 100 times in memory
write_loop:
		call lock_acquire
        ldw t0, SHARED_MEM(zero)
        addi t0, t0, 1
        stw t0, SHARED_MEM(zero)
		call lock_release
        addi t3, t3, 1
        bne t3, t4, write_loop

		;; wait for the other to end
		addi t0, t0, 1
		stw t0, FINISHED_FLAG_1(zero)
wait_loop:
		ldw t0, FINISHED_FLAG_0(zero)
		addi t1, zero, 1
		bne t0, t1, wait_loop

        ;; after the loop, show the value of the counter in leds
		addi t1, zero, 512
        ldw t0, SHARED_MEM(zero)
        stw t0, LEDS+4(zero)
		bne t0, t1, led_error

		
        ;; show we are done
        addi t0, zero, 1
        stw t0, LEDS(zero)
		br end_pgm

led_error:
        addi t0, zero, 2
        ;; show we are done
        stw t0, LEDS(zero)

        ;; show we are done
        stw t0, LEDS(zero)
end_pgm:
        nop
        br end_pgm


        ;; must save t0, t1,t2 before calling
lock_acquire:
        addi t0, zero, 1
        stw t0, LOCK_FLAG_1(zero)
        addi t0, zero, 0
        stw t0, LOCK_TURN(zero)
while_locked:   
        ldw t0, LOCK_FLAG_0(zero)
        ldw t1, LOCK_TURN(zero)
		addi t2, zero, 1
		xor t1, t1, t2 ;; t1 = (t1 == 0)? 1 : 0
        and t0, t0, t1
        bne t0, zero, while_locked ; wait while both are 1
        ;; lock was ackired
        ret 

        ;; must save t0 before calling
lock_release:
        addi t0, zero, 0
        stw t0, LOCK_FLAG_1(zero)
        ret
