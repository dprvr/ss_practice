ExitProcess proto
MessageBoxA proto

.data
	window_caption db "TASK-2", 0
	zero_division_message db "Error can't divide on zero", 0
	message_prefix db "T – Y / R = "
	message_prefix_len = $ - message_prefix
	res_buf db 10 dup(?)
	res_buf_len = $ - res_buf
	message_buf db 60 dup(?)
	

	t db 20
	y db 10
	r db 2

.code

cnvrt_num_to_str proc
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
cnvrt_num_to_str endp

start proc
	
	movzx rax, t
	movzx rdx, y
	sub rax, rdx
	xor rdx, rdx
	movzx rbx, r
	cmp rbx, 0
	je print_error
	div rbx
	
	lea rdi, res_buf
	call cnvrt_num_to_str
	
	lea rsi, message_prefix
	lea rdi, message_buf
	mov rcx, message_prefix_len
	cld
	rep movsb

	lea rsi, res_buf
	lea rdi, message_buf + message_prefix_len
	mov rcx, 2
	cld
	rep movsb

	sub rsp, 28h
	mov rcx, 0
	lea r8, window_caption
	lea rdx, message_buf
	mov r9, 0
	call MessageBoxA
	jmp pg_exit
	
	print_error:
	sub rsp, 28h
	mov rcx, 0
	lea r8, window_caption
	lea rdx, zero_division_message
	mov r9, 0
	call MessageBoxA

	pg_exit:
	mov rcx, 0
	call ExitProcess
start endp
end