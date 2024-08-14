global setup_interrupts

section .data
    idt_ptr     dq 0                ; IDT pointer (48-bit)
    idt         times 256 dq 0      ; IDT with 256 entries (each 16 bytes)

section .text
    extern keyboard_handler_c       ; C function to handle the keyboard interrupt

    ; Function to set up the PIC
    setup_pic:
        cli                         ; Disable interrupts
        ; ICW1: Initialize PICs
        mov al, 0x11                ; Start initialization in cascade mode
        out 0x20, al                ; Send to master PIC
        out 0xA0, al                ; Send to slave PIC

        ; ICW2: Set vector offset
        mov al, 0x20                ; Master PIC vector offset
        out 0x21, al
        mov al, 0x28                ; Slave PIC vector offset
        out 0xA1, al

        ; ICW3: Set up cascading
        mov al, 0x04                ; Tell Master PIC there is a slave PIC at IRQ2
        out 0x21, al
        mov al, 0x02                ; Tell Slave PIC its cascade identity
        out 0xA1, al

        ; ICW4: Environment info
        mov al, 0x01                ; 8086/88 mode
        out 0x21, al
        out 0xA1, al

        ; Mask interrupts
        mov al, 0xFD                ; Enable only IRQ1 (keyboard)
        out 0x21, al
        mov al, 0xFF                ; Disable all interrupts on the slave PIC
        out 0xA1, al

        sti                         ; Enable interrupts
        ret

    ; Function to load the IDT
    load_idt:
        lidt [idt_ptr]              ; Load the IDT pointer
        sti                         ; Enable interrupts
        ret

    ; Function to set an IDT entry
    set_idt_entry:
        ; Arguments: rdi = index, rsi = handler address
        mov rax, rsi                ; Load the handler address (64 bits) into rax
        mov rbx, rdi                ; Load the index into rbx
        shl rbx, 4                  ; Multiply by 16 (size of IDT entry)
    
        ; Set the low 16 bits of the handler address
        mov word [idt + rbx], ax
        ; Set the code segment selector
        mov word [idt + rbx + 2], 0x08
        ; Set the type and attributes (0x8E = present, privilege level 0, interrupt gate)
        mov byte [idt + rbx + 5], 0x8E
        ; Zero the next byte
        mov byte [idt + rbx + 4], 0x00
        ; Set the high 16 bits of the handler address
        shr rax, 16
        mov word [idt + rbx + 6], ax
        ; Set the higher 32 bits of the handler address (bits 32-63)
        shr rax, 16
        mov dword [idt + rbx + 8], eax
        ; Zero the final dword
        mov dword [idt + rbx + 12], 0
        ret

    ; Keyboard ISR
    keyboard_isr:
        cli                         ; Clear interrupts

        ; Manually push all general-purpose registers
        push rax
        push rbx
        push rcx
        push rdx
        push rsi
        push rdi
        push rbp
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15

        call keyboard_handler_c     ; Call the C handler

        ; Manually pop all general-purpose registers
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rbp
        pop rdi
        pop rsi
        pop rdx
        pop rcx
        pop rbx
        pop rax

        ; Send EOI to PIC
        mov al, 0x20
        out 0x20, al                ; Send to master PIC

        sti                         ; Enable interrupts
        iret                        ; Return from interrupt

    ; Setup IDT and PIC in one function
    setup_interrupts:
        call setup_pic
        mov rdi, 0x21               ; IDT index for keyboard interrupt
        lea rsi, [keyboard_isr]     ; Address of keyboard ISR
        call set_idt_entry          ; Set the IDT entry

        ; Step-by-step calculation of IDT size (limit)
        lea rax, [idt_end]          ; Load the address of idt_end into rax
        sub rax, idt                ; Subtract the base address of idt to get the size
        dec rax                     ; Subtract 1 from the size (for the limit)
        mov word [idt_ptr], ax      ; Store the lower 16 bits of size in the IDT pointer's first word

        ; Store IDT base address in idt_ptr + 2
        mov rax, idt                ; IDT base address
        mov [idt_ptr + 2], rax      ; Store base address in the next part of the IDT pointer

        call load_idt               ; Load the IDT
        ret

section .rodata
    idt_end:
