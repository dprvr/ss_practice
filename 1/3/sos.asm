.model small
.stack 256
.data
sound_freq dw 1193180 / 1000
dot_msec equ 200000
dot dd dot_msec
dash dd dot_msec * 3
space dd dot_msec * 7
.code

DelayMSecs proc
push ax
mov ax, 8600h
int 15h
pop ax
ret
DelayMSecs endp

Delay macro msecs
push cx
push dx
mov cx, word ptr msecs[2]
mov dx, word ptr msecs[0]
call DelayMSecs
pop dx
pop cx
endm

TurnSoundOn proc
push ax
mov al, 10110110b
out 43h, al
mov al, byte ptr sound_freq[0]
out 42h, al
mov al, byte ptr sound_freq[2]
out 42h, al
in al, 61h
or al, 011b
out 61h, al
pop ax
ret
TurnSoundOn endp

TurnSoundOff proc
push ax
in al, 61h
and al, 1100b
out 61h, al
pop ax
ret
TurnSoundOff endp

SoundS proc
push cx
mov cx, 3
sound3dot:
	call TurnSoundOn
	Delay dot
	call TurnSoundOff
	Delay dot
loop sound3dot
pop cx
ret
SoundS endp

SoundO proc
push cx
mov cx, 3
sound3dash:
	call TurnSoundOn
	Delay dash
	call TurnSoundOff
	Delay dot
loop sound3dash
pop cx
ret
SoundO endp

SoundSOS proc
call SoundS
Delay dash
call SoundO
Delay dash
call SoundS
ret
SoundSOS endp

start:
mov AX, @data                
mov DS,AX

mov cx, 3
sound3SOS:
	call SoundSOS
	Delay space
loop sound3SOS

mov AX,4C00h 
int 21h
end start