GetStdHandle proto
ReadConsoleA proto
WriteConsoleA proto
ExitProcess proto



LISTS struct
    Litems byte 30 dup(' ')
LISTS ends


CARS struct
	Cid byte ?
	Cname LISTS {}
	Crelease LISTS {}
	Cbrand LISTS {}
	Cpower LISTS {}
CARS ends


.data

	welcome_message db "This prog can print info about some Cars models.", 10, 13

	help_message db "For full info about cars type f", 10, 13,
				 "For info about cars names type n", 10, 13,
				 "For info about cars releases type r", 10, 13,
				 "For info about cars powers type p", 10, 13,
				 "For info about cars brands type b", 10, 13,
				 "For info about commands type h", 10, 13,
				 "To finish work with prog type e", 10, 13, 0

	waiting_message db 10, 13, "... Type command - "
	
	arg_error_message db "The input argument doesn't exist...", 10, 13

	exit_message db "...best regards...", 10, 13

	input_buffer db 30 dup(?)
	output_buffer db 150 dup(?)
	clean_buffer db 150 dup(?)

	carsdb CARS {'1', {"Voyah Dreamer"}, {"10.2023"}, {"Voyah"}, {"435 ls"}}
		CARS {'2', {"Jeep Wrangler IV"}, {"9.2023"}, {"Jeep"}, {"380 ls"}}
		CARS {'3', {"Audi TTS Roadster"}, {"11.2022"}, {"Audi"}, {"360 ls"}}
		CARS {'4', {"Ford Expedition SUV IV"}, {"2021"}, {"Ford"}, {"400 ls"}}		
		CARS {'5', {"Baojun E300 Plus"}, {"May 2020"}, {"Baojun"}, {"54 Hp"}}
		CARS {'6', {"Fiat Topolino"}, {"2023"}, {"Fiat"}, {"8 Hp"}}
		CARS {'7', {"Audi A6 Avant"}, {"June 2023"}, {"Audi"}, {"143 Hp"}}

	cars_count sqword 7
	list_size sqword 30

	stdin_desc sqword ?
	stdout_desc sqword ?

	read_num sqword ?
	write_num sqword ?

	car_print_format db ?
	
	exit_arg db 'e'
	help_arg db 'h'	
	names_arg db 'n'
	brands_arg db 'b'
	releases_arg db 'r'
	powers_arg db 'p'
	full_info_arg db 'f'


.code

get_stdout_desc macro out_stdout_desc
	sub rsp, 32
	mov rcx, -11
	call GetStdHandle
	add rsp, 32
	mov out_stdout_desc, rax
endm

get_stdin_desc macro out_stdin_desc
	sub rsp, 32
	mov rcx, -10
	call GetStdHandle
	add rsp, 32
	mov out_stdin_desc, rax
endm

clear_buffer proc
	pushf
	push rdi
	push rax
	push rcx
	push rsi

	lea rdi, output_buffer
	lea rsi, clean_buffer
	mov rcx, lengthof output_buffer
	rep movsb

	pop rsi
	pop rcx
	pop rax
	pop rdi
	popf
	ret
clear_buffer endp


;rax - to print addr
;rbx - to print len
print_to_console proc 
	push rcx
	push rdx
	push r8
	push r9
	push rax
	
	sub rsp, 32
	mov rcx, stdout_desc
	mov rdx, rax
	mov r8, rbx
	lea r9, write_num
	push 0
	call WriteConsoleA	
	add rsp, 40

	pop rax
	pop r9
	pop r8
	pop rdx
	pop rcx	
	ret
print_to_console endp


write_to_console macro message
	lea rax, message
	mov rbx, lengthof message
	call print_to_console
endm


read_fromConsole macro _buffer
	sub rsp, 40
	mov rcx, stdin_desc
	lea rdx, _buffer
	mov r8, lengthof _buffer
	lea r9, read_num
	push 0
	call ReadConsoleA
	add rsp, 40
endm


;rax - car id
;loaded info format - 0(p)(r)(b)(n)(i)b
load_car_to_buffer proc
	push rax
	push r8
	push rbx
	push rcx	

	dec rax
	mov r8, type CARS
	mul r8
	lea rbx, carsdb
	add rbx, rax

	lea rdi, output_buffer
	movzx r9, car_print_format


	load_id:
		test r9, 1
		jz load_name
			mov al, byte ptr [rbx].CARS.Cid
			stosb
			mov al, '|'
			stosb

	load_name:
		test r9, 10b
		jz load_brand
			lea rsi, [rbx].CARS.Cname
			mov rcx, list_size
			rep movsb
			mov al, '|'
			stosb

	load_brand:
		test r9, 100b
		jz load_release
			lea rsi, [rbx].CARS.Cbrand
			mov rcx, list_size
			rep movsb
			mov al, '|'
			stosb

	load_release:
		test r9, 1000b
		jz load_power 
			lea rsi, [rbx].CARS.Crelease
			mov rcx, list_size
			rep movsb
			mov al, '|'
			stosb

	load_power:
		test r9, 10000b
		jz finish_load
			lea rsi, [rbx].CARS.Cpower
			mov rcx, list_size
			rep movsb
			mov al, '|'
			stosb
	
	finish_load:
		mov al, 10
		stosb
		mov al, 13
		stosb
			
	xor rsi, rsi
	xor rdi, rdi

	pop rcx
	pop rbx
	pop r8
	pop rax
	ret
load_car_to_buffer endp


write_cars_to_console proc
	push rbx
	push rcx
	push rax
	push r9

	mov rbx, 1
	print_each_car:
		mov rax, rbx
		call load_car_to_buffer
		push rbx
		lea rax, output_buffer
		mov rbx, lengthof output_buffer
		call print_to_console
	    call clear_buffer
		pop rbx
		inc rbx
		cmp rbx, cars_count
		jle print_each_car
	
	pop r9
	pop rax
	pop rcx
	pop rbx
	ret
write_cars_to_console endp


start proc
	
	get_stdout_desc stdout_desc
	get_stdin_desc stdin_desc
	jmp on_start

	on_start:
	write_to_console welcome_message
	write_to_console help_message
	jmp waiting

	waiting:
		write_to_console waiting_message	
		read_fromConsole input_buffer

		cmp read_num, 3
		jne on_arg_error

		cmp input_buffer, 'f'
		je print_full

		cmp input_buffer, 'n'
		je print_name

		cmp input_buffer, 'r'
		je print_release

		cmp input_buffer, 'b'
		je print_brand

		cmp input_buffer, 'p'
		je print_power

		cmp input_buffer, 'h'
		je print_help

		cmp input_buffer, 'e'
		je on_exit		
		
		jmp on_arg_error

	print_full:
		mov car_print_format, 11111b
		call write_cars_to_console
		jmp waiting	
		
	print_brand:
		mov car_print_format, 00110b
		call write_cars_to_console 
		jmp waiting

	print_name:
		mov car_print_format, 00011b
		call write_cars_to_console 
		jmp waiting

	print_power:
		mov car_print_format, 10010b
		call write_cars_to_console 
		jmp waiting
	
	print_release:
		mov car_print_format, 01010b
		call write_cars_to_console 
		jmp waiting

	print_help:
		write_to_console help_message
		jmp waiting	
	
	on_arg_error:
		write_to_console arg_error_message 
		jmp waiting

	on_exit:
		write_to_console exit_message 
		mov rcx, 0
		call ExitProcess

start endp
end