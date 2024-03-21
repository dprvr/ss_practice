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
handler_function_n db ?

hex_map db '0123456789ABCDEF'

vm_cur_row dw 0
cur_sc db 0

esc_key_code db 01h

cur_sc_mes_pref db "The current SC: "
cur_sc_mes_pref_len = $ - cur_sc_mes_pref

hex_template db "00h"
hex_template_len = $ - hex_template

esc_detected_mes db "The ESC key was detected. Termination..."
esc_detected_mes_len = $ - esc_detected_mes

;in esi message
;in ecx message len
;in edi vm offset
;out edi vm offset
copy_message_to_vm proc
push eax
push esi
push es
mov ax, 0b800h
mov es, ax 
mov ah, 71h
cld
copy_each_message_char:
	lodsb
	stosw
loop copy_each_message_char
pop es
pop esi
pop eax
ret
copy_message_to_vm endp

showm macro message
lea esi, message
mov ecx, &message&_len
movzx edi, word ptr vm_cur_row
call copy_message_to_vm
add vm_cur_row, 160
endm

;in esi message_pref
;in ecx message_pref_len
;in eax message
;in ebx message_len
show_message_with_pref proc
push edi
movzx edi, word ptr vm_cur_row
call copy_message_to_vm
mov esi, eax
mov ecx, ebx
call copy_message_to_vm
pop edi
ret
show_message_with_pref endp

showpm macro message_pref, message
lea esi, message_pref
mov ecx, &message_pref&_len
lea eax, message
mov ebx, &message&_len
call show_message_with_pref
add vm_cur_row, 160
endm

;in al
;in edi out save
convert_hex_to_ascii proc
push eax
push ebx
mov ah, al
and al, 1111b
movzx ebx, al
mov al, hex_map[ebx]
mov byte ptr edi[1], al
mov al, ah
shr al, 4
movzx ebx, al
mov al, hex_map[ebx]
mov byte ptr edi[0], al
pop ebx
pop eax
ret
convert_hex_to_ascii endp


hex_to_ascii macro val
push eax edi
mov al, val
lea edi, hex_template
call convert_hex_to_ascii
pop edi eax
endm


new_handler proc
pushf

cmp ah, 4fh
jne switch_on_old_handler
	cmp ebx, new_handler_request_key
	jne start_handle
		mov ebx, new_handler_answer_key
		jmp break_handle

start_handle:		
	call cs:old_handler
	pushad
	push ds
	push es

	push cs
	pop ds
	
	mov byte ptr cur_sc, al
	mov word ptr vm_cur_row, 0
	hex_to_ascii cur_sc
	showpm cur_sc_mes_pref, hex_template
	
	mov al, byte ptr cur_sc
	cmp al, esc_key_code
		jne finish_handle
			showm esc_detected_mes
			
			mov ax, 2515h
			lds dx, dword ptr cs:old_handler
			int 21h
			
			mov ah, 49h
			int 21h
	
finish_handle:
	pop es
	pop ds
	popad
	iret
	
switch_on_old_handler:
	call cs:old_handler
	iret
	
break_handle:
	popf
	iret
	
new_handler endp
new_handler_end:

function_4fh_not_support_message db "Fail to load handler. Function 4fh not executed by interrupt 9h handler."
function_4fh_not_support_message_len = $ - function_4fh_not_support_message

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
	
	mov ah, 0c0h
	int 15h	
	movzx esi, bx
	add esi, 5
	lodsb
	test al, 10000b
	jnz function_4fh_not_support

		mov ah, 4fh
		mov ebx, new_handler_request_key
		int 15h
		cmp ebx, new_handler_answer_key
		je new_handler_already_load
			xor ebx, ebx
			get_int_handler 15h, old_handler
			set_int_handler 15h, new_handler
			print handler_load
			stay_resident new_handler_start, new_handler_end			
			
	function_4fh_not_support:
		print function_4fh_not_support_message
		jmp terminate_programm
		
	new_handler_already_load:
		print handler_already_load
		jmp terminate_programm
		
	terminate_programm:	
		terminate

end start
