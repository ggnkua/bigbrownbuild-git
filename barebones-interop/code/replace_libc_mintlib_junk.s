;; "Liberated" from gcc sources (libgcc/config/m68k/lb1sf68k.s)
;
;__udivsi3:
;___udivsi3::
;        move.l  d2, -(sp)
;        move.l  12(sp), d1      ; d1 = divisor 
;        move.l  8(sp), d0       ; d0 = dividend 
;
;        cmp.l   #$10000, d1     ; divisor >= 2 ^ 16 ?   
;        bcc     L3              ; then try next algorithm 
;        move.l  d0, d2
;        clr.w   d2
;        swap    d2
;        divu    d1, d2          ; high quotient in lower word 
;        move.w  d2, d0          ; save high quotient 
;        swap    d0
;        move.w  10(sp), d2      ; get low dividend + high rest 
;        divu    d1, d2          ; low quotient 
;        move.w  d2, d0
;        bra     L6
;
;L3:     move.l  d1, d2          ; use d2 as divisor backup 
;L4:     lsr.l   #1, d1          ; shift divisor 
;        lsr.l   #1, d0          ; shift dividend 
;        cmp.l   #$10000, d1     ; still divisor >= 2 ^ 16 ?  
;        bcc     L4
;        divu    d1, d0          ; now we have 16-bit divisor 
;        and.l   #$ffff, d0      ; mask out divisor, ignore remainder 
;
;; Multiply the 16-bit tentative quotient with the 32-bit divisor.  Because of
;; the operand ranges, this might give a 33-bit product.  If this product is
;; greater than the dividend, the tentative quotient was too large.
;        move.l  d2, d1
;        mulu    d0, d1          ; low part, 32 bits 
;        swap    d2
;        mulu    d0, d2          ; high part, at most 17 bits 
;        swap    d2              ; align high part with low part 
;        tst.w   d2              ; high part 17 bits? 
;        bne     L5              ; if 17 bits, quotient was too large 
;        add.l   d2, d1          ; add parts 
;        bcs     L5              ; if sum is 33 bits, quotient was too large 
;        cmp.l   8(sp), d1       ; compare the sum with the dividend 
;        bls     L6              ; if sum > dividend, quotient was too large 
;L5:     subq.l  #1, d0          ; adjust quotient 
;
;L6:     move.l  (sp)+, d2
;        rts

;// -----------------------------------------------------------------------------
;; "Liberated" from gcc sources (libgcc/config/m68k/lb1sf68.S)
;___umodsi3::
;__umodsi3:
;	move.l	8(sp), d1	; d1 = divisor 
;	move.l	4(sp), d0	; d0 = dividend 
;	move.l	d1, -(sp)
;	move.l	d0, -(sp)
;	bsr __udivsi3
;	addq.l	#8, sp
;	move.l	8(sp), d1	; d1 = divisor 
;	move.l	d1, -(sp)
;	move.l	d0, -(sp)
;	bsr __mulsi3	; d0 = (a/b)*b 
;	addq.l	#8, sp
;	move.l	4(sp), d1	; d1 = dividend 
;	sub.l	d0, d1		; d1 = a - (a/b)*b 
;	move.l	d1, d0
;	rts

// -----------------------------------------------------------------------------
;; "Liberated" from gcc sources (libgcc/config/m68k/lb1sf68.S)
;___mulsi3::
;__mulsi3:
;	move.w	4(sp), d0	; x0 -> d0
;	mulu	10(sp), d0	; x0*y1 
;	move.w	6(sp), d1	; x1 -> d1 
;	mulu	8(sp), d1	; x1*y0 
;	add.l	d1, d0
;	swap	d0
;	clr.w	d0
;	move.w	6(sp), d1	; x1 -> d1 
;	mulu	10(sp), d1	; x1*y1 
;	add.l	d1, d0
;
;	rts

;// -----------------------------------------------------------------------------
;; POSIX open() flags like O_RDONLY etc seem to map 1:1 to the GEMDOS call, at least the simple stuff.
;; So we pass the flags as-is and brace for impact
;_open:: .cargs #4,.fname.l,.open_flags.l
;        move.w  .open_flags+2(sp),-(sp)
;        move.l  2+.fname(sp),-(sp)
;        move.w  #$3d,-(sp)
;        trap    #1
;        addq.l  #8,sp
;        rts

