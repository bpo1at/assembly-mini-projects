; ================================
; FALLING BLOCKS (8086) - OPTIMIZED SIMPLE VERSION
; Grid: 5x5
; Controls: A = left, D = right
; Goal: survive until score reaches 4 -> WIN
; Collision with any falling block -> GAME OVER
; ================================

include 'emu8086.inc'

.model small
.stack 100h

.data
WIDTH       equ 5
HEIGHT      equ 5

player_x    db ?
player_y    db ?

block_x     db ?
block_y     db ?
block2_x    db ?
block2_y    db ?

game_over   db ?       ; 0=running, 1=dead, 2=win
score       db 0
seed        db 7       ; pseudo-random seed

msg_intro_title   db 'FALLING BLOCKS', 13,10, '$'
msg_intro_line1   db 'A / D : move left-right', 13,10, '$'
msg_intro_line2   db 'Avoid 4 blocks -> win', 13,10, '$'
msg_intro_start   db 13,10, 'Press any key...', '$'

msg_game_over  db 'GAME OVER$', 0
msg_win        db 'YOU WON!$', 0
msg_press_key  db 13, 10, 'Press any key to exit...$', 0
msg_score      db 'Score: $', 0 

prev_player_x db 0FFh
prev_player_y db 0FFh
prev_block_x  db 0FFh
prev_block_y  db 0FFh
prev_block2_x db 0FFh
prev_block2_y db 0FFh
prev_score    db 0FFh
draw_inited   db 0
 



.code

; -------------------------------
; PROGRAM START
; -------------------------------
start:
    mov ax, @data
    mov ds, ax

    call show_intro
    call init_game

; -------------------------------
; MAIN LOOP
; -------------------------------
game_loop:
    mov al, game_over
    cmp al, 0
    jne finish

    call read_input_non_blocking
    call update_block
    call check_collision

    mov al, game_over
    cmp al, 0
    jne finish

    call draw_screen
    jmp game_loop

; -------------------------------
; FINISH STATES
; -------------------------------
finish:
    cmp al, 1
    je state_game_over
    cmp al, 2
    je state_win
    jmp game_loop

state_game_over:
    mov dx, offset msg_game_over
    call show_end_screen
    call wait_key
    call exit_program

state_win:
    mov dx, offset msg_win
    call show_end_screen
    call wait_key
    call exit_program


; ========================================
; show_intro: prints instructions, waits key
; ========================================
show_intro proc
    push ax
    push dx

    mov ah, 00h
    mov al, 03h
    int 10h

    mov dx, offset msg_intro_title
    mov ah, 09h
    int 21h

    mov dx, offset msg_intro_line1
    mov ah, 09h
    int 21h

    mov dx, offset msg_intro_line2
    mov ah, 09h
    int 21h

    mov dx, offset msg_intro_start
    mov ah, 09h
    int 21h

    mov ah, 00h
    int 16h

    pop dx
    pop ax
    ret
show_intro endp


; ========================================
; init_game: sets player + initial blocks
; ========================================
init_game proc
    mov ah, 00h
    mov al, 03h
    int 10h

    ; player at bottom middle
    mov al, WIDTH
    mov bl, 2
    div bl
    mov player_x, al        ; WIDTH/2

    mov al, HEIGHT-1
    mov player_y, al

    ; initial blocks
    mov block_x, 2
    mov block_y, 0

    mov block2_x, 4
    mov block2_y, 0

    mov game_over, 0
    mov score, 0
    mov seed, 7
    ret
init_game endp


; ========================================
; read_input_non_blocking:
; if key exists, reads it and moves player
; ========================================
read_input_non_blocking proc
    push ax
    push bx

    mov ah, 01h
    int 16h
    jz done

    mov ah, 00h
    int 16h                ; AL = ASCII

    or  al, 20h            ; 'A'->'a', 'D'->'d'
    cmp al, 'a'
    je left
    cmp al, 'd'
    je right
    jmp done

left:
    mov al, player_x
    cmp al, 0
    jle done
    dec al
    mov player_x, al
    jmp done

right:
    mov al, player_x
    cmp al, WIDTH-1
    jge done
    inc al
    mov player_x, al

done:
    pop bx
    pop ax
    ret
read_input_non_blocking endp


