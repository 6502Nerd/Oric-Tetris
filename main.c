#include "lib.h"

void pt3_init_irq();
void pt3_init(unsigned char*, unsigned char);
void pt3_mute();
void pt3_unmute();

extern unsigned char PT3Counter;
extern unsigned char popcornpt3[];
extern unsigned char smariopt3[];


void main()
{
  int state=0;
  char k=0;

  poke(0x26A,10);
  printf("%x %x\n",smariopt3, popcornpt3);
  pt3_init_irq();
  pt3_init(popcornpt3,0);
//  pt3_init(smariopt3,0);
  while(1) {
    k = get();
    state ^= 1;
    if(state)
      pt3_init(smariopt3,0);
    else
      pt3_init(popcornpt3,0);
  }
}
