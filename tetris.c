#include "lib.h"
#include "tetris.h"
#include "pt3.h"
#include "dflat_lib.h"

char gameMap[MAP_SIZE_Y][MAP_SIZE_X];
char blankLine[MAP_SIZE_X], fillLine[MAP_SIZE_X];
unsigned lineCount[MAP_SIZE_Y];
char nextBlank[5], statBlank[8], topBlank[11];
int topScore[8], score;
char topName[8][4];
char msgTmp[MSG_WINDOW + 1];
unsigned char lines, level, musicFlag, msgIdx;
unsigned char sprX, sprY, ss, ns, sr;
unsigned int msgTimer, msgMaxLen;
unsigned int moveSpeed, dropSpeed;

void encode(char *dest, const char *src)
{
    while (*src) {
        if (*src == ' ')
            *dest = BLANK;
        else if (*src == '*')
            *dest = SOLID;
        src++;
        dest++;
    }
    *dest = *src;
}

void init()
{
    int i;
    unsigned char *p;
    unsigned char *data = (unsigned char *)tetris_udg;

    /* Load UDGs */
    while (*data) {
        p = (unsigned char *)(0xb400 + (*data * 8));
        memcpy(p, data + 1, 8);
        data += 9;
    }

    encode(blankLine, "*          *");
    encode(fillLine, "************");
    encode(nextBlank, "    ");
    encode(statBlank, "       ");

    for (i = 0; i < 7; i++) {
        topScore[i] = (8 - i) * 100;
        strcpy(topName[i], "ORI");
    }

    msgMaxLen = strlen(message) - MSG_WINDOW;
}

void setAttr(unsigned char flash, unsigned char colour, unsigned char start, unsigned char end)
{
    int i;
    for (i = start; i <= end; i++) {
        gr_tplot(TOP_X - 2, i, (char *)flash);
        gr_tplot(TOP_X - 1, i, (char *)colour);
    }
}


/* Set shape to character p */
void setShape(char p)
{
    int i;
    for (i = 0; i < 4; i++) {
        gr_spr_char(i, p);
    }
}

/* Plot shape s at x,y with rotation r */
void plotShape(char x, char y, char s, char r)
{
    int i;
    for (i = 0; i < 4; i++) {
        gr_spr_pos(i, x + shapes[s].coord[r][i].x, y + shapes[s].coord[r][i].y);
    }
    gr_spr_upd();
}

/* Check if shape s at x,y with rotation r fits (1) or not (0) */
char checkShape(char x, char y, char s, char r)
{
    int i;
    for (i = 0; i < 4; i++) {
        if (gameMap[y - MAPOFF_Y + shapes[s].coord[r][i].y][x - MAPOFF_X + shapes[s].coord[r][i].x] != BLANK)
            return 0;
    }
    return 1;
}

/* Stamp shape s at x,y with rotation r in gameMap */
void stampShape(char x, char y, char s, char r)
{
    int i;
    for (i = 0; i < 4; i++) {
        gameMap[y - MAPOFF_Y + shapes[s].coord[r][i].y][x - MAPOFF_X + shapes[s].coord[r][i].x] = shapes[s].colour;
        lineCount[y - MAPOFF_Y + shapes[s].coord[r][i].y]++;
    }
}

/* Show next shape */
void showNext(char s)
{
    gr_tplot(NEXT_X, NEXT_Y, nextBlank);
    gr_tplot(NEXT_X, NEXT_Y + 1, nextBlank);
    setShape(shapes[s].colour);
    plotShape(NEXT_X, NEXT_Y, s, 0);
    gr_spr_init();
}

/* Draw game area */
void drawGamePanel()
{
    int q;
    for (q = 1; q < MAP_SIZE_Y - 1; q++) {
        gr_tplot(GAME_X - 1, GAME_Y + q - 1, gameMap[q]);
    }
}