;// -----------------------------------------------------------------------------
;_read:: .cargs #4,.handle.l,.buf.l,.length.l
;        move.l  .buf(sp),-(sp)
;        move.l  4+.length(sp),-(sp)
;        move.w  8+.handle+2(sp),-(sp)
;        move.w  #$3F,-(sp)
;        trap   #1
;        lea   12(sp),sp
;        rts

;// -----------------------------------------------------------------------------
;_write::    .cargs #4,.handle.l,.buf.l,.count.l
;        move.l  .buf(sp),-(sp)
;        move.l  4+.count(sp),-(sp)
;        move.w  8+.handle+2(sp),-(sp)
;        move.w  #$40,-(sp)
;        trap    #1
;        lea     12(sp),sp
;        rts

;// -----------------------------------------------------------------------------
;_close::    .cargs #4,.handle.l
;        move.w  .handle+2(sp),-(sp)
;        move.w  #$3E,-(sp)
;        trap    #1
;        addq.l  #4,sp
;        rts

;// -----------------------------------------------------------------------------
;_lseek::    .cargs #4,.handle.l,.offset.l,.mode.l
;        move.w  .mode+2(sp),-(sp)
;        move.w  2+.handle+2(sp),-(sp)
;        move.l  4+.offset(sp),-(sp)
;        move.w  #$42,-(sp)
;        trap    #1
;        lea     10(sp),sp
;        rts

;// -----------------------------------------------------------------------------
;_creat:: .cargs #4,.fname.l,.attr.l
;        move.w  .attr+2(sp),-(sp)
;        move.l  2+.fname(sp),-(sp)
;        move.w  #$3C,-(sp)
;        trap    #1
;        addq.l  #8,sp
;        rts

// -----------------------------------------------------------------------------
_memcpy::
; From mintlib (string/bcopy.s)

;   new version of bcopy, memcpy and memmove
;   handles overlap, odd/even alignment
;   uses movem to copy 256 bytes blocks faster.
;   Alexander Lehmann   alexlehm@iti.informatik.th-darmstadt.de
;   sortof inspired by jrbs bcopy

;   void *memcpy( void *dest, const void *src, size_t len );
;   void *memmove( void *dest, const void *src, size_t len );
;   returns dest
;   functions are aliased

    move.l  4(sp),a1   ; dest
    move.l  8(sp),a0   ; src
    bra common      ; the rest is samea as bcopy

;   void bcopy( const void *src, void *dest, size_t length );
;   void _bcopy( const void *src, void *dest, unsigned long length );
;   return value not used (returns src)
;   functions are aliased (except for HSC -- sb)

_bcopy:
___bcopy:
__bcopy:
    move.l  4(sp),a0   ; src
    move.l  8(sp),a1   ; dest
common: move.l  12(sp),d0  ; length
common2:
    beq exit        ; length==0? (size_t)

                ; a0 src, a1 dest, d0.l length
    move.l   d2,-(sp)

    ; overlay ?
    cmp.l   a0,a1
    bgt top_down

    move.w  a0,d1       ; test for alignment
    move.w  a1,d2
    eor.w   d2,d1
    btst    #0,d1       ; one odd one even ?
    bne slow_copy
    btst    #0,d2       ; both even ?
    beq both_even
    move.b  (a0)+,(a1)+ ; copy one byte, now we are both even
    subq.l  #1,d0
both_even:
    moveq   #0,d1       ; save length less 256
    move.b  d0,d1
    lsr.l   #8,d0       ; number of 256 bytes blocks
    beq less256
    movem.l d1/d3-d7/a2/a3/a5/a6,-(sp)   ; d2 is already saved
                    ; exclude a4 because of -mbaserel
