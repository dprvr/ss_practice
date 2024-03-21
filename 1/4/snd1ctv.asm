.model tiny
.code
.386
org 100h

start: 

jmp main

new_handler_start:
new_handler_request_key dd 1234h
new_handler_answer_key dd 0ffffh
old_handler dd ?

notes_freqs dw 440, 466, 494, 523, 554, 587, 622, 659, 698, 740, 784, 831, 880
cur_note_offset db -2
notes_remain db 12

update_freq dd 18
next_update_ticks dd 0

;out edx
read_rtc_ticks macro
push eax
push ecx
xor edx, edx
xor ecx, ecx
mov ah, 00h
int 1ah
shr ecx, 16
add edx, ecx
pop ecx
pop eax
endm

;in eax sound freq
;out eax sound divider
get_sound_divider proc
push ebx edx
xor edx, edx
mov ebx, eax
mov eax, 1234dch
div ebx
pop edx ebx
ret
get_sound_divider endp

;in eax sound_divider
start_play_sound proc
push eax
mov al, 0b6h
out 43h, al
pop eax
out 42h, al
mov al, ah
out 42h, al
in al, 61h
or al, 011b
out 61h, al
ret
start_play_sound endp

stop_play_sound proc
push eax
in al, 61h
and al, 11111100b
out 61h, al
pop eax
ret
stop_play_sound endp


new_handler proc
pushf
call cs:old_handler

cmp eax, new_handler_request_key
jne new_handler_work
	mov eax, new_handler_answer_key
	iret

new_handler_work:
pusha
push ds
push es

push cs
pop ds

read_rtc_ticks
cmp dword ptr next_update_ticks, edx
jg finish_handle
	cmp notes_remain, 0
	jle unload_prog
		jmp on_time_change

on_time_change:
	add edx, dword ptr update_freq
	mov dword ptr next_update_ticks, edx
	dec notes_remain
	add cur_note_offset, 2	
	
play_next_note:	
	movzx ebx, byte ptr cur_note_offset
	movzx eax, word ptr notes_freqs[ebx]	
	call get_sound_divider 
	call start_play_sound
	jmp finish_handle
	
unload_prog:
	call stop_play_sound
	
	mov ax, 251ch
	lds dx, dword ptr cs:old_handler
	int 21h
	
	mov ah, 49h
	int 21h
	
finish_handle:
pop es
pop ds
popa
iret
new_handler endp
new_handler_end:


handler_load db "New handler resident was successfully installed!!!"
handler_load_len = $ - handler_load

handler_already_load db "Fail to load handler. New handler resident already in memory!!!"
handler_already_load_len = $ - handler_already_load

;dx - message addr
;cx - message len
print_message proc
push eax
push ebx
mov ah, 40h
mov ebx, 1
int 21h
pop ebx
pop eax
ret
print_message endp

print macro message, message_len
push edx
push ecx
lea edx, message
mov ecx, &message&_len
call print_message
pop ecx
pop edx
endm

get_int_handler macro int_n, storage
push eax
push ebx
mov ah, 35h
mov al, int_n
int 21h
mov word ptr storage, bx
mov word ptr storage + 2, es
pop ebx
pop eax
endm

set_int_handler macro int_n, handler
push eax
push edx
mov ah, 25h
mov al, int_n
lea edx, handler
int 21h
pop eax
pop edx
endm

stay_resident macro resident_start, resident_end
mov eax, 3100h
mov edx, (resident_end - resident_start + 10fh) / 16
int 21h
endm

terminate macro
mov eax, 4c00h
int 21h
endm

main:

mov eax, new_handler_request_key
int 1ch
cmp eax, new_handler_answer_key
	je new_handler_already_load
	
	get_int_handler 1ch, old_handler
	set_int_handler 1ch, new_handler	
	print handler_load
	stay_resident start, new_handler_end	
	
new_handler_already_load:
	print handler_already_load
	terminate

end start
