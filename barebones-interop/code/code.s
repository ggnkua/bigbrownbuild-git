
                .globl  _palette_current
                .globl  _vbl_count
    

                .data

_screen_phys::  .dc.l SCREEN1
_screen_log::   .dc.l SCREEN2

                .even
_sample_start:: .incbin "obj/254056__jagadamba__space-sound.raw"
_sample_end::
                .even

_pic_palette::  .incbin "obj/pic.pi1",32,2
_pic_data::     .incbin "obj/pic.pi1",32000,34
_pic_data_end::

                .bss
                ds.b 256
SCREEN1:        ds.b 32000
SCREEN2:        ds.b 32000

_old_pal::      .ds.l 8
old_pal_falcon_tt:  .ds.l 256 ; enough for ST/E, TT and Falcon
_machine_type:: .ds.w 1

                .text

;-------------------------------------------------------------------------------
; Detect machine and setup video
;-------------------------------------------------------------------------------

_detect_machine::
                movem.l d0-a6,-(sp)

                move.l  #'Emu?',D5
                move.l  D5,D6
                move.l  D6,D7
                move.w  #$25,-(SP)
                trap    #14
                addq.l  #2,SP
                cmp.l   D5,D7
                bne.s   find_emu
                cmp.l   D5,D6
                beq.s   cookiejar
find_emu:       moveq   #10,D2
                lea     emulators(PC),A0
                moveq   #(end_emulators-emulators)/8-1,D0
find_emu_loop:  movem.l (A0)+,D3-D4
                cmp.l   D3,D6
                bne.s   diff_emu
                cmp.l   D4,D7
                bne.s   diff_emu
                lea     -8(A0),A1
                bra.s   found_machine
diff_emu:       addq.w  #1,D2
                dbra    D0,find_emu_loop


cookiejar:      move.l  #"_MCH",D1      ;cookie we want
                move.l  #'CT60',D2      ;for CT6x detection
                move.l  $05A0.w,D0      ;get address of cookie jar in d0
                beq.s   .nofind         ;If zero, there's no jar.
                movea.l D0,A0           ;move the address of the jar to a0
.search:        tst.l   (A0)            ;is this jar entry the last one ?
                beq.s   .nofind         ;yes, the cookie was not found
                cmp.l   (A0),D1         ;does this cookie match what we're looking for?
                beq.s   foundit         ;yes, it does.
                cmp.l   (A0),D2         ;detected CT6x?
                beq.s   ct6x            ;yep
                addq.l  #8,A0           ;advance to the next jar entry
                bra.s   .search         ;and start over

.nofind:        lea     m_stfm(PC),A1
                moveq   #0,D2
                bra.s   found_machine

ct6x:           lea     m_ct6x(PC),A1
                moveq   #7,D2
                bra.s   found_machine

foundit:        lea     machines(PC),A2
                move.l  4(A0),D0
                moveq   #(end_machines-machines)/12-1,D1
                moveq   #1,D2
findmachine:    cmp.l   (A2)+,D0
                beq.s   found_machine
                addq.w  #1,D2
                addq.l  #8,A2
                dbra    D1,findmachine
                lea     m_unknown(PC),A1 ;if we got here and didn't find any sane values then we got a problem
                moveq   #8,D2

found_machine:
                bra.s   scr_setup

m_unknown:      DC.B 'Unknown '
m_stfm:         DC.B 'STF/M   '
m_ct6x:         DC.B 'CT60/63 '
machines:
                DC.L $010000,'STE ','    '
                DC.L $010010,'Mega',' STE'
                DC.L $030000,'Falc','on  '
                DC.L $020000,'TT  ','    '
                DC.L $010008,'Unof','f/al'
                DC.L $010001,'ST B','ook '
end_machines:
emulators:      DC.L 'PaCi','fiST'
                DC.L 'Tbox','    '
                DC.L 'STEe','mEng'
end_emulators:

STFM            EQU 0
STE             EQU 1
MEGASTE         EQU 2
FALCON          EQU 3
TT              EQU 4
CRAP            EQU 5
STBOOK          EQU 6
CT6X            EQU 7
UNKNOWN         EQU 8
PACIFIST        EQU 10
TOSBOX          EQU 11
STEEM           EQU 12

