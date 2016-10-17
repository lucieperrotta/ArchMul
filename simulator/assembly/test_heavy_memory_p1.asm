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
        .equ MEM_ARRAY, 0x1800
main:
		addi t0, zero, 255
		stw t0, LEDS_DUTY(zero)
        addi t0, zero, 0
        addi t3, zero, 256
        ;; write 256 memory addresses
write_loop:
        stw t0, MEM_ARRAY(t0)
        addi t0, t0, 4
        bne t0, t3, write_loop
        addi t0, zero, 0
read_loop:
        ldw t1, MEM_ARRAY(t0)
        ;; check if read is ok
        bne t1, t0, error_read
        addi t0, t0, 4
        bne t0, t3, read_loop
        
success:
        addi t0, zero, 1
        ;; show we are done
        stw t0, LEDS(zero)
        br end_pgm
        
error_read:
        addi t0, zero, 2
        ;; show we are done
        stw t0, LEDS(zero)
end_pgm:
        nop
        br end_pgm
