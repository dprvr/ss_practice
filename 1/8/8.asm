StackSegment segment para stack 'stack'
db 256 dup(?)
StackSegment ends
DataSegment segment para public 'data'

scan_codes db 2, 3, 4, 5, 6, 7, 8, 9, 10
scan_codes_len = $ - scan_codes

ascii_codes db '123456789'
ascii_codes_len = $ - ascii_codes

typed_message_pref db "YOU TYPED:: "
typed_message_pref_len = $ - typed_message_pref

typed db 50 dup (' ')
typed_len = $ - typed

DataSegment ends
CodeSegment segment para public 'code'
	assume cs:CodeSegment, ds:DataSegment, ss:StackSegment, es:DataSegment

	
;dx - message addr
;cx - message len
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


terminate macro
mov ax, 4c00h
int 21h
endm


start:
	mov ax, DataSegment
	mov ds, ax
	mov es, ax
	xor ax, ax
	
	lea di, typed
	xor cx, cx
	add cx, scan_codes_len
	xor bx, bx
	cld
	foreach_code:
		push cx
		
		mov ax, 0500h
		mov ch, scan_codes[bx]
		mov cl, ascii_codes[bx]
		int 16h
		
		mov ax, 1000h
		int 16h
		stosb
		
		inc bx
		pop cx			
	loop foreach_code
	
	print typed_message_pref
	print typed
	
	terminate
CodeSegment ends
end start