copy256:
    movem.l (a0)+,d1-d7/a2/a3/a5/a6 ; copy 5*44+36=256 bytes
    movem.l d1-d7/a2/a3/a5/a6,(a1)
    movem.l (a0)+,d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,44(a1)
    movem.l (a0)+,d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,88(a1)
    movem.l (a0)+,d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,132(a1)
    movem.l (a0)+,d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,176(a1)
    movem.l (a0)+,d1-d7/a2-a3
    movem.l d1-d7/a2-a3,220(a1)
    lea 256(a1),a1     ; increment dest, src is already
    subq.l  #1,d0
    bne copy256         ; next, please
    movem.l (sp)+,d1/d3-d7/a2/a3/a5/a6
less256:            ; copy 16 bytes blocks
    move.w  d1,d0
    lsr.w   #2,d0       ; number of 4 bytes blocks
    beq less4       ; less that 4 bytes left
    move.w  d0,d2
    neg.w   d2
    andi.w  #3,d2       ; d2 = number of bytes below 16 (-n)&3
    subq.w   #1,d0
    lsr.w   #2,d0       ; number of 16 bytes blocks minus 1, if d2==0
    add.w   d2,d2       ; offset in code (move.l two bytes)
    jmp 2(pc,d2.w) ; jmp into loop
copy16:
    move.l  (a0)+,(a1)+
    move.l  (a0)+,(a1)+
    move.l  (a0)+,(a1)+
    move.l  (a0)+,(a1)+
    dbra    d0,copy16
less4:
    btst    #1,d1
    beq less2
    move.w  (a0)+,(a1)+
less2:
    btst    #0,d1
    beq none
    move.b  (a0),(a1)
none:
exit_d2:
    move.l  (sp)+,d2
exit:
    move.l 4(sp),d0        ; return dest (for memcpy only)
    rts

slow_copy:          ; byte by bytes copy
    move.w  d0,d1
    neg.w   d1
    andi.w  #7,d1       ; d1 = number of bytes blow 8 (-n)&7
    addq.l   #7,d0
    lsr.l   #3,d0       ; number of 8 bytes block plus 1, if d1!=0
    add.w   d1,d1       ; offset in code (move.b two bytes)
    jmp 2(pc,d1.w) ; jump into loop
scopy:
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    move.b  (a0)+,(a1)+
    subq.l  #1,d0
    bne scopy
    bra exit_d2

top_down:
    add.l    d0,a0       ; a0 byte after end of src
    add.l    d0,a1       ; a1 byte after end of dest

    move.w  a0,d1       ; exact the same as above, only with predec
    move.w  a1,d2
    eor.w   d2,d1
    btst    #0,d1
    bne slow_copy_d

    btst    #0,d2
    beq both_even_d
    move.b  -(a0),-(a1)
    subq.l  #1,d0
both_even_d:
    moveq   #0,d1
    move.b  d0,d1
    lsr.l   #8,d0
    beq less256_d
    movem.l d1/d3-d7/a2/a3/a5/a6,-(sp)
copy256_d:
    movem.l -44(a0),d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,-(a1)
    movem.l -88(a0),d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,-(a1)
    movem.l -132(a0),d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,-(a1)
    movem.l -176(a0),d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,-(a1)
    movem.l -220(a0),d1-d7/a2/a3/a5/a6
    movem.l d1-d7/a2/a3/a5/a6,-(a1)
    movem.l -256(a0),d1-d7/a2-a3
    movem.l d1-d7/a2-a3,-(a1)
    lea -256(a0),a0
    subq.l  #1,d0
    bne copy256_d
    movem.l (sp)+,d1/d3-d7/a2/a3/a5/a6
less256_d:
    move.w  d1,d0
    lsr.w   #2,d0
    beq less4_d
    move.w  d0,d2
    neg.w   d2
    andi.w  #3,d2
    subq.w   #1,d0
    lsr.w   #2,d0
    add.w   d2,d2
    jmp 2(pc,d2.w)
copy16_d:
    move.l  -(a0),-(a1)
    move.l  -(a0),-(a1)
    move.l  -(a0),-(a1)
    move.l  -(a0),-(a1)
    dbra    d0,copy16_d
less4_d:
    btst    #1,d1
    beq less2_d
    move.w  -(a0),-(a1)
less2_d:
    btst    #0,d1
    beq exit_d2
    move.b  -(a0),-(a1)
    bra exit_d2
slow_copy_d:
    move.w  d0,d1
    neg.w   d1
    andi.w  #7,d1
    addq.l   #7,d0
    lsr.l   #3,d0
    add.w   d1,d1
    jmp 2(pc,d1.w)
scopy_d:
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    move.b  -(a0),-(a1)
    subq.l  #1,d0
    bne scopy_d
    bra exit_d2

// -----------------------------------------------------------------------------
_memset::
; From mintlib (string/bzero.s)

;   new version of bcopy and memset
;   uses movem to set 256 bytes blocks faster.
;   Alexander Lehmann   alexlehm@iti.informatik.th-darmstadt.de
;   sortof inspired by jrbs bcopy
;   has to be preprocessed (int parameter in memset)


;   void *memset( void *dest, int val, size_t len );
;   returns dest
;   two versions for 16/32 bits

    move.l  4(sp),a0   ; dest
.if 0                ;__MSHORT__
    move.b  9(sp),d0   ; value
    move.l  10(sp),d1  ; length
.else
    move.b  11(sp),d0  ; value
    move.l  12(sp),d1  ; length
.endif
    beq memset_exit             ; length==0? (size_t)

;   void bzero( void *dest, size_t length );
;   void _bzero( void *dest, unsigned long length );
;   return value not used (returns dest)

___bzero:
_bzero:

do_set:             ; a0 dest, d0.b byte, d1.l length
    move.l   d2,-(sp)

    add.l    d1,a0       ; a0 points to end of area, needed for predec

    move.w  a0,d2       ; test for alignment
    btst    #0,d2       ; odd ?
    beq areeven
    move.b  d0,-(a0)    ; set one byte, now we are even
    subq.l  #1,d1
areeven:
    move.b  d0,d2
    lsl.w   #8,d0
    move.b  d2,d0
    move.w  d0,d2
    swap    d2
    move.w  d0,d2       ; d2 has byte now four times

    moveq   #0,d0       ; save length less 256
    move.b  d1,d0
    lsr.l   #8,d1       ; number of 256 bytes blocks
    beq memset_less256
    movem.l d0/d3-d7/a2/a3/a5/a6,-(sp)   ; d2 is already saved
                ; exclude a4 because of -mbaserel
    move.l  d2,d0
    move.l  d2,d3
    move.l  d2,d4
    move.l  d2,d5
    move.l  d2,d6
    move.l  d2,d7
    move.l  d2,a2
    move.l  d2,a3
    move.l  d2,a5
    move.l  d2,a6
set256:
    movem.l d0/d2-d7/a2/a3/a5/a6,-(a0)  ; set 5*44+36=256 bytes
    movem.l d0/d2-d7/a2/a3/a5/a6,-(a0)
    movem.l d0/d2-d7/a2/a3/a5/a6,-(a0)
    movem.l d0/d2-d7/a2/a3/a5/a6,-(a0)
    movem.l d0/d2-d7/a2/a3/a5/a6,-(a0)
    movem.l d0/d2-d7/a2-a3,-(a0)
    subq.l  #1,d1
    bne set256          ; next, please
    movem.l (sp)+,d0/d3-d7/a2/a3/a5/a6
memset_less256:            ; set 16 bytes blocks
    move.w  d0,-(sp)     ; save length below 256 for last 3 bytes
    lsr.w   #2,d0       ; number of 4 bytes blocks
    beq memset_less4       ; less that 4 bytes left
    move.w  d0,d1
    neg.w   d1
    andi.w  #3,d1       ; d1 = number of bytes below 16 (-n)&3
    subq.w   #1,d0
    lsr.w   #2,d0       ; number of 16 bytes blocks minus 1, if d1==0
    add.w   d1,d1       ; offset in code (move.l two bytes)
    jmp 2(pc,d1.w) ; jmp into loop
set16:
    move.l  d2,-(a0)
    move.l  d2,-(a0)
    move.l  d2,-(a0)
    move.l  d2,-(a0)
    dbra    d0,set16
memset_less4:
    move.w  (sp)+,d0
    btst    #1,d0
    beq .less2
    move.w  d2,-(a0)
.less2:
    btst    #0,d0
    beq .none
    move.b  d2,-(a0)
.none:
    move.l  (sp)+,d2
memset_exit:
    move.l 4(sp),d0        ; return dest (for memset only)
    rts
