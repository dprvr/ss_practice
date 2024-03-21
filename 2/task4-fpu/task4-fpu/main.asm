ExitProcess proto

.data
	
	item_size = 32
	items_count = 4
	pic_array dd 4 dup(?)	
	vec_array dd 10, 20, 30, 40
	
.code

start proc

	mov rcx, items_count
	lea rdi, pic_array
	mov rbx, 5
	cld
	fill_pic_loop:
		mov rax, 100
		mul rbx
		stosd
		inc rbx
	loop fill_pic_loop

	movaps xmm0, pic_array
	movaps xmm1, vec_array

	mov rcx, items_count
	vec_mul_loop:
		pmulld xmm0, xmm1
	loop vec_mul_loop 

	mov rcx, 0
	call ExitProcess
start endp
end