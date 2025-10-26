#ifndef TETRIS_H
#define TETRIS_H

#define MSG_WINDOW 36
#define SIZE_X 10
#define SIZE_Y 20
#define MAP_SIZE_X (SIZE_X+3)
#define MAP_SIZE_Y (SIZE_Y+2)
#define NUM_SHAPES 7
#define NUM_ROT 4
#define NEXT_X 6
#define NEXT_Y 5
#define GAME_X 14
#define GAME_Y 4
#define STAT_X 3
#define STAT_Y 11
#define TOP_X 28
#define TOP_Y 5
#define BORDER_BL 125
#define BORDER_BR (126+128)
#define BORDER_TL 123
#define BORDER_TR (124+128)
#define BORDER_SOLID 23
#define BLANK 16
#define SOLID 127
#define MSG_DELAY 10
#define MAPOFF_X (GAME_X-1)
#define MAPOFF_Y (GAME_Y-1)

typedef struct {
    char x;
    char y;
} ShapeCoords;

typedef struct {
    char  colour;
    char stat;
    ShapeCoords coord[NUM_ROT][4];
} ShapeDef;

// External data - PT3 music files
extern unsigned char attractpt3[];
extern unsigned char win1pt3[];
extern unsigned char popcornpt3[];

// External data - game assets
extern const unsigned char tetris_udg[];
extern ShapeDef shapes[];
extern const char message[];

#endif
