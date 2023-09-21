ORG 0x7C000                 ; especifica o endereço de memória onde o programa será carregado
bits 16                     ; as instruções serão de 16 bits
main:
    hlt
.halt:
    jmp .halt

times 510 - ($ - $$) db 0   ; preenche com 0x00 até a posição 510
dw 0AA55h                   ; assinatura final 0xAA55