; ========================================
; random_block_position (FIXED + better):
; seed = seed*5 + 3   (small LCG)
; returns AL = seed % WIDTH
; ========================================
random_block_position proc
    push bx

    mov al, seed
    mov bl, 5
    mul bl              ; AX = AL*5
    add ax, 3
    mov seed, al        ; keep low 8-bit seed

    xor ah, ah
    mov bl, WIDTH
    div bl              ; AH = remainder (0..WIDTH-1)
    mov al, ah

    pop bx
    ret
random_block_position endp


; ========================================
; update_block:
; block1 always falls
; block2 falls only when score >= 1
; when a block passes player row -> score++
; score==4 -> WIN
; ========================================
update_block proc
    push ax
    push bx

    ; ---- block 1 ----
    mov al, block_y
    inc al
    mov block_y, al

    mov al, block_y
    cmp al, player_y
    jle block2_part

    ; passed -> score++
    mov al, score
    inc al
    mov score, al

    cmp al, 4
    jne reset1
    mov game_over, 2
    jmp endu

reset1:
    mov block_y, 0
    call random_block_position
    mov block_x, al

block2_part:
    ; ---- block 2 (active after score>=1) ----
    mov al, score
    cmp al, 1
    jl endu

    mov al, block2_y
    inc al
    mov block2_y, al

    mov al, block2_y
    cmp al, player_y
    jle endu

    ; passed -> score++
    mov al, score
    inc al
    mov score, al

    cmp al, 4
    jne reset2
    mov game_over, 2
    jmp endu

reset2:
    mov block2_y, 0

    ; block2_x = (block_x + 2) % WIDTH  (fast mod with DIV)
    mov al, block_x
    add al, 2
    xor ah, ah
    mov bl, WIDTH
    div bl              ; AH = remainder
    mov block2_x, ah

endu:
    pop bx
    pop ax
    ret
update_block endp


; ========================================
; check_collision:
; if player and any block share same (x,y) -> GAME OVER
; block2 checked only if score >= 1
; ========================================
check_collision proc
    push ax

    ; block1
    mov al, block_y
    cmp al, player_y
    jne check2
    mov al, block_x
    cmp al, player_x
    jne check2
    mov game_over, 1
    jmp donec

check2:
    mov al, score
    cmp al, 1
    jl donec

    mov al, block2_y
    cmp al, player_y
    jne donec
    mov al, block2_x
    cmp al, player_x
    jne donec
    mov game_over, 1

donec:
    pop ax
    ret
check_collision endp


; ========================================
; draw_screen (incremental, FIXED):
; updates only changed cells + score line
; ========================================
draw_screen proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov ax, 0B800h
    mov es, ax

    ; ------------------------
    ; First time: draw full grid of '.'
    ; ------------------------
    mov al, draw_inited
    cmp al, 1
    je  incremental

    mov bl, 0                 ; y
full_row:
    cmp bl, HEIGHT
    jge full_done

    ; di = y*160
    xor di, di
    mov al, bl
    xor ah, ah
    mov di, ax
    shl di, 7                 ; y*128
    mov al, bl
    xor ah, ah
    shl ax, 5                 ; y*32
    add di, ax                ; y*160

    mov cx, WIDTH             ; x count
full_col:
    mov ax, 0F2Eh             ; '.' attr 0Fh
    stosw
    loop full_col

    inc bl
    jmp full_row

full_done:
    mov draw_inited, 1
    mov prev_score, 0FFh      ; force score redraw once

incremental:

    ; ------------------------
    ; 1) clear previous cells (write '.')
    ; ------------------------
    ; prev player
    mov al, prev_player_x
    cmp al, 0FFh
    je  clr_b1
    mov cl, prev_player_x
    mov bl, prev_player_y
    call write_dot_xy

clr_b1:
    ; prev block1
    mov al, prev_block_x
    cmp al, 0FFh
    je  clr_b2
    mov cl, prev_block_x
    mov bl, prev_block_y
    call write_dot_xy

clr_b2:
    ; prev block2 (only if it was active last frame)
    mov al, prev_score
    cmp al, 1
    jl  draw_new
    mov al, prev_block2_x
    cmp al, 0FFh
    je  draw_new
    mov cl, prev_block2_x
    mov bl, prev_block2_y
    call write_dot_xy

