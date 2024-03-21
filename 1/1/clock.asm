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

time_offset dw 0
time_pref db "Time: "
time_pref_len = $ - time_pref

remtime_offset dw 160
remtime_pref db "Seconds remain: "
remtime_pref_len = $ - remtime_pref
remtime dw 0

alarm_rise db "Alarm rise!!!Clock frozen!!!"
alarm_rise_len = $ - alarm_rise
alarm_rise_offset dw 160

update_freq dd 18
next_update_ticks dd 0
alarm_rise_ticks dd 0

cur_time db 3 dup(?)

ascii_time db 'DE.FA.LT'
ascii_time_len = $ - ascii_time

ascii_number db "0000000000"
ascii_number_len = $ - ascii_number

;out dx
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

;in bcd al
;out asc ax 
convert_bcd_to_asc proc
mov ah, al
and al, 1111b
shr ah, 4
or ax, 3030h
ret
convert_bcd_to_asc endp

write_message_to_videomemory proc
push eax
push es
push 0b800h
pop es
mov ah, 71h
cld
foreach_char:
	lodsb
	stosw
	loop foreach_char
pop es
pop eax
ret
write_message_to_videomemory endp

write_to_videomem macro message, message_len, offset_value
push ecx
push esi
push edi
lea esi, message
mov cx, message_len
movzx edi, word ptr offset_value
call write_message_to_videomemory
pop edi
pop esi
pop ecx
endm

;in esi time
;in edi template
;out template
store_time_in_ascii_template proc
push eax
mov al, byte ptr si[0]
call convert_bcd_to_asc
mov byte ptr di[0], ah
mov byte ptr di[1], al

mov al, byte ptr si[1]
call convert_bcd_to_asc
mov byte ptr di[3], ah
mov byte ptr di[4], al

mov al, byte ptr si[2]
call convert_bcd_to_asc
mov byte ptr di[6], ah
mov byte ptr di[7], al
pop eax
ret
store_time_in_ascii_template endp

store_time_in_ascii macro time_buffer, template
push esi
push edi
lea esi, time_buffer
lea edi, template
call store_time_in_ascii_template
pop edi
pop esi
endm

save_rtc_time macro buffer
push eax
push ecx
push edx
mov ah, 02h
int 1ah
mov byte ptr buffer[0], ch
mov byte ptr buffer[1], cl
mov byte ptr buffer[2], dh
pop edx
pop ecx
pop eax
endm

write_curtime_to_videomem proc
push ebx
save_rtc_time cur_time
write_to_videomem time_pref, time_pref_len, time_offset
store_time_in_ascii cur_time, ascii_time
mov bx, time_offset
add bx, time_pref_len * 2
write_to_videomem ascii_time, ascii_time_len, bx	
pop ebx
ret
write_curtime_to_videomem endp

;in dx cur_ticks
write_rem_time_to_videomem proc
push eax
push ebx
push ecx

mov eax, dword ptr alarm_rise_ticks
sub eax, edx
mov ebx, 18
xor edx, edx
div ebx
cmp edx, 0
je convert_num
inc eax
convert_num: 
call convert_num_to_ascii
mov bx, remtime_offset
add bx, remtime_pref_len * 2
write_to_videomem ascii_number, ascii_number_len, bx

pop ecx
pop ebx
pop eax
ret
write_rem_time_to_videomem endp

;in eax
;in edi buffer
;out buffer num
;out cl digits count
convert_num_to_ascii proc
push eax
push ebx
push edx
push ecx

xor ecx, ecx
mov ebx, 10
tke_rigth_digit:
	xor edx, edx
	div ebx
	add edx, '0'
	push edx
	inc ecx
	cmp eax, 0
jg tke_rigth_digit

lea edi, ascii_number
add edi, ascii_number_len
sub edi, ecx
store_each_digit:	
	pop eax
	mov byte ptr [edi], al
	inc edi
loop store_each_digit

pop ecx
pop edx
pop ebx
pop eax	
ret

convert_num_to_ascii endp


new_handler proc
pushf
call cs:old_handler

cmp eax, new_handler_request_key
jne new_handler_work
	mov eax, new_handler_answer_key
	iret

new_handler_work:
pushad
push ds
push es

push cs
pop ds

read_rtc_ticks

cmp dword ptr next_update_ticks, edx
jg finish_handle
	cmp dword ptr alarm_rise_ticks, edx
	jle on_alarm_rise
		jmp on_time_change

on_time_change:
	push edx
	add edx, dword ptr update_freq
	mov dword ptr next_update_ticks, edx	
	
	call write_curtime_to_videomem
	pop edx
	write_to_videomem remtime_pref, remtime_pref_len, remtime_offset	
	call write_rem_time_to_videomem	
	jmp finish_handle

on_alarm_rise:
	call write_curtime_to_videomem
	write_to_videomem alarm_rise, alarm_rise_len, alarm_rise_offset

	mov ax, 251ch
	lds dx, dword ptr cs:old_handler
	int 21h
	
	mov ah, 49h
	int 21h
	
finish_handle:
pop es
pop ds
popad
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


;eax - secs 
set_alarm proc
push ecx
push edx
read_rtc_ticks
mov cl, 18
mul cl
add edx, eax
mov dword ptr alarm_rise_ticks, edx
pop edx
pop ecx
ret
endp

main:

mov eax, new_handler_request_key
int 1ch
cmp eax, new_handler_answer_key
	je new_handler_already_load
	xor eax, eax

	get_int_handler 1ch, old_handler
	set_int_handler 1ch, new_handler
	mov eax, 60
	call set_alarm

	print handler_load
	stay_resident new_handler_start, new_handler_end	
	
new_handler_already_load:
print handler_already_load
terminate

end start
