#include <stdint.h>

#include "kernel/print.h"

extern void setup_interrupts(void);

// Function to read from an I/O port
static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "dN"(port));
    return ret;
}

// Buffer to store the last scan code
volatile uint8_t scan_code = 0;

void keyboard_handler_c() {
    // Read the scan code from the keyboard data port (0x60)
    scan_code = inb(0x60);

    print_char('.');
}

void keyboard_init() {
    setup_interrupts(); // Setup PIC and IDT
}