/* Draw border */
void drawBorder(int bx, int by, int bw, int bh)
{
    int i;

    for (i = by; i < by + bh - 1; i++) {
        gr_tplot(bx, i, (char *)BORDER_SOLID);
        gr_tplot(bx + bw - 1, i, (char *)BORDER_SOLID);
        gr_tplot(bx + 1, i, (char *)BLANK);
        gr_tplot(bx + bw, i, (char *)BLANK);
    }
    for (i = bx + 1; i < bx + bw - 1; i++) {
        gr_tplot(i, by, (char *)SOLID);
        gr_tplot(i, by + bh - 1, (char *)SOLID);
    }
    gr_tplot(bx, by, (char *)BORDER_TL);
    gr_tplot(bx + bw - 1, by, (char *)BORDER_TR);
    gr_tplot(bx, by + bh - 1, (char *)BORDER_BL);
    gr_tplot(bx + bw - 1, by + bh - 1, (char *)BORDER_BR);
}

/* Draw top scores */
void drawTopScores()
{
    int i;
    char buf[16];

    for (i = 0; i < 7; i++) {
        if (topScore[i] < 1000)
            sprintf(buf, "%s  %d ", topName[i], topScore[i]);
        else
            sprintf(buf, "%s  %d", topName[i], topScore[i]);

        buf[9] = 0;
        gr_tplot(TOP_X - 2, TOP_Y + i * 2 + 1, (char *)(i + 1));
        gr_tplot(TOP_X + 1, TOP_Y + i * 2 + 1, buf);
    }
}

/* Draw status line */
void drawStatusLine()
{
    int i;
    char buf[20];

    for (i = 0; i < 2; i++) {
        sprintf(buf, "SCORE:%d    ", score);
        buf[10] = 0;
        gr_tplot(4, i, buf);

        sprintf(buf, "LINES:%d    ", lines);
        buf[10] = 0;
        gr_tplot(17, i, buf);

        sprintf(buf, "LEVEL:%d    ", level);
        buf[11] = 0;
        gr_tplot(29, i, buf);
    }
}

/* Draw game screen */
void drawScreen()
{
    gr_tplot(2, 0, " ");
    gr_tplot(1, 0, (char *)2);
    gr_tplot(1, 1, (char *)3);
    gr_tplot(2, 0, (char *)10);
    gr_tplot(2, 1, (char *)10);
    gr_tplot(1, 27, (char *)1);

    drawStatusLine();
    drawBorder(GAME_X - 1, GAME_Y, SIZE_X + 2, SIZE_Y + 1); /* Game area */
    drawBorder(NEXT_X - 1, NEXT_Y - 1, 6, 4);               /* Next shape */
    drawBorder(STAT_X - 1, STAT_Y - 1, 9, 15);              /* Statistics */
    drawBorder(TOP_X - 1, TOP_Y - 1, 12, 16);               /* Top scores */

    gr_tplot(NEXT_X, NEXT_Y - 1, "NEXT");
    gr_tplot(STAT_X + 1, STAT_Y - 1, "STATS");
    gr_tplot(TOP_X, TOP_Y - 1, "TOP SCORES");

    drawTopScores(); /* Top scores */
}

void scrollMsg()
{
    if (gr_elapsed(msgTimer) > MSG_DELAY) {
        gr_resetTimer(&msgTimer);
        memcpy(msgTmp, &message[msgIdx++], MSG_WINDOW);
        msgTmp[MSG_WINDOW] = '\0';
        if (msgIdx >= msgMaxLen)
            msgIdx = 0;
        gr_tplot(2, 27, msgTmp);
    }
}

/* Animate shape */
void animateShape(unsigned char ss)
{
    int tx = NEXT_X, ty = NEXT_Y;

    /*    if (musicFlag) {
            sound(0,20,0); sound(2,100,0); play(2,2,4,1000);
        } */

    do {
        plotShape(tx, ty, ss, 0);

        if (tx < sprX)
            tx++;
        if (ty < sprY)
            ty++;
        if (tx > sprX)
            tx--;
        if (ty > sprY)
            ty--;

        scrollMsg();
    } while ((tx != sprX) || (ty != sprY));
}