scr_setup:

        clr.b _screen_phys+3    ; align to 256 byte boundary
        clr.b _screen_log+3     ; align to 256 byte boundary
        
        move.w d2,_machine_type

        cmp.w #FALCON,d2
        beq.s setup_falcon
        blt setup_st_ste
        cmp.w #CT6X,d2
        beq.s setup_falcon
        cmp.w #TT,d2
        beq   setup_tt
        
        bra setup_st_ste    ; Let's assume it's a plain ST for the rest - what could go wrong? (lol)

;  ______    _                 
; |  ____|  | |                
; | |__ __ _| | ___ ___  _ __  
; |  __/ _` | |/ __/ _ \| '_ \ 
; | | | (_| | | (_| (_) | | | |
; |_|  \__,_|_|\___\___/|_| |_|

setup_falcon:

        move.w #256-1,d7
        lea $ffff9800.w,a0
        lea old_pal_falcon_tt,a1
save_falc_pal:
        move.l (a0)+,(a1)+
        dbra d7,save_falc_pal

        movem.l $ffff8240.w,d0-d7
        movem.l d0-d7,_old_pal

; Save Falcon video
; Saves the current falcon resolution to an internal buffer.
        lea save_video,a6

        move.w #2,-(sp)         ; physbase
        trap #14
        addq.l #2,sp
        move.l d0,(a6)+
        move.w #3,-(sp)         ; logbase
        trap #14
        addq.l #2,sp
        move.l d0,(a6)+
 
        move.l  $FFFF8282.w,(A6)+ ; h-regs
        move.l  $FFFF8286.w,(A6)+ ;
        move.l  $FFFF828A.w,(A6)+ ;
        move.l  $FFFF82A2.w,(A6)+ ; v-regs
        move.l  $FFFF82A6.w,(A6)+ ;
        move.l  $FFFF82AA.w,(A6)+ ;
        move.w  $FFFF82C0.w,(A6)+ ; vco
        move.w  $FFFF82C2.w,(A6)+ ; c_s
        move.l  $FFFF820E.w,(A6)+ ; offset
        move.w  $FFFF820A.w,(A6)+ ; sync
        move.b  $FFFF8256.w,(A6)+ ; p_o
        clr.b   (A6)            ; test of st(e) or falcon mode
        cmpi.w  #$B0,$FFFF8282.w ; hht kleiner $b0?
        sle     (A6)+           ; flag setzen
        move.w  $FFFF8266.w,(A6)+ ; f_s
        move.w  $FFFF8260.w,(A6)+ ; st_s

; Setup video

        move.l _screen_phys,d0
        lsr.w #8,d0
        move.l d0,$ffff8200.w

        move.w #$59,-(sp)
        trap #14
        addq.l #2,sp

        move.w #$3,d1           ; 320x200x4bpp
        cmp.w #2,d0             ; VGA?
        bne.s do_setup
        or.w #$110,d1           ; set VGA+doubling bit
        add.l #320*28,_screen_phys; centre screen vertically for VGA
        add.l #320*28,_screen_log; centre screen vertically for VGA
        
do_setup:
        move.w d1,-(sp)
        move.w #$58,-(sp)
        trap #14
        addq.l #4,sp

        movem.l (sp)+,d0-a6
        rts



save_video:     .ds.b 40
save_video_ptrs:.ds.l 2     ; plus 2 longs for old phys/log pointers

;  _______ _______ 
; |__   __|__   __|
;    | |     | |   
;    | |     | |   
;    | |     | |   
;    |_|     |_|

setup_tt:

; Save palette

        move.w #256/2-1,d7
        lea $ffff8400.w,a0
        lea old_pal_falcon_tt,a1
save_tt_pal:
        move.l (a0)+,(a1)+
        dbra d7,save_tt_pal

; Save video

        lea save_video(pc),a6
        move.w $ffff8262.w,(a6)+
        move.w #2,-(sp)         ; physbase
        trap #14
        addq.l #2,sp
        move.l d0,(a6)+

        movem.l (sp)+,d0-a6
        rts

;   _____ _______  _______ _______ ______ 
;  / ____|__   __|/ / ____|__   __|  ____|
; | (___    | |  / / (___    | |  | |__   
;  \___ \   | | / / \___ \   | |  |  __|  
;  ____) |  | |/ /  ____) |  | |  | |____ 
; |_____/   |_/_/  |_____/   |_|  |______|

setup_st_ste:
        movem.l $ffff8240.w,d0-d7
        movem.l d0-d7,_old_pal
        lea save_video(pc),a6
        move.w #4,-(sp)         ; getrez
        trap #14
        addq.l #2,sp
        move.w d0,(a6)+
        move.w #2,-(sp)         ; physbase
        trap #14
        addq.l #2,sp
        move.l d0,(a6)+
        move.w #3,-(sp)         ; logbase
        trap #14
        addq.l #2,sp
        move.l d0,(a6)+
        
        clr.w -(sp)
        move.l _screen_phys,-(sp)
        move.l (sp),-(sp)
        move.w #5,-(sp)
        trap #14
        lea 12(sp),sp
        
        movem.l (sp)+,d0-a6
        rts

;-------------------------------------------------------------------------------
; Restore video
;-------------------------------------------------------------------------------
_restore_video::
        movem.l d0-a6,-(sp)

        move.w _machine_type,d2

        cmp.w #FALCON,d2
        beq.s restore_video_falcon
        blt   restore_video_st_ste
        cmp.w #CT6X,d2
        beq.s restore_video_falcon
        cmp.w #TT,d2
        beq   restore_video_tt
        
        bra restore_video_st_ste    ; Let's assume it's a plain ST for the rest - what could go wrong? (lol)

;  ______    _                 
; |  ____|  | |                
; | |__ __ _| | ___ ___  _ __  
; |  __/ _` | |/ __/ _ \| '_ \ 
; | | | (_| | | (_| (_) | | | |
; |_|  \__,_|_|\___\___/|_| |_|

restore_video_falcon:
        lea save_video,a6

        move.w #-1,-(sp)
        move.l (a6)+,-(sp)
        move.l (a6)+,-(sp)
        move.w #5,-(sp)
        trap #14
        lea 12(sp),sp

        clr.w   $FFFF8266.w     ; falcon-shift clear
        move.l  (A6)+,$FFFF8282.w ;0       * h-regs
        move.l  (A6)+,$FFFF8286.w ;4       *
        move.l  (A6)+,$FFFF828A.w ;8       *
        move.l  (A6)+,$FFFF82A2.w ;12      * v-regs
        move.l  (A6)+,$FFFF82A6.w ;16      *
        move.l  (A6)+,$FFFF82AA.w ;20      *
        move.w  (A6)+,$FFFF82C0.w ;24      * vco
        move.w  (A6)+,$FFFF82C2.w ;26      * c_s
        move.l  (A6)+,$FFFF820E.w ;28      * offset
        move.w  (A6)+,$FFFF820A.w ;32      * sync
        move.b  (A6)+,$FFFF8256.w ;34      * p_o
        tst.b   (A6)+             ;35      * st(e) compatible mode?
        bne.s   .st_ste           ;36
        move.w  $0468.w,D0        ; / wait for vbl
.wait468:                         ; | to avoid
        cmp.w   $0468.w,D0        ; | falcon monomode
        beq.s   .wait468          ; \ syncerrors.
        move.w  (A6),$FFFF8266.w  ;38      * falcon-shift
        bra.s   .video_restored
.st_ste:move.w  2(A6),$FFFF8260.w ;40      * st-shift
        move.w  -10(A6),$FFFF82C2.w ; c_s
        move.l  -8(A6),$FFFF820E.w ; offset
.video_restored:

; Restore palette

        move.w #256-1,d7
        lea old_pal_falcon_tt,a0
        lea $ffff9800.w,a1
restore_falc_pal:
        move.l (a0)+,(a1)+
        dbra d7,restore_falc_pal

        movem.l (sp)+,d0-a6
        rts
;  _______ _______ 
; |__   __|__   __|
;    | |     | |   
;    | |     | |   
;    | |     | |   
;    |_|     |_|

restore_video_tt:

        lea save_video,a6
        move.w (a6)+,$ffff8262.w
        move.l (a6)+,d0
        lsr.w #8,d0
        move.l d0,$ffff8200.w

; Restore palette
        move.w #256/2-1,d7
        lea old_pal_falcon_tt,a0
        lea $ffff8400.w,a1
restore_tt_pal:
        move.l (a0)+,(a1)+
        dbra d7,restore_tt_pal

        movem.l (sp)+,d0-a6

        rts

;   _____ _______  _______ _______ ______ 
;  / ____|__   __|/ / ____|__   __|  ____|
; | (___    | |  / / (___    | |  | |__   
;  \___ \   | | / / \___ \   | |  |  __|  
;  ____) |  | |/ /  ____) |  | |  | |____ 
; |_____/   |_/_/  |_____/   |_|  |______|

restore_video_st_ste:

        lea save_video(pc),a6
        move.w (a6)+,-(sp)
        move.l (a6)+,-(sp)
        move.l (a6)+,-(sp)
        move.w #5,-(sp)
        trap #14
        lea 12(sp),sp
        
        movem.l (sp)+,d0-a6
        rts

;-------------------------------------------------------------------------------
; Fades (modifies) a1 into a0 (one notch per call)
; Why can't I find a cross fade routine on my personal source archive
; in the year 2020 and have to write one now? I'm so fired
;-------------------------------------------------------------------------------

_cross_fade::   .cargs #12*4,.current_palette.l,.target_palette.l
                movem.l D0-A2,-(SP)
                move.l  .current_palette(sp),a1
                move.l  .target_palette(sp),a0
                move.w  #15,D7

fadein2:        move.w  (A0)+,D0
                move.w  D0,D1
                move.w  D1,D2
                lsr.w   #8,D0
                lsr.w   #4,D1
                and.w   #15,D0
                and.w   #15,D1
                and.w   #15,D2
                move.w  (A1),D3
                move.b  D3,D4
                move.b  D4,D5
                lsr.w   #8,D3
                lsr.w   #4,D4
                and.w   #15,D3
                and.w   #15,D4
                and.w   #15,D5

                move.b  _ste_to_index(PC,D0.w),D0
                move.b  _ste_to_index(PC,D3.w),D3
                cmp.b   D3,D0
                beq.s   green
                blt.s   red_dec
                addq.b  #1,D3
                bra.s   green
red_dec:        subq.b  #1,D3

green:          move.b  _ste_to_index(PC,D1.w),D1
                move.b  _ste_to_index(PC,D4.w),D4
                cmp.b   D4,D1
                beq.s   blue
                blt.s   green_dec
                addq.b  #1,D4
                bra.s   blue
green_dec:      subq.b  #1,D4

blue:           move.b  _ste_to_index(PC,D2.w),D2
                move.b  _ste_to_index(PC,D5.w),D5
                cmp.b   D5,D2
                beq.s   combine
                blt.s   blue_dec
                addq.b  #1,D5
                bra.s   combine
blue_dec:       subq.b  #1,D5

combine:        move.b  _index_to_ste(PC,D3.w),D3
                move.b  _index_to_ste(PC,D4.w),D4
                move.b  _index_to_ste(PC,D5.w),D5
                lsl.w   #8,D3
                lsl.b   #4,D4
                add.b   D4,D3
                add.b   D5,D3
                move.w  D3,(A1)+

                dbra    D7,fadein2

                movem.l (SP)+,D0-A2
                rts

_index_to_ste::   DC.B 0,8,1,9,2,10,3,11,4,12,5,13,6,14,7,15
_ste_to_index::   DC.B 0,2,4,6,8,10,12,14,1,3,5,7,9,11,13,15

;-------------------------------------------------------------------------------
; Vertical blank routine
;-------------------------------------------------------------------------------
_vbl::           movem.l d0-a6,-(sp)
                
                movem.l _palette_current,d0-d7
                movem.l d0-d7,$ffff8240.w

                addq.w #1,_vbl_count

                movem.l (sp)+,d0-a6

                rte


