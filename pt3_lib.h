#ifndef PT3_LIB_H
#define PT3_LIB_H

// External functions - PT3 music player
extern void pt3_init_irq();
extern void pt3_init(unsigned char *, unsigned char);
extern void pt3_mute();
extern void pt3_unmute();

/*
gr_resetTimer(timer)
    Reset timer to zero
    timer - pointer to unsigned int variable to hold timer value
    Requires PT3 player to be initialized for IRQ timer to work
*/
extern void gr_resetTimer(unsigned int *);

/*
gr_elapsed(timer)
    Get elapsed time in 1/50 second ticks since timer was reset
    timer - pointer to unsigned int variable holding timer value
    Returns number of ticks elapsed since last reset
    Requires PT3 player to be initialized for IRQ timer to work
*/
extern unsigned gr_elapsed(unsigned int);


#endif // PT3_LIB_H