/* New shape at top */
void newShape()
{
    sprX = 3 + GAME_X;
    sprY = GAME_Y;
    ss = ns;
    ns = rand() % NUM_SHAPES;
    sr = 0;

    showNext(ns);
    setShape(shapes[ss].colour);
    animateShape(ss);
    plotShape(sprX, sprY, ss, sr);

    shapes[ss].stat++;
    if (shapes[ss].stat <= 13)
        gr_tplot(STAT_X + ss, STAT_Y + 13 - shapes[ss].stat, (char *)shapes[ss].colour);
}

/* Init game map */
void initGameMap()
{
    int q;

    strcpy(gameMap[0], fillLine);

    for (q = 1; q < MAP_SIZE_Y - 1; q++) {
        strcpy(gameMap[q], blankLine);
        lineCount[q] = 0;
    }

    gameMap[1][0] = BORDER_TL;
    gameMap[1][MAP_SIZE_X - 2] = BORDER_TR;
    strcpy(gameMap[MAP_SIZE_Y - 1], fillLine);
}

void initStats()
{
    int i;

    for (i = 0; i < 7; i++)
        shapes[i].stat = 0;

    for (i = STAT_Y; i <= (STAT_Y + 12); i++)
        gr_tplot(STAT_X, i, statBlank);
}

void killLine(int y)
{
    int x, c;

    for (; y > 0; y--) {
        memcpy(gameMap[y] + 1, gameMap[y - 1] + 1, SIZE_X);
        /* strcpy(gameMap[y],gameMap[y-1]); */
        lineCount[y] = lineCount[y - 1];

        if (y > 1)
            gr_tplot(GAME_X - 1, GAME_Y + y - 1, gameMap[y]);
    }

    memcpy(gameMap[1] + 1, blankLine + 1, SIZE_X);
    /* strcpy(gameMap[1],blankLine); */
    gr_tplot(GAME_X - 1, GAME_Y, gameMap[1]);
}

void checkLineFull()
{
    int x, y, count, bonus;

    bonus = 1;
    y = SIZE_Y;

    while (y > 0) {
        if (lineCount[y] == SIZE_X) {
            killLine(y);
            score = score + ((SIZE_Y - y + 2) * bonus);
            bonus++;
            lines++;

            if ((lines % 10) == 0) {
                level++;
                dropSpeed = (dropSpeed * 80) / 100;
            }
            drawStatusLine();
        } else {
            y--;
        }
    }
}

void checkTop()
{
    int i, j;
    char c;

    for (i = 0; i < 7; i++) {
        if (score >= topScore[i]) {
            if (musicFlag)
                pt3_init(win1pt3, 0);
            for (j = 6; j > i; j--) {
                topScore[j] = topScore[j - 1];
                strcpy(topName[j], topName[j - 1]);
            }
            topScore[i] = score;
            strcpy(topName[i], "   ");
            drawTopScores();
            setAttr(12, 3, 21, 23);
            gr_tplot(TOP_X, 21, "WELL DONE!");
            gr_tplot(TOP_X, 22, "ENTER NAME");
            while(key());
            j=0;
            do {
                gr_tplot(TOP_X+1+j, TOP_Y+i*2+1, (char *)160);
                do {
                    scrollMsg();
                    c=key();
                } while((c!=127)&&(c<32));
                if(c==127) {
                    if(j>0) {
                        gr_tplot(TOP_X+1+j, TOP_Y+i*2+1, (char *)32);
                        j--;
                    }
                } else {
                    if(c>=32) {
                        topName[i][j]=c;
                        gr_tplot(TOP_X+1+j, TOP_Y+i*2+1, (char *)c);
                        j++;
                    }
                }

            } while(j<3);
            break;
        }
    }
    while(key());
}

