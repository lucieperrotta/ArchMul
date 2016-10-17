        ;;- ROM  (address 0x0-0xFFF)
        ;;- RAM (addresses 0x1000-0x1FFF)
        ;;- LEDS[0] (address 0x2000-0x2003)
        ;;- LEDS[1] (address 0x2004-0x2007)
        ;;- LEDS[2] (address 0x2008-0x200B)
        ;;- BUTTONS (address 0x2030-0x2033)
        .equ LEDS, 0x2000 ; LEDs address
        .equ BUTTONS, 0x2030 ; Buttons address
        .equ EDGECAPTURE, 0x2034
        .equ MEM_ADDR_TEST, 0x1800
main:
        addi t0, zero, 0
wait_for_button0:   
        addi t1, zero, 0x0001
        ldw t0, BUTTONS(zero)   ; read buttons
        and t1, t0, t1          ; read button 0
        bne t1, zero, wait_for_button0 ; wait until button is down, bit0 == 0
        ;; button is up, time to light up the led 32
        addi t1, zero, 0x0001
        stw  t1, LEDS+4(zero)
wait_for_edge1: 
        addi t1, zero, 0x0002
        ldw t0, EDGECAPTURE(zero)   ; read edge
        and t1, t0, t1          ; read edge 1
        beq t1, zero, wait_for_edge1 ; wait until edge is up
        ;; edge is up, light up led 33
        addi t1, zero, 0x0003
        stw  t1, LEDS+4(zero)
wait_for_button2:
        addi t1, zero, 0x0004
        ldw t0, BUTTONS(zero)   ; read buttons
        and t1, t0, t1          ; read button 2
        bne t1, zero, wait_for_button2 ; wait until button is  down, bit0 == 0

        ;; button is up test memory
		;; write pattern to memory        
		addi t1, zero, 0x10
		ori t0, zero, 0x0F99
		sll t0, t0, t1
		ori t0, t0, 0x69FF
        stw  t0, MEM_ADDR_TEST(zero)
		;; read back
		ldw  t1, MEM_ADDR_TEST(zero)

        stw  t1, LEDS(zero)     ; Write to mem, read from mem and write to led

        beq  t0, t1, test_success
        ;; test failed, light up led 34
        addi t1, zero, 0x0004
        stw  t1, LEDS+4(zero)
test_success:
        ;; test successifull, light up led 35
        addi t1, zero, 0x0008
        stw  t1, LEDS+4(zero)
end_pgm:
        nop
        br end_pgm
