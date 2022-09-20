section .text
 
; Принимает код возврата и завершает текущий процесс

exit: 
    mov		rax, 60 	; 'exit' syscall number
    syscall
    ret 

; Принимает указатель на нуль-терминированную строку, возвращает её длину

string_length:
    xor rax, rax
    .main_loop:
        cmp 	byte[rdi + rax], 0 
        je	.end
        inc 	rax
        jmp 	.main_loop
    .end:
        ret
		
; Принимает указатель на нуль-терминированную строку, выводит её в stdout

print_string:
    call 	string_length
    mov 	rsi, rdi
    mov 	rdx, rax	
    mov 	rax, 1		; 'write' syscall number
    mov 	rdi, 1		; stdout descriptor
    syscall
    ret

; Принимает код символа и выводит его в stdout

print_char:
    xor 	rax, rax
    push 	rdi
    mov 	rsi, rsp
    pop 	rax
    mov 	rdx, 1
    mov 	rax, 1		; 'write' syscall number
    mov 	rdi, 1		; stdout descriptor
    syscall
    ret

; Переводит строку (выводит символ с кодом 0xA)

print_newline:
    mov 	rdi, 0xA
    call 	print_char
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.

print_uint:
    xor 	rcx, rcx
    xor 	rdx, rdx
    mov 	rbx, 10		; divider to get digits
    mov 	rax, rdi
    .stack_filling:
        xor 	rdx, rdx
        div 	rbx		; next digit
        add 	rdx, '0'	; offset to save ascii-code
        push 	rdx
        inc 	rcx
        test 	rax, rax	; loop while rax has content 
        jnz 	.stack_filling
    .print_from_stack:
        pop 	rdx
        mov 	rdi, rdx
        push 	rcx		; save reg value before calling
        call 	print_char
        pop 	rcx
        dec 	rcx
        test 	rcx, rcx	; loop while rcx > 0
        jnz 	.print_from_stack
        xor 	rbx, rbx	; respect convention :)
        ret

; Выводит знаковое 8-байтовое число в десятичном формате 

print_int:
    or 		rdi, rdi		; set flags
    jns 	.end			; if number is positive just print it!
    push 	rdi			; else add '-'
    mov 	rdi, '-'
    call 	print_char
    pop 	rdi
    neg 	rdi
    .end:
        jmp 	print_uint
        ret

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе

string_equals:
    call 	string_length
    mov 	r8, rdi
    mov 	r9, rax
    mov 	rdi, rsi
    call 	string_length
    cmp 	r9, rax		; compare lengths
    jne 	.not_equals
    mov 	rcx, 0
    mov 	rsi, r8
    .char_loop:			
        cmp 	rcx, r9
        je 	.equals
        mov 	al, byte[rsi + rcx]
        mov 	dl, byte[rdi + rcx]
        cmp 	al, dl		; compare each chars
        jne 	.not_equals
        inc 	rcx
        jmp 	.char_loop
    .not_equals:
        xor 	rax, rax	; false
        ret
    .equals:
        mov 	rax, 1		; true
        ret	

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока

read_char:
    xor		rax, rax
    xor 	rdi, rdi
    push 	0
    mov 	rdx, 1			; length
    mov 	rsi, rsp		; descriptor
    syscall
    pop 	rax
    ret 

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор

read_word:
    xor 	rcx, rcx
    push 	rdi		; save regs values before calling
    push 	rsi
    push 	rcx
    .spaces_skip_loop:
        call 	read_char
        cmp 	rax, 0x20
        je 	.spaces_skip_loop
        cmp 	rax, 0x9
        je 	.spaces_skip_loop
        cmp 	rax, 0xA
        je 	.spaces_skip_loop
    .main_loop:
        pop 	rcx		; get regs values after calling
        pop 	rsi			
        pop 	rdi
        test 	rax, rax	; check overflow
        jz 	.end
        cmp 	rax, 0x20	; check spaces again :(
        je 	.end
        cmp 	rax, 0x9
        je 	.end
        cmp 	rax, 0xA
        je 	.end
        mov 	[rdi + rcx], al
        inc 	rcx		; counter
        dec 	rsi
        jz 	.end
        push	rdi		; save regs values before calling
        push	rsi
        push	rcx
        call 	read_char
        jmp 	.main_loop
    .end:
        test 	rsi, rsi	; check rsi = 0?
        jnz 	.success	; overflow
        xor 	rax, rax	
        ret
    .success:
        mov 	byte[rdi + rcx], 0
        mov 	rax, rdi
        mov 	rdx, rcx
        ret

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось

parse_uint:
    xor 	rax, rax
    xor 	rcx, rcx
    mov 	rbx, 10			; divider to get digits
    .read_digit:
        xor 	r8, r8
        mov 	r8b, byte [rdi + rcx]
        sub 	r8, '0'			; set offset for ascii-code
        cmp 	r8, 0		
        jl 		.end		; no-digit char found
        cmp 	r8, 9
        jg 		.end		; no-digit char found
        mul 	rbx			
        add 	al, r8b			; save current digit
        inc 	rcx
        jmp 	.read_digit
    .parse_error:
        mov 	rdx, 0		
        ret
    .end:
        xor 	rbx, rbx		; respect convention :)
        cmp 	rcx, 0
        je 		.parse_error	; line started with not a digit char
        mov 	rdx, rcx
        ret

; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось

parse_int:
    cmp 	byte [rdi], '-'	
    jne 	parse_uint		
    inc 	rdi				; case with neg number
    call 	parse_uint
    neg 	rax
    inc 	rdx
    ret 


; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0

string_copy:
    call 	string_length		; check overflow
    cmp 	rax, rdx
    jge 	.overflow	
    xor 	rax, rax
    xor 	rdx, rdx
    .copy_next:
        mov 	dl, [rdi + rax]
        mov 	[rsi + rax], dl
        test 	dl, dl			; if string length = 0 then goto end
        je 		.end
        inc 	rax
        jmp 	.copy_next
    .overflow:
        xor 	rax, rax
    .end:
        xor 	rdx, rdx		; respect convention :)
        ret