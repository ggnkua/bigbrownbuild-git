#include <mint/sysbind.h>
#include <stdio.h>
#include <string.h>

extern void *sample_start;
extern void *sample_end;
extern unsigned int *screen_phys, *screen_log;
extern void cross_fade(unsigned short *current, unsigned short *target);


unsigned int old_sp;
unsigned int old_vbl;
unsigned char old_484;

#define DMA_MONO (1<<7)
#define DMA_STEREO (0<<7)
#define DMA_FREQ_6258 0
#define DMA_FREQ_12517 1
#define DMA_FREQ_25033 2
#define DMA_FREQ_50066 3
#define DMA_LOOP 2
#define DMA_REPLAY_ON 1

enum
{
    STFM          = 0,
    STE           = 1,
    MEGASTE       = 2,
    FALCON        = 3,
    TT            = 4,
    CRAP          = 5,
    STBOOK        = 6,
    CT6X          = 7,
    UNKNOWN       = 8,
    PACIFIST      = 10,
    TOSBOX        = 11,
    STEEM         = 12,
};

extern unsigned short machine_type;

void play_sample(void *start_address, void *end_address)
{
    *(volatile unsigned char *)0xFF8901 = 0;
    if (machine_type == STFM)
    {
        // Poor ST/STF/STFMs get no love here
        return;
    }
    *(volatile unsigned char *)0xFF8903 = (((unsigned int)start_address>> 16)&0xff);
    *(volatile unsigned char *)0xFF8905 = (((unsigned int)start_address>> 8)&0xff);
    *(volatile unsigned char *)0xFF8907 = (((unsigned int)start_address>> 0)&0xff);
    *(volatile unsigned char *)0xFF890f = (((unsigned int)end_address>> 16)&0xff);
    *(volatile unsigned char *)0xFF8911 = (((unsigned int)end_address>> 8)&0xff);
    *(volatile unsigned char *)0xFF8913 = (((unsigned int)end_address>> 0)&0xff);
    *(volatile unsigned char *)0xFF8921 = DMA_MONO|DMA_FREQ_25033;
    *(volatile unsigned char *)0xFF8901 = DMA_REPLAY_ON;
}

extern void vbl();
unsigned short palette_current[16];
extern unsigned short old_pal[16];
extern void detect_machine();
volatile unsigned short vbl_count = 0;
unsigned short palette_black[16] = { 0 };
extern unsigned short pic_palette[16];
extern unsigned char *pic_data[32000];
extern void restore_video();

void wait_for_vblank(void)
{
    volatile unsigned short temp_vbl = vbl_count;
    while (vbl_count == temp_vbl)
    {
    }
}

void swap_screens()
{
    if (machine_type != FALCON && machine_type != CT6X)
    {        
        *(int *)0xffff8200 = ((unsigned int)screen_log&0xffff0000) | (((unsigned int)screen_log&0xff00)>> 8);
        unsigned int *temp = screen_log;
        screen_log = screen_phys;
        screen_phys = temp;
        wait_for_vblank();
    }
    else
    {
        unsigned int *temp = screen_log;
        screen_log = screen_phys;
        screen_phys = temp;
        wait_for_vblank();
        *(int *)0xffff8200 = ((unsigned int)temp&0xffff0000) | (((unsigned int)temp&0xff00)>> 8);
    }
}

void fade(unsigned short *current, unsigned short *palette_to_fade_to)
{
    unsigned short i;
    for (i=0;i<16;i++)
    {
        wait_for_vblank();
        cross_fade(current, palette_to_fade_to);
    }
}

int main()
{
    old_sp = Super(0);

    detect_machine();

    old_vbl = *(unsigned int *)0x70;
    *(int *)0x70 = (int)vbl;
    old_484 = *(unsigned char *)0x484;
    *(char *)0x484 = 0; // Shut up, keyclick
    // Gee, thanks gcc 11: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=99578
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wstringop-overread"
    memcpy(palette_current, (unsigned short *)0xffff8240, 32);
    memcpy(old_pal, (unsigned short *)0xffff8240, 32);
#pragma GCC diagnostic pop

    fade(palette_current, palette_black);
    memcpy(screen_phys,&pic_data,32000);
    memcpy(screen_log,&pic_data,32000);
    play_sample(&sample_start, &sample_end);
    fade(palette_current, pic_palette);

    volatile unsigned char key=0;
    while (key!=57)
    {
        swap_screens();
        key=*(volatile unsigned char *)0xfffffc02;
    }
    
    fade(palette_current, palette_black);

    *(int *)0x70 = old_vbl;
    restore_video();

    unsigned short i;
    for (i=0;i<16;i++)
    {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wstringop-overflow"
    memcpy((unsigned short *)0xffff8240, palette_current, 32);
#pragma GCC diagnostic pop
        Vsync();
        cross_fade(palette_current, old_pal);
    }

    *(unsigned char *)0x484 = old_484;
    Super(old_sp);
    Pterm(0);
    
}
