/*
 * Pause FabGL UART2 on GPIO 2 before SD SPI (PICO-D4 shared pin).
 * Used only when OTTO_SD_ENABLED — terminal-only builds omit this.
 */
#pragma once

namespace fabgl {
class SerialPort;
}

void ottoUartPauseForSd(fabgl::SerialPort * serial);
void ottoUartRemount(fabgl::SerialPort * serial, void (*restoreUart)());
