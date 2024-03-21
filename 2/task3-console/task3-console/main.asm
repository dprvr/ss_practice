GetStdHandle proto
ReadConsoleA proto
WriteConsoleA proto
ExitProcess proto


.data
	hi_message db "This prog calculate the value of equation: f = (83 * k - 34) / (h - 68 * s)", 10
	hi_message_len = $ - hi_message
	
	type_k_message db "Please type value for k - "
	type_k_message_len = $ - type_k_message
	
	type_h_message db "Please type value for h - "
	type_h_message_len = $ - type_h_message
	
	type_s_message db "Please type value for s - "
	type_s_message_len = $ - type_s_message

	success_message db "The equation was calculated success, f = "
	success_message_len = $ - success_message

	error_input_message db "Calculating of equation can't be perform, some inputed params was invalid.", 0
	error_input_message_len = $ - error_input_message

	error_zero_div_message db "The value of denominator was zero. Can't calculate the value of equation.", 0
	error_zero_div_message_len = $ - error_zero_div_message

	input_buffer db 100 Dup(?)
	input_buffer_len = $ - input_buffer
	
	k_buffer db 10 dup(?)
	k_buffer_len = $ - k_buffer

	h_buffer db 10 dup(?)
	h_buffer_len = $ - h_buffer

	s_buffer db 10 dup(?)
	s_buffer_len = $ - s_buffer

	res_buffer db 10 dup(?)
	res_buffer_len = $ - res_buffer

.data?
	input_desc sqword ?
	output_desc sqword ?

	k_readed sqword ?
	h_readed sqword ?
	s_readed sqword ?

	k sqword ?
	h sqword ?
	s sqword ?

	read_num sqword ?
	write_num sqword ?

.code

write_to_console macro message, message_len
	sub rsp, 40
	mov rcx, output_desc
	lea rdx, message
	mov r8, message_len
	lea r9, write_num
	push 0
	call WriteConsoleA
	add rsp, 40
endm

read_from_console macro input_buffer, buffer_len, readed
	sub rsp, 40
	mov rcx, input_desc
	lea rdx, input_buffer
	mov r8, input_buffer_len
	lea r9, readed
	push 0
	call ReadConsoleA
	add rsp, 40
endm

;input rsi - str
;input rcx - str_len
;out rax - num
;out rbx - o if success else 1
convert_str_to_num proc
	push rdx
	push r8
	push r9

	xor rax, rax
	sub rcx, 2
	mov rbx, 10
	xor r9, r9
	cld

	for_each_symbol:
	xor rax, rax
	xor rdx, rdx	
	lodsb
	sub rax, '0'
	js on_fail_convert
	cmp rax, 9
	jg on_fail_convert
	mov r8, rcx
	dec rcx
	pow_digit:
	cmp rcx, 0
		jle end_pow
		mul rbx
		dec rcx
		jmp pow_digit
	end_pow:	
	mov rcx, r8
	add r9, rax
	loop for_each_symbol
	jmp on_success_convert 

	on_fail_convert:
	mov rbx, 1
	xor rax, rax
	jmp convert_exit 
	
	on_success_convert:
	mov rax, r9
	mov rbx, 0

	convert_exit:
	pop r9
	pop r8
	pop rdx
	xor rcx, rcx
	xor rsi, rsi
	ret
convert_str_to_num endp


;input rdi - outbuffer, rax - number
convert_num_to_str proc
	push rax
	push rbx
	push rcx
	push rdx
	push r8
	
	xor rcx, rcx	
	mov rbx, 10
	mov r8, 48

cnvrt_loop1:
	cmp rax, 0
	je cnvrt_loop1_end
	xor rdx, rdx
	div rbx
	add rdx, r8
	push rdx
	inc rcx
	jmp cnvrt_loop1

cnvrt_loop1_end:	
	mov rsi, 8
	xor rax, rax
cnvrt_loop2:
	pop rax
	stosb
	inc rsi
	loop cnvrt_loop2
	mov al, 0
	stosb

	pop r8
	pop rdx
	pop rcx
	pop rbx
	pop rax
ret
convert_num_to_str endp

start proc
	;rcx rdx r8 r9

	sub rsp, 32
	mov rcx, -11
	call GetStdHandle
	add rsp, 32
	mov output_desc, rax

	sub rsp, 32
	mov rcx, -10
	call GetStdHandle
	add rsp, 32
	mov input_desc, rax
	
	write_to_console hi_message, hi_message_len
	
	write_to_console type_k_message, type_k_message_len
	read_from_console k_buffer, k_buffer_len, k_readed

	write_to_console type_h_message, type_h_message_len
	read_from_console h_buffer, h_buffer_len, h_readed

	write_to_console type_s_message, type_s_message_len
	read_from_console s_buffer, s_buffer_len, s_readed

	xor r8, r8

	lea rsi, k_buffer
	mov rcx, k_readed
	call convert_str_to_num
	mov k, rax
	add r8, rbx

	lea rsi, h_buffer
	mov rcx, h_readed
	call convert_str_to_num
	mov h, rax
	add r8, rbx

	lea rsi, s_buffer
	mov rcx, s_readed
	call convert_str_to_num
	mov s, rax
	add r8, rbx

	cmp r8, 0
	jne on_input_error

	mov rax, s
	mov r8, 68
	mul r8
	mov rbx, h
	sub rbx, rax
	cmp rbx, 0
	je on_zero_div_error
	mov rax, k
	mov r8, 83
	mul r8
	sub rax, 34
	div rbx

	lea rdi, res_buffer
	call convert_num_to_str

	on_success_calc:
		write_to_console success_message, success_message_len 
		write_to_console res_buffer, res_buffer_len
		jmp exit

	on_zero_div_error:
		write_to_console error_zero_div_message, error_zero_div_message_len
		jmp exit

	on_input_error:
		write_to_console error_input_message, error_input_message_len
		jmp exit

	exit:
	mov rcx, 0
	call ExitProcess
start endp
end