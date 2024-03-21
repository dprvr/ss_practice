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

rb_seg dw 0040h

rb_begin_offset dw 0080h
rb_end_offset dw 0082h
rb_head_offset dw 001ah
rb_tail_offset dw 001ch
rb_flags_offset dw 0017h

rb_head dw 0
rb_tail dw 0
rb_begin dw 0
rb_end dw 0
rb_flags dw 0

hex_map db '0123456789ABCDEF'

hex_template db 'iih'
hex_template_len = $ - hex_template

bin_template db 'dddddddd'
bin_template_len = $ - bin_template

rb_begin_pref db 'RB begin: '
rb_begin_pref_len = $ - rb_begin_pref

rb_head_pref db 'RB head: '
rb_head_pref_len = $ - rb_head_pref

rb_tail_pref db 'RB tail: '
rb_tail_pref_len = $ - rb_tail_pref

rb_end_pref db 'RB end: '
rb_end_pref_len = $ - rb_end_pref

rb_flags_pref db 'RB flags: '
rb_flags_pref_len = $ - rb_flags_pref

rb_flags_template db "00000000b : 00000000b"
rb_flags_template_len = $ - rb_flags_template

rb_content_pref db 'RB content:'
rb_content_pref_len = $ - rb_content_pref

hex_word_template db '0000h'
hex_word_template_len = $ - hex_word_template

key_code_template db '_:00h'
key_code_template_len = $ - key_code_template

update_freq dd 18 * 5
next_update_ticks dd 0

vm_cur_row dw 0

esc_key_code db 01h
esc_key_detected db 0h

esc_detected_message db 'The esk key was typed - prog terminated...'
esc_detected_message_len = $ - esc_detected_message
		

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

;in ax word
;in edi
hexw_to_ascii proc
	lea edi, hex_word_template + 2
	call convert_hex_to_ascii
	mov al, ah
	sub edi, 2
	call convert_hex_to_ascii
	ret
hexw_to_ascii endp

;in al
;in edi
convert_binary_to_ascii proc
	push ecx
	mov ecx, 8
	for_each_bit:
		xor ebx, ebx
		test al, 10000000b
		setne bl
		add bl, '0'
		mov byte ptr [edi], bl
		shl al, 1
		inc edi	
	loop for_each_bit
	pop ecx
	ret
convert_binary_to_ascii endp

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
	push ecx esi edi
	lea esi, message
	mov ecx, &message&_len
	movzx edi, word ptr vm_cur_row
	call copy_message_to_vm
	add vm_cur_row, 160
	pop edi esi ecx
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


;in bx seg_offset
;out ax
lodw_from_kd proc
	push es
	mov ax, rb_seg
	mov es, ax
	mov ax, word ptr es:bx
	pop es
	ret
lodw_from_kd endp


savew_from_kd macro seg_offset, store
	mov bx, seg_offset
	call lodw_from_kd
	mov word ptr store, ax
endm


clear_rb proc
	push es eax ebx ecx
	mov ax, rb_seg	
	mov es, ax
	
	mov bx, rb_begin
	mov ecx, 16
	clear_each_sc:
		mov word ptr es:bx, 0000h
		add bx, 02h
	loop clear_each_sc
	pop ecx ebx eax es
	ret
clear_rb endp


save_kd_state macro
	push eax ebx
	savew_from_kd rb_begin_offset, rb_begin
	savew_from_kd rb_head_offset, rb_head
	savew_from_kd rb_tail_offset, rb_tail
	savew_from_kd rb_end_offset, rb_end
	savew_from_kd rb_flags_offset, rb_flags
	pop ebx eax
endm


show_kd_state macro
	push eax edi
	
	mov ax, word ptr rb_begin
	call hexw_to_ascii
	showpm rb_begin_pref, hex_word_template
	
	mov ax, word ptr rb_head
	call hexw_to_ascii
	showpm rb_head_pref, hex_word_template
	
	mov ax, word ptr rb_tail
	call hexw_to_ascii
	showpm rb_tail_pref, hex_word_template
	
	mov ax, word ptr rb_end
	call hexw_to_ascii
	showpm rb_end_pref, hex_word_template
	
	mov ax, word ptr rb_flags
	lea edi, rb_flags_template
	call convert_binary_to_ascii
	add edi, 4
	mov al, ah
	call convert_binary_to_ascii
	showpm rb_flags_pref, rb_flags_template
	
	pop edi eax
endm


show_rb_content macro
	local end_load, continue_load, for_each_sc
	push eax ebx ecx edi
	showm rb_content_pref
	
	mov ecx, 16
	mov bx, rb_begin
	
	print_each_sc:
		cmp ecx, 0
		jle end_load
			call lodw_from_kd
			lea edi, key_code_template
			mov byte ptr edi[0], al
			
			mov al, ah
			add edi, 2		
			call convert_hex_to_ascii				
			add bx, 2
			
			showm key_code_template
			
			dec ecx
			
			cmp ah, byte ptr esc_key_code
			jne print_each_sc
				mov byte ptr esc_key_detected, 1				
	end_load:
	call clear_rb
	pop edi ecx ebx eax
endm

;out dx
read_rtc_ticks macro
	push eax ecx
	xor edx, edx
	xor ecx, ecx
	mov ah, 00h
	int 1ah
	shr ecx, 16
	add edx, ecx
	pop ecx eax
endm


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

	on_time_change:
		add edx, dword ptr update_freq
		mov dword ptr next_update_ticks, edx
		
		mov ax, 0003h
		int 10h
		mov word ptr vm_cur_row, 160 * 2
		
		save_kd_state
		show_kd_state
		show_rb_content		
		
		movzx eax, byte ptr esc_key_detected
		cmp eax, 1
		jl finish_handle
		
		mov ax, 0003h
		int 10h		
		
		mov vm_cur_row, 60
		showm esc_detected_message
		
		mov ax, 251ch
		lds dx, dword ptr cs:old_handler
		int 21h
		
		mov ax, 4900h
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
	xor eax, eax

	get_int_handler 1ch, old_handler
	set_int_handler 1ch, new_handler
	
	mov ax, 0305h 
	xor ebx, ebx
	int 16h
	
	print handler_load
	stay_resident new_handler_start, new_handler_end	
	
new_handler_already_load:
	print handler_already_load
	terminate

end start