void initGameStart() {
    score = 0;
    level = 1;
    lines = 0;
    dropSpeed = 40;
    moveSpeed = 6;

    drawStatusLine();
    initStats();
    initGameMap();
    drawGamePanel();

    ns = rand() % NUM_SHAPES;

}

void startGame()
{
    int dead = 0;
    int stop, forceDrop, fire = 0;
    int mo, tr;
    unsigned int dropTimer = 0, moveTimer = 0;

    initGameStart();

    if (musicFlag)
        pt3_init(popcornpt3, 0);

    do {
        newShape(); /* sets sprX, sprY, ss, sr, mo, ns, etc. */
        forceDrop = 0;

        if (!checkShape(sprX, sprY, ss, sr)) {
            dead = 1;
            gr_spr_init(); /* disables sprites, leaves imprint */
        } else {
            stop = 0;
            gr_resetTimer(&dropTimer);
            gr_resetTimer(&moveTimer);

            do {
                mo = 0;
                if (gr_elapsed(moveTimer) > moveSpeed) {
                    gr_resetTimer(&moveTimer);

                    /* Move left */
                    if (kb_stick() & 1) {
                        if (checkShape(sprX - 1, sprY, ss, sr)) {
                            mo=1;
                            sprX--;
                        }
                    }
                    /* Move right */
                    if (kb_stick() & 2) {
                        if (checkShape(sprX + 1, sprY, ss, sr)) {
                            mo=1;
                            sprX++;
                        }
                    }

                    /* Force drop */
                    if (kb_stick() & 8) {
                        forceDrop = 1;
                    }
                    /* Rotate */
                    if (kb_stick() & 16) {
                        if (!fire) {
                            fire = 1;
                            tr = (sr + 1) % 4;
                            if (checkShape(sprX, sprY, ss, tr)) {
                                sr = tr;
                                mo=1;
                            }
                        }
                    } else {
                        fire = 0;
                    }
                }

                /* Drop shape */
                if (forceDrop || (gr_elapsed(dropTimer) > dropSpeed)) {
                    gr_resetTimer(&dropTimer);
                    if (checkShape(sprX, sprY + 1, ss, sr)) {
                        mo++;
                        sprY++;
                    } else {
                        stop = 1;
                    }
                }

                /* Redraw if moved or rotated */
                if (mo)
                    plotShape(sprX, sprY, ss, sr);

                scrollMsg();
            } while (!stop);

            stampShape(sprX, sprY, ss, sr);
            gr_spr_init();
            checkLineFull();
        }
    } while (!dead);

    checkTop();
}

void start()
{
    int i;

    drawScreen();
    initGameMap();
    drawGamePanel();
    musicFlag = 1;

    do {
        setAttr(8, 2, 21, 23);
        gr_tplot(TOP_X, 21, "PRESS FIRE");
        gr_tplot(TOP_X, 22, " TO START ");
        pt3_init(attractpt3, 0);

        do {
            if (kb_stick() & 1)
                musicFlag = 0;
            if (kb_stick() & 2)
                musicFlag = 1;

            if (musicFlag) {
                gr_tplot(TOP_X, 23, "MUSIC: ON ");
                pt3_unmute();
            } else {
                gr_tplot(TOP_X, 23, "MUSIC: OFF");
                pt3_mute();
            }

            scrollMsg();
        } while (!(kb_stick() & 16));

        for (i = 21; i <= 23; i++)
            gr_tplot(TOP_X, i, "          ");

        startGame();
    } while (1);
}

void main()
{
    paper(0);
    ink(7);
    text();
    cls();
    poke(0x26A, 10);        // No cursor or key clicks

    gr_init();
    init();
    gr_spr_init();
    pt3_init_irq();

    while (1)
        start();
}
