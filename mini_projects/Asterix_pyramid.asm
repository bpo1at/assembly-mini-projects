org 100h

mov bh, 4
mov bl, 1

satir_loop:
mov al, bh
sub al, bl

xor ch, ch
mov cl, al
jcxz skip_spaces

space_loop:
mov ah, 02h
mov dl, ' '
int 21h
loop space_loop

skip_spaces:
xor ch, ch
mov cl, bl

star_loop:
mov ah, 02h
mov dl, '*'
int 21h

mov dl, ' '
int 21h

loop star_loop

mov ah, 02h
mov dl, 0Dh
int 21h
mov dl, 0Ah
int 21h

inc bl
cmp bl, bh
jle satir_loop

mov ah, 4Ch
int 21h
