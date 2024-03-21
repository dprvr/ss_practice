ExitProcess proto
MessageBoxA proto

.data
	window_caption db "TASK-1", 0
	window_message db "Hands up", 10, "Hands up!", 10, "Hands down!", 10, "Hands on hips.", 10, "And sit down!", 0

.code
start proc
	sub rsp, 28h
	mov rcx, 0
	lea r8, window_caption
	lea rdx, window_message
	mov r9, 0
	call MessageBoxA

	mov rcx, 0
	call ExitProcess
start endp
end