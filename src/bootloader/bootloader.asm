; -------------------------------------------------
; BIOS Interrupts
; https://en.wikipedia.org/wiki/BIOS_interrupt_call
; -------------------------------------------------
; INT 10h -- Video
; INT 11h -- Equipament Check
; INT 12h -- Memory Size
; INT 13h -- Disk I/O
; INT 14h -- Serial Communications
; INT 15h -- Cassette
; INT 16h -- Keyboard I/O

; -------------------------------------------------
; Same Registeres
; -------------------------------------------------
; CS (Code Segment)
; DS (Data Segment)
; SS (Stack Segment)
; ES (Extra Segment)
; SP (Stack Pointer)
; IP (Code Address)
; FS e GS (General Segment)

ORG 0x7C00                 ; especifica o endereço de memória onde o programa será carregado
bits 16                     ; as instruções serão de 16 bits

%define ENDL 0x0D, 0x0A

;
; FAT12 header
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
ebr_reserved                db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'LUCAS OS   '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

;
; Code goes here
;
start:
    jmp main

; imprime uma string na tela 
; ds:si contém o ponteiro para a string
puts:
    ; salva os registradores de SI e AX
    ; vamos recuperar eles ao final do
    ; procedimento
    push si
    push ax
    push bx

.loop:
    ; PS: loadsw/loads carregam word/dword (double word) e seus conteúdos
    ; serão carregados em ax/eax respectivamente, e o SI é incrementado
    ; com a quantidade de bytes que irá depender da instrução
    lodsb  ; loadsb carrega um byte que esta apontado para DS:SI em AL e incrementa SI em 1 byte

    ; bitwise OR, vamso verificar se 'al' e nulo
    ; se for, o bitwise irá registrar uma flag z (zero flag)
    or al, al

    ; jz irá verificar se zero flag é zero, se for, faz um jump no programa
    jz .finish

    mov ah, 0x0e    ; Write Character in TTY Mode (Habilita o TTY Mode na BIOS)
    mov bh, 0x00    ; Text Mode (Page Number)
    
    int 0x10        ; chama a interrupção de vídeo da BIOS

    ; se não for zero, continua no loop, até finalizar toda a string
    jmp .loop

.finish:
    ; recuperamos os valores do SI e AX que colocamos no inicio do procedimento
    pop bx
    pop ax
    pop si

    ; retornamos a função original que foi chamado (o endereço esta na stack)
    ret

main:
    ; inicializa o ax como zero
    mov ax, 0

    ; inicialização do data segment, extra segment e stack segment como zero
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; initialização do stack pointer no endereço 0x7C00 (inicio do programa)
    ; PS: stack pointer não vai interferir em nosso programa pois
    ; usa a lógica de first in - first out, ou seja, quando você adiciona
    ; algo na stack, vamos decrementar o pointeiro, então, serão usados
    ; o endereço abaixo do 0x7C00 e não posterior ao 0x7C00
    mov sp, 0x7C00

    ; exibe a mensagem na tela
    mov si, hello_lucas
    call puts

    hlt

.halt:
    jmp .halt

hello_lucas: db 'Hello Lucas :)', ENDL, 0

times 510 - ($ - $$) db 0   ; preenche com 0x00 até a posição 510
dw 0AA55h                   ; assinatura final 0xAA55