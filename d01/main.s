; libSystem.fdopen
;     (fd : int / i32 {x0}, mode : *char / *u8 {x1})
;     -> (file : *FILE {x0})
.extern _fdopen
; libSystem.feof
;     (file : *FILE {x0})
;     -> (eof : bool / i32)
.extern _feof
; libSystem.fprintf
;     (file : *FILE {x0}, fmt : *char / *u8 {x1}, ???... {[sp]})
;     -> (written : int / i32 {x0})
.extern _fprintf
; libSystem.getline
;     (linebuf : **char / **u8 {x0}, sizep : *size_t / *u64 {x1}, file : *FILE {x2})
;     -> (read : ssize_t / i64 {x0})
.extern _getline
; libSystem.strtoull
;     (str : *char / *u8 {x0}, str_end : **char / **u8 {x1}, base : int / i32)
;     -> (number : ull / u64 {x0})
.extern _strtoull
; libSystem.free
;     (ptr : *any / *void {x0})
;     -> unit
.extern _free
; libSystem.exit
;     (status : int / i32 {x0})
;     -> nothing
.extern _exit

.global _main
.align 4

.text
; should eventually go unused
; unfortunately error handling is hard
panic: brk #1

; init_stdin_stdout
;     ()
;     -> (stdin : *FILE {x0}, stdout : *FILE {x1})
init_stdin_stdout:
    ; begin init_stdin_stdout
    ; saved registers:
    ;     x19
    ;     x20
    ;     lr
    ;     fp
    ; allocate 32 bytes
    sub sp, sp, #32
    stp x20, x19, [sp, #16]
    stp fp, lr, [sp]
    ; save new frame pointer
    mov fp, sp

    ; fd = STDOUT_FILENO
    mov x0, #1
    ; mode = &w_str
    adrp x1, w_str@PAGE
    add x1, x1, w_str@PAGEOFF
    ; x19 = fdopen(STDOUT_FILENO, "w")
    bl _fdopen
    mov x19, x0

    ; fd = STDIN_FILENO
    mov x0, #0
    ; mode = &r_str
    adrp x1, r_str@PAGE
    add x1, x1, r_str@PAGEOFF
    ; x0 = fdopen(STDIN_FILENO, "r")
    bl _fdopen

    ; x1 = x19
    mov x1, x19

    ; end init_stdin_stdout
    ldp x20, x19, [sp, #16]
    ldp fp, lr, [sp]
    add sp, sp, #32

    ret

; calorie_group_sum
;     (stdin : *FILE {x0})
;     -> (sum : ull / u64 {x0})
calorie_group_sum:
    ; begin calorie_group_sum
    ; saved registers:
    ;     x19
    ;     x20
    ;     lr
    ;     fp
    ; stack variables:
    ;     line_buf : *char / *u8 = NULL
    ;     buf_size : size_t / u64
    ; allocate 48 bytes
    sub sp, sp, #48
    stp x20, x19, [sp, #32]
    stp fp, lr, [sp, #16]
    ; save new frame pointer
    add fp, sp, #16
    ; line_buf @ [sp, #8] = 0
    str xzr, [sp, #8]
    ; buf_size @ [sp, #0]

    ; back up stdin
    mov x19, x0
    ; initialize sum to 0
    mov x20, xzr

.line_loop:
    ; read a line from stdin
    ; linebuf = &line_buf
    add x0, sp, #8
    ; sizep = &buf_size
    add x1, sp, #0
    ; file = stdin
    mov x2, x19
    ; getline(&line_buf, &buf_size, stdin)
    bl _getline

    ; if the return value is not -1, read was successful
    cmn x0, #1
    bne .line_loop_body
    ; otherwise, check eof
    mov x0, x19
    bl _feof
    ; if it's zero, panic
    cbz x0, panic
    ; otherwise, we hit the end of the file
    b .line_loop_done

.line_loop_body:
    ; we have a string in [sp, #8] and its length in x0
    ; if the string ends with a newline, we strip it
    ; x1 = string
    ldr x1, [sp, #8]
    ; x2 = length - 1
    sub x2, x0, #1
    ; if the last character is newline
    ldrb w3, [x1, x2]
    cmp w3, '\n'
    ; check for empty line, else remove trailing newline
    beq .line_loop_newline_checks

.line_loop_newline_checks_pass:
    ; we can use strtoull to extract our number
    ; str = line_buf
    mov x0, x1
    ; str_end = NULL
    mov x1, #0
    ; base = 10
    mov x2, #10
    ; x0 = strtoull(line_buf, NULL, 10)
    bl _strtoull

    ; add this to our sum
    add x20, x20, x0

    ; read next line
    b .line_loop

.line_loop_newline_checks:
    ; if length == 1, our line is empty
    cmp x2, #0
    beq .line_loop_done
    ; otherwise, store a null byte
    strb wzr, [x1, x2]
    b .line_loop_newline_checks_pass

.line_loop_done:
    ; free the string allocated by getline
    ldr x0, [sp, #8]
    bl _free

    ; return the sum
    mov x0, x20

    ; end calorie_group_sum
    ldp x20, x19, [sp, #32]
    ldp fp, lr, [sp, #16]
    add sp, sp, #48

    ret

; calorie_groups_max
;     (stdin : *FILE {x0})
;     -> (max : ull / u64 {x0})
calorie_groups_max:
    ; begin calorie_groups_max
    ; saved registers:
    ;     x19
    ;     x20
    ;     lr
    ;     fp
    ; allocate 32 bytes
    sub sp, sp, #32
    stp x20, x19, [sp, #16]
    stp fp, lr, [sp, #0]
    ; save new frame pointer
    mov fp, sp

    ; back up stdin
    mov x19, x0
    ; initialize maximum to 0
    mov x20, #0

.group_loop:
    ; check eof
    mov x0, x19
    bl _feof
    ; if nonzero, return maximum
    cbnz x0, .group_loop_done
    ; otherwise, get the next group's sum
    mov x0, x19
    bl calorie_group_sum

    ; compare the new sum with our current maximum
    cmp x0, x20
    ; select whichever is bigger
    csel x20, x0, x20, hs

    ; do next group
    b .group_loop

.group_loop_done:
    ; return max
    mov x0, x20

    ; end calorie_groups_max
    ldp x20, x19, [sp, #16]
    ldp fp, lr, [sp, #0]
    add sp, sp, #32

    ret

_main:
    ; begin main
    ; saved registers:
    ;     x19
    ;     x20
    ;     lr
    ;     fp
    ; allocate 32 bytes
    sub sp, sp, #32
    stp x20, x19, [sp, #16]
    stp fp, lr, [sp, #0]
    ; save new frame pointer
    mov fp, sp

    ; x0 = stdin, x1 = stdout
    bl init_stdin_stdout
    ; x19 = stdin, x20 = stdout
    mov x19, x0
    mov x20, x1

    ; fprintf args.len = 1, 16-byte aligned
    sub sp, sp, #16

    ; get a sum
    ; x0 = stdin
    mov x0, x19
    bl calorie_groups_max

    ; fprintf args[0] = x0
    str x0, [sp]

    ; file = stdout
    mov x0, x20
    ; fmt = "%zu\n"
    adrp x1, out_fmt_str@PAGE
    add x1, x1, out_fmt_str@PAGEOFF
    ; fprintf(stdout, "%zu\n", sum)
    bl _fprintf

    ; args.len = 1
    add sp, sp, #16

    ; return = 0
    mov x0, #0

    ; end main
    ldp x20, x19, [sp, #16]
    ldp fp, lr, [sp, #0]
    add sp, sp, #32

    ret

.data
; r_str : [2]u8
r_str:
    .ascii "r"
    .byte 0

; w_str : [2]u8
w_str:
    .ascii "w"
    .byte 0

; out_fmt_str : [5]u8
out_fmt_str:
    .ascii "%zu\n"
    .byte 0
