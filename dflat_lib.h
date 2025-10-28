#ifndef DFLAT_LIB_H
#define DFLAT_LIB_H

// External functions - graphics and keyboard

/*
gr_init()
    Initialize graphics system - call before any other graphics library functions
    Initialises various tables required for the graphics routines
*/
extern void gr_init();

/*
gr_spr_init()
    Initialize sprite system - call before using sprites
    Any previous sprites are forgotten and left on the screen as artefacts
*/
extern void gr_spr_init();

/*
gr_spr_upd()
    Update sprite positions on screen
    After udpateing sprite position or character data, call this to reflect changes on screen
*/
extern void gr_spr_upd();

/*
gr_spr_pos(spr, x, y)
    Set sprite #spr to position (x,y)
    spr - sprite number (0-31)
    x - x coordinate (0-39)
    y - y coordinate (0-27)
*/
extern void gr_spr_pos(unsigned char, unsigned char, unsigned char);

/*
gr_spr_char(spr, p)
    Set sprite #spr to character p
    spr - sprite number (0-31)
    p - character code (0-255)
*/
extern void gr_spr_char(unsigned char, unsigned char);


/*
gr_tplot(x, y, str)
    Plot string str at position (x,y)
    x - x coordinate (0-39)
    y - y coordinate (0-27)
    str - pointer to null-terminated string or a character code
    if str is less than 256, it is treated as a character code
*/
extern void gr_tplot(int, int, char *);

/*
kb_stick()
    Get joystick/keyboard state
    Returns bitmask of current joystick/keyboard state
    Bit 0 - left
    Bit 1 - right
    Bit 2 - down
    Bit 3 - up
    Bit 4 - fire button / space key
*/
extern unsigned char kb_stick();

#endif
