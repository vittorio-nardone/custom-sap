/*
 * VGA32 microSD helpers (F11 browser / boot probe). No Otto protocol — local FabGL use only.
 */
#pragma once

#include "otto_sd.h"
#include <stddef.h>

namespace fabgl {
class SerialPort;
}

class OttoSdHost {
public:
  static OttoSd & sd();

  /** Boot probe before UART claims GPIO 2 — call only when OTTO_SD_ENABLED. */
  static void probeBoot(int csPin, char * buf, size_t bufLen);

  /** Mount for F11 browser; pauses UART on GPIO 2 when needed. */
  static bool beginUiSession(void (*uartRestore)());
  static void endUiSession(void (*uartRestore)());

private:
  static OttoSd s_sd;
  static bool   s_uiSession;
};

void ottoSdHostSetSerial(fabgl::SerialPort * serial);