draw_new:
    ; ------------------------
    ; 2) draw current entities
    ; ------------------------
    ; block1 '#'
    mov cl, block_x
    mov bl, block_y
    call write_hash_xy

    ; block2 '#', only if active now
    mov al, score
    cmp al, 1
    jl  draw_player
    mov cl, block2_x
    mov bl, block2_y
    call write_hash_xy

draw_player:
    ; player 'P' last (overwrites if same cell)
    mov cl, player_x
    mov bl, player_y
    call write_player_xy

    ; ------------------------
    ; 3) save current as previous
    ; ------------------------
    mov al, player_x
    mov prev_player_x, al
    mov al, player_y
    mov prev_player_y, al

    mov al, block_x
    mov prev_block_x, al
    mov al, block_y
    mov prev_block_y, al

    mov al, block2_x
    mov prev_block2_x, al
    mov al, block2_y
    mov prev_block2_y, al

    ; ------------------------
    ; 4) update score line only if changed
    ; ------------------------
    mov al, score
    cmp al, prev_score
    je  done_draw

    ; write at row (HEIGHT+1), col 0 in video memory
    mov bl, HEIGHT
    inc bl                    ; y = HEIGHT+1

    ; di = y*160
    xor di, di
    mov al, bl
    xor ah, ah
    mov di, ax
    shl di, 7
    mov al, bl
    xor ah, ah
    shl ax, 5
    add di, ax

    ; "Score: "
    mov ax, 0F53h  ; S
    stosw
    mov ax, 0F63h  ; c
    stosw
    mov ax, 0F6Fh  ; o
    stosw
    mov ax, 0F72h  ; r
    stosw
    mov ax, 0F65h  ; e
    stosw
    mov ax, 0F3Ah  ; :
    stosw
    mov ax, 0F20h  ; space
    stosw

    ; digit
    mov al, score
    add al, '0'
    mov ah, 0Fh
    stosw

    mov al, score
    mov prev_score, al

done_draw:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------
; helpers (local "subroutines" with RET!)
; expects: CL=x, BL=y
; ------------------------------------------------
calc_di_xy:
    ; DI = y*160 + x*2
    xor di, di
    mov al, bl
    xor ah, ah
    mov di, ax
    shl di, 7                 ; y*128
    mov al, bl
    xor ah, ah
    shl ax, 5                 ; y*32
    add di, ax                ; y*160

    mov al, cl
    xor ah, ah
    shl ax, 1                 ; x*2
    add di, ax
    ret

write_dot_xy:
    push ax
    call calc_di_xy
    mov ax, 0F2Eh             ; '.'
    mov es:[di], ax
    pop ax
    ret

write_hash_xy:
    push ax
    call calc_di_xy
    mov ax, 0F23h             ; '#'
    mov es:[di], ax
    pop ax
    ret

write_player_xy:
    push ax
    call calc_di_xy
    mov ax, 0F50h             ; 'P'
    mov es:[di], ax
    pop ax
    ret

draw_screen endp



; ========================================
; print_crlf: prints newline (13,10)
; ========================================
print_crlf proc
    push ax
    push dx

    mov ah, 02h
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    pop dx
    pop ax
    ret
print_crlf endp


; ========================================
; print_score: prints "Score: " + digit
; ========================================
print_score proc
    push ax
    push dx

    mov dx, offset msg_score
    mov ah, 09h
    int 21h

    mov al, score
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    pop dx
    pop ax
    ret
print_score endp


; ========================================
; show_end_screen:
; DX = msg_game_over or msg_win
; clears screen, prints message + score + exit text
; ========================================
show_end_screen proc
    push ax
    push dx

    mov ah, 00h
    mov al, 03h
    int 10h

    mov ah, 09h
    int 21h

    call print_crlf
    call print_score
    call print_crlf

    mov dx, offset msg_press_key
    mov ah, 09h
    int 21h

    pop dx
    pop ax
    ret
show_end_screen endp


; ========================================
; wait_key: waits for any key
; ========================================
wait_key proc
    mov ah, 00h
    int 16h
    ret
wait_key endp


; ========================================
; exit_program: return to DOS
; ========================================
exit_program proc
    mov ax, 4C00h
    int 21h
exit_program endp

end start
