/*
 * Otto AdvancedTerminal build options (Project Otto).
 *
 * OTTO_SD_ENABLED = 0  Terminal-only (default): no microSD probe or F11 browser.
 * OTTO_SD_ENABLED = 1  Experimental local SD (F11); UART pauses on GPIO 2 during SD on PICO-D4.
 *
 * OTTO_UART_ON_HEADER = 1  FabGL Terminal TX=2 RX=34 (Otto on 2x4 header).
 * OTTO_UART_ON_HEADER = 0  PS/2 mouse TX=27 RX=26 (GPIO 2 free for SD experiments).
 */
#pragma once

#define OTTO_SD_ENABLED 0

#define OTTO_UART_ON_HEADER 1

#if OTTO_UART_ON_HEADER
#define OTTO_UART_PORT_DEFAULT 0   // FabGL Terminal: TX=2 RX=34
#else
#define OTTO_UART_PORT_DEFAULT 2   // PS/2 mouse: TX=27 RX=26
#endif

#define VGA_SD_CS 13
