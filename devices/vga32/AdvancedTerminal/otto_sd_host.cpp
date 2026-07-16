#include "otto_sd_host.h"
#include "otto_config.h"
#include "otto_uart_pause.h"
#include "fabgl.h"
#include <dirent.h>
#include <stdio.h>
#include <string.h>

OttoSd OttoSdHost::s_sd;
bool OttoSdHost::s_uiSession = false;

static fabgl::SerialPort * s_serial = nullptr;

OttoSd & OttoSdHost::sd() {
  return s_sd;
}

void OttoSdHost::probeBoot(int csPin, char * buf, size_t bufLen) {
  if (!buf || bufLen < 16)
    return;
#if !OTTO_SD_ENABLED
  snprintf(buf, bufLen, "disabled (terminal-only)");
  (void)csPin;
  return;
#else
  buf[0] = '\0';
  int const miso = OttoSd::sdSharesUartTx() ? 2 : 35;
  s_sd.begin(csPin);
  if (!s_sd.tryMount()) {
    snprintf(buf, bufLen, "mount FAILED (MISO=%d)", miso);
    return;
  }
  DIR * dir = opendir(VGA_SD_ROOT);
  bool const ok = (dir != nullptr);
  if (dir)
    closedir(dir);
  if (ok)
    s_sd.markSdKnown();
  s_sd.release();
  if (ok)
    snprintf(buf, bufLen, "OK (%s, MISO=%d)", VGA_SD_ROOT, miso);
  else
    snprintf(buf, bufLen, "mounted, %s missing (MISO=%d)", VGA_SD_ROOT, miso);
#endif
}

bool OttoSdHost::beginUiSession(void (*uartRestore)()) {
#if !OTTO_SD_ENABLED
  (void)uartRestore;
  return false;
#else
  OttoSd::setUartHooks(
      []() { ottoUartPauseForSd(s_serial); },
      [uartRestore]() { ottoUartRemount(s_serial, uartRestore); });
  s_uiSession = true;
  OttoSd::setUiHold(true);
  if (!s_sd.tryMount()) {
    endUiSession(uartRestore);
    return false;
  }
  return true;
#endif
}

void OttoSdHost::endUiSession(void (*uartRestore)()) {
#if OTTO_SD_ENABLED
  OttoSd::setUiHold(false);
  s_sd.release();
  if (OttoSd::sdSharesUartTx())
    ottoUartRemount(s_serial, uartRestore);
#endif
  s_uiSession = false;
}

void ottoSdHostSetSerial(fabgl::SerialPort * serial) {
  s_serial = serial;
}
