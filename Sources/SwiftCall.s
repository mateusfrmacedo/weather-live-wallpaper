.text
.globl _call_swift_cloud_kind
.p2align 2
_call_swift_cloud_kind:
 stp x29, x30, [sp, #-16]!
 mov x29, sp
 mov x8, x1
 blr x0
 ldp x29, x30, [sp], #16
 ret
.globl _call_swift_init
.p2align 2
_call_swift_init:
 stp x29, x30, [sp, #-32]!
 str x20, [sp, #16]
 mov x29, sp
 mov x20, x1
 blr x0
 ldr x20, [sp, #16]
 ldp x29, x30, [sp], #32
 ret
.globl _call_swift_init_argument
.p2align 2
_call_swift_init_argument:
 stp x29, x30, [sp, #-32]!
 str x20, [sp, #16]
 mov x29, sp
 mov x9, x0
 mov x20, x1
 mov x0, x2
 blr x9
 ldr x20, [sp, #16]
 ldp x29, x30, [sp], #32
 ret
.globl _call_swift_method
.p2align 2
_call_swift_method:
 stp x29, x30, [sp, #-32]!
 str x20, [sp, #16]
 mov x29, sp
 mov x9, x0
 mov x20, x1
 mov x8, x3
 mov x10, x2
 ldp x0, x1, [x10]
 ldp x2, x3, [x10, #16]
 ldp x4, x5, [x10, #32]
 blr x9
 ldr x20, [sp, #16]
 ldp x29, x30, [sp], #32
 ret
.globl _call_swift_moon
.p2align 2
_call_swift_moon:
 stp x29, x30, [sp, #-32]!
 str x20, [sp, #16]
 mov x29, sp
 mov x9, x0
 mov x20, x1
 mov x0, x2
 mov x1, x3
 mov x8, x4
 blr x9
 ldr x20, [sp, #16]
 ldp x29, x30, [sp], #32
 ret
