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
; Some Registeres
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
    mov si, hello_lucas_os
    call puts

    ; tentando ler alguma coisa do disco
    mov [ebr_drive_number], dl  ; bios faz o setting do dl com o número do driver atual
    mov ax ,1                   ; ler o segundo setor do disco (o primeiro é o bootloader)
    mov cl, 1                   ; ler apenas 1 setor
    mov bx, 0x7E00              ; os dados devem ser escritos após o bootloader (512 bytes a frente)
    call .read_disk

    cli             ; desabilita as interrupções
    hlt

; erro leitura floppy
.floppy_error:
    mov si, floppy_error
    call puts

.wait_key_and_reboot:
    mov si, press_key_to_reboot
    call puts

    mov ah, 0
    int 0x16        ; aguarda pressionar uma tecla
    jmp 0FFFFh:0    ; pula para o inicio da bios

.halt:
    cli             ; desabilita as interrupções
    hlt             ; halt

; Rotina do Floppy Disc

; Converte um LBA (Logic Block Address) para CHS (Cylinder - Head - Sector)
; Param
;   - ax: Endereço LBA
; Return
;   - cl: número do setor
;   - ch: número do cilindro
;   - dh: número da cabeça
.lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / setor por trilha
                                        ; dx = LBA % setor por trilha (resto da divisão)
    inc dx                              ; dx += (LBA % setor por trilha) + 1 = número do setor
    mov cx, dx                          ; cx = dx

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = ax / número de cabeças = número do cilindro
                                        ; dx = ax % número de cabeças = número da cabeça
    mov dh, dl                          ; dh = dl = número da cabeça (8 bits iniciais)
    mov ch, al                          ; al = ch = número do cilindro (8 bits iniciais)
    shl ah, 6
    or cl, ah                           ; cl = ah = número de setores no cilindro

    pop ax
    mov dl, al                          ; restaura apenas os 8 bits iniciais do dx

    pop ax

    ret

; Leitura do disco
; Param
;   - ax: Endereço LBA
;   - cl: número de setores para ler (maior que 128)
;   - dl: número do driver
;   - es:bx: endereço de memória onde será salvo os dados
.read_disk:
    ; salva todos os registradores na stack
    push ax
    push bx
    push cx
    push dx
    push di

    push cx             ; salva temporariamente o cl (número de setores para ler)
    call .lba_to_chs    ; computa o CHS
    pop ax              ; al tem o resultado do cl (do push cx)

    mov ah, 02h         ; IO
    mov di, 3           ; tentativa de leitura

.read_retry:
    pusha               ; salva todos os registradores

    mov si, read_floppy_disk
    call puts

    stc                 ; set o carry flag

    int 0x13            ; interrupção da BIOS para ler disk floppy
    jnc .read_success   ; carry flag cleared = sucesso

    ; falha na leitura
    popa
    call .reset_controller_disk

    dec di              ; decrementa o di
    test di, di         ; testa se é zero
    jnz .read_retry     ; se não for zero, tenta novamente

.read_failed:
    jmp .floppy_error   ; não conseguiu ler o floppy disc (erro)

.read_success:
    mov si, floppy_success
    call puts

    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

; Faz o reset do controlador de disco
; Param
;   - dl: número do driver
.reset_controller_disk:
    pusha           ; salva todas os registradores
    mov ah, 0
    stc             ; set o carry flag

    int 0x13
    jc .read_failed ; verifica se carry está ativo, se sim, pula para a falha

    popa            ; restaura todos os registradores
    ret

hello_lucas_os: db 'Hello - Lucas OS', ENDL, 0
floppy_error: db 'Error to read floppy disk', ENDL, 0
floppy_success db "Success to read floppy disk", ENDL, 0
press_key_to_reboot: db 'Press any key to reboot', ENDL, 0
read_floppy_disk: db 'Trying read floppy disk data', ENDL, 0

times 510 - ($ - $$) db 0   ; preenche com 0x00 até a posição 510
dw 0AA55h                   ; assinatura final 0xAA55
