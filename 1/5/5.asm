.model small
.stack 256
.data

hex_map db '0123456789ABCDEF'

hex_template db 'iih'
hex_template_len = $ - hex_template

bin_template db 'ddddddddb'
bin_template_len = $ - bin_template

ps_data_port equ 60h
ps_control_port equ 64h

ps_read_master_byte_com equ 20h
ps_write_master_byte_com equ 60h
ps_read_lines_state_com equ 0e0h
ps_read_input_port_com equ 0c0h
ps_read_output_port_com equ 0d0h

terminate_key db 01h

ps_state_before_read db 0
typed_key db 0
ps_state_after_read db 0
ps_master_byte db 0
ps_lines_state db 0
ps_input_port db 0
ps_output_port db 0

new_line db 10, 13
new_line_len = $ - new_line

wait_key_input_message db '.................Type key.................', 10, 13
wait_key_input_message_len = $ - wait_key_input_message

key_typed_message db '.....................The key was typed........................', 10, 13
key_typed_message_len = $ - key_typed_message

terminate_message db '...best_regards...', 10, 13
terminate_message_len = $ - terminate_message

welcome_message db '...started...', 10, 13
welcome_message_len = $ - welcome_message

ps_state_pref db 'PS state: '
ps_state_pref_len = $ - ps_state_pref

ps_data_reg_pref db 'PS data reg: '
ps_data_reg_pref_len = $ - ps_data_reg_pref

ps_master_byte_pref db 'PS master byte: '
ps_master_byte_pref_len = $ - ps_master_byte_pref

ps_input_port_pref db 'PS input port: '
ps_input_port_pref_len = $ - ps_input_port_pref

ps_out_port_pref db 'PS output port: '
ps_out_port_pref_len = $ - ps_out_port_pref

ps_lines_state_pref db 'PS lines state port: '
ps_lines_state_pref_len = $ - ps_lines_state_pref

.code

;in al
;in edi out save
convert_hex_to_ascii proc
push ax
push bx
push cx

mov ah, al
and al, 1111b
mov bl, al
mov al, hex_map[bx]
mov byte ptr di[1], al
mov al, ah
mov cl, 4
shr al, cl
mov bl, al
mov al, hex_map[bx]
mov byte ptr di[0], al

pop cx
pop bx
pop ax
ret
convert_hex_to_ascii endp


hex_to_ascii macro
push di
lea di, hex_template
call convert_hex_to_ascii
pop di
endm

;in al
;in edi
convert_binary_to_ascii proc
push ax
push cx
mov cx, 8
for_each_bit:
	push cx
	xor bx, bx
	test al, 10000000b
	jz set_zero
		mov byte ptr di[0], '1'
		jmp continue
	set_zero:
		mov byte ptr di[0], '0'
	continue:
	mov cl, 1
	shl al, cl
	inc di
	pop cx
loop for_each_bit
pop cx
pop ax
ret
convert_binary_to_ascii endp

;in al
bin_to_ascii macro
push di
lea di, bin_template
call convert_binary_to_ascii
pop di
endm

print_in_hex macro pref, val
	push ax
	mov al, byte ptr val
	hex_to_ascii
	print pref
	print hex_template
	print new_line
	pop ax
endm

print_in_binary macro pref, val
	push ax
	mov al, byte ptr val	
	bin_to_ascii
	print pref
	print bin_template
	print new_line
	pop ax
endm


print_message proc
push ax
push bx
mov ah, 40h
mov bx, 1
int 21h
pop bx
pop ax
ret
print_message endp


print macro message
push dx
push cx
lea dx, message
mov cx, &message&_len
call print_message
pop cx
pop dx
endm


;out al
read_ps_state macro
	in al, ps_control_port
endm


wait_while_ps_input_full macro
	local while_input_full	
	push ax
	while_input_full:
		read_ps_state
		test al, 10b
	jnz while_input_full
	pop ax
endm


wait_while_ps_output_empty macro
	local while_output_empty	
	push ax
	while_output_empty:
		read_ps_state
		test al, 1b
	jz while_output_empty
	pop ax
endm


;out al
read_ps_data proc	
	wait_while_ps_output_empty
	in al, ps_data_port
	ret
read_ps_data endp


;in al com to ps
send_com_to_ps proc
	wait_while_ps_input_full
	out ps_control_port, al
	ret
send_com_to_ps endp


;in al
send_com_to_kd proc
	wait_while_ps_input_full
	out ps_data_port, al
	ret
send_com_to_kd endp


;in al - 0 - disable, 1 - enable
set_ps_ints proc
	push ax bx
	cli
	mov bl, al
	mov al, ps_read_master_byte_com
	call send_com_to_ps
	call read_ps_data
	test bl, 1h
		jnz enable_ints
	disable_ints:
		and al, 11111110b
		jmp set_ints
	enable_ints:
		or al, 1b
	set_ints:
		mov ah, al
		mov al, ps_write_master_byte_com
		call send_com_to_ps
		mov al, ah
		call send_com_to_kd
	sti
	pop bx ax
	ret
set_ps_ints endp


enable_ps_ints macro
push ax
mov al, 1
call set_ps_ints
pop ax
endm

disable_ps_ints macro
push ax
mov al, 0
call set_ps_ints
pop ax
endm


read_ps_inner_reg macro ps_read_com, store
	mov al, ps_read_com
	call send_com_to_ps
	call read_ps_data
	mov byte ptr store, al
	xor ax, ax
endm


save_ps_state proc
	push ax
	cli
	read_ps_state
	mov byte ptr ps_state_before_read, al
	
	call read_ps_data
	mov byte ptr typed_key, al
	
	read_ps_state
	mov byte ptr ps_state_after_read, al
	
	read_ps_inner_reg ps_read_master_byte_com, ps_master_byte	
	read_ps_inner_reg ps_read_lines_state_com, ps_lines_state	
	read_ps_inner_reg ps_read_input_port_com, ps_input_port	
	read_ps_inner_reg ps_read_output_port_com, ps_output_port
	sti
	pop ax
	ret
save_ps_state endp


print_ps_state proc
	print key_typed_message	
	print_in_binary ps_state_pref, ps_state_before_read
	print_in_hex ps_data_reg_pref, typed_key
	print_in_binary ps_state_pref, ps_state_after_read
	print_in_binary ps_master_byte_pref, ps_master_byte
	print_in_binary ps_lines_state_pref, ps_lines_state
	print_in_binary ps_input_port_pref, ps_input_port
	print_in_binary ps_out_port_pref, ps_output_port
	ret
print_ps_state endp


terminate macro
mov ax, 4c00h
int 21h
endm


start:
	mov ax, @data
	mov ds, ax
	mov es, ax
	
	disable_ps_ints
	print welcome_message

	wait_key_input:
		wait_while_ps_output_empty
		call save_ps_state
		test typed_key, 80h
		jnz wait_key_input
		call print_ps_state	
			mov al, byte ptr typed_key
			cmp al, byte ptr terminate_key
				jne wait_key_input

	enable_ps_ints
	print terminate_message
	terminate
end start

