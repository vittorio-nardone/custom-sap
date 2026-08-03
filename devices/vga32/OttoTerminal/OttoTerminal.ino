/*
  OttoTerminal v1 - VGA text-mode console for Project Otto.

  - Footer status line; Otto body = bright white on black
  - F1: Help   F10: Apps Repository (upload)   F11: Settings
  - UI overlay exit: ESC only

  Flash: ./devices/vga32/build.sh upload
*/

#include "fabgl.h"
#include "otto_uart_raw.h"
#include "otto_settings.h"
#include "otto_wifi.h"
#include "otto_xmodem_send.h"

#include <esp_heap_caps.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <stdio.h>
#include <string.h>

static constexpr int OTTO_UART_TX  = 2;
static constexpr int OTTO_UART_RX  = 34;
static constexpr int OTTO_UART_RTS = -1;
static constexpr int OTTO_UART_CTS = -1;
static constexpr int OTTO_UART_NUM = 2;

static constexpr uint32_t OTTO_WIFI_MENU_STACK = 16384;

/**
 * Track the live glyph map pointer (FabGL CSI ?1049 does not call setTextMap on
 * VGATextController, so we snapshot/restore the main map instead of alt-screen).
 */
class OttoVgaTextController : public fabgl::VGATextController {
public:
  void setTextMap(uint32_t const * map, int rows) override
  {
    m_mapPtr = map;
    fabgl::VGATextController::setTextMap(map, rows);
  }
  uint32_t const * mapPtr() const { return m_mapPtr; }
private:
  uint32_t const * m_mapPtr = nullptr;
};

OttoVgaTextController              DisplayController;
fabgl::PS2Controller               PS2Controller;
fabgl::Terminal                    Terminal;
fabgl::SerialPort                  SerialPort;
fabgl::SerialPortTerminalConnector SerialPortTerminalConnector;

static OttoWifiCatalog s_catalog{};
static OttoWifiTargetList s_targets{};
static int             s_selectedTarget = 0;
static char            s_detectedKernel[OTTO_WIFI_KERNEL_VER_MAX] = "";
static volatile bool   s_uiBusy         = false;  // F1 help or F10 menu open
static volatile bool   s_serialToTerm   = true;   // Otto UART -> Terminal (filtered)
static volatile bool   s_muteSerialSend = false;  // block Terminal->Otto during FabGL queries

#if OTTO_USB_MIRROR
static QueueHandle_t   s_usbMirrorQueue = nullptr;

static void ottoUsbMirrorInit()
{
  if (!s_usbMirrorQueue)
    s_usbMirrorQueue = xQueueCreate(4096, sizeof(uint8_t));
  Serial.begin(OTTO_USB_MIRROR_BAUD);
  Serial.setTxBufferSize(1024);
  Serial.setRxBufferSize(512);
}

static void ottoUsbMirrorPush(uint8_t value, bool fromISR)
{
  if (!s_usbMirrorQueue)
    return;
  if (fromISR) {
    BaseType_t woken = pdFALSE;
    xQueueSendFromISR(s_usbMirrorQueue, &value, &woken);
    if (woken)
      portYIELD_FROM_ISR();
  } else {
    xQueueSend(s_usbMirrorQueue, &value, 0);
  }
}

/** Drain Otto->USB TX queue and USB Serial RX -> Otto (same gates as PS/2). */
static void ottoUsbMirrorPump()
{
  if (!s_usbMirrorQueue)
    return;
  uint8_t b = 0;
  while (xQueueReceive(s_usbMirrorQueue, &b, 0) == pdTRUE)
    Serial.write(b);

  // USB console typing -> Otto. Skip while F1/F10/F11 UI or FabGL mute.
  while (Serial.available() > 0) {
    int const ch = Serial.read();
    if (ch < 0)
      break;
    if (s_muteSerialSend || s_uiBusy)
      continue;
    uint8_t c = (uint8_t)ch;
    if (c == 0x0A)  // LF -> CR (same as simulate.py keyboard path)
      c = 0x0D;
    SerialPort.send(c);
  }
}
#endif

static int termCols() { return DisplayController.getColumns(); }
static int termRows() { return DisplayController.getRows(); }

/**
 * TerminalController replies use Terminal.send(), which would go to Otto via
 * onSend and corrupt the kernel command line (?syntax error). Mute while querying.
 */
static void ottoMuteSerialSend(bool mute)
{
  s_muteSerialSend = mute;
}

static void ottoSerialRx(void * args, uint8_t value, bool fromISR);
static bool ottoSerialRxReady(void * args, bool fromISR);

/**
 * Install Otto serial bridge: filtered RX (DECSTBM clamp) + gated TX (mute FabGL
 * TerminalController replies). Safe to call again after XMODEM — OttoUartRaw::end
 * used to call connector->connect() and wipe these; it no longer does, but we
 * reinstall defensively.
 */
static void ottoInstallSerialBridge()
{
  SerialPort.setCallbacks(nullptr, ottoSerialRxReady, ottoSerialRx);
  Terminal.onSend = [&](uint8_t c) {
    // FabGL TermDecodeVirtualKey still calls send(ASCII) even when onVirtualKeyItem
    // clears vk — block all local keyboard echo while F1/F10/F11 menus are open.
    if (!s_muteSerialSend && !s_uiBusy)
      SerialPort.send(c);
  };
}

/** Gate Otto serial into the Terminal. Never stop draining the UART FIFO —
 * Otto has no CTS; disableSerialPortRX / RxReady=false overflows HW RX and
 * drops bytes (VGA + USB mirror). */
static void ottoEnableSerialToTerm(bool enabled)
{
  s_serialToTerm = enabled;
}

static constexpr size_t kOttoTermPendCap = 4096;  // power of two
static uint8_t          s_ottoTermPend[kOttoTermPendCap];
static volatile size_t  s_ottoTermPendHead = 0;
static volatile size_t  s_ottoTermPendTail = 0;

static void ottoTermPendClear()
{
  s_ottoTermPendHead = 0;
  s_ottoTermPendTail = 0;
}

static size_t ottoTermPendCount()
{
  return (s_ottoTermPendHead - s_ottoTermPendTail) & (kOttoTermPendCap - 1);
}

static bool ottoTermPendPush(uint8_t value)
{
  size_t const h = s_ottoTermPendHead;
  size_t const n = (h + 1) & (kOttoTermPendCap - 1);
  if (n == s_ottoTermPendTail)
    return false;
  s_ottoTermPend[h] = value;
  s_ottoTermPendHead = n;
  return true;
}

static void ottoFilterVtToTerminal(uint8_t c, bool fromISR);
static void ottoSerialRingPush(uint8_t value);

static void ottoTermPendDrain(bool fromISR)
{
  while (s_ottoTermPendTail != s_ottoTermPendHead) {
    if (!s_serialToTerm)
      return;
    if (Terminal.availableForWrite(fromISR) <= 0)
      return;
    size_t const t = s_ottoTermPendTail;
    uint8_t const v = s_ottoTermPend[t];
    s_ottoTermPendTail = (t + 1) & (kOttoTermPendCap - 1);
    if (!fromISR)
      ottoSerialRingPush(v);
    ottoFilterVtToTerminal(v, fromISR);
  }
}

static void termWriteByte(uint8_t c, bool fromISR)
{
  Terminal.write(c, fromISR);
}

static void termWriteDec(int n, bool fromISR)
{
  if (n < 0)
    n = 0;
  if (n >= 100) {
    termWriteByte((uint8_t)('0' + (n / 100) % 10), fromISR);
    termWriteByte((uint8_t)('0' + (n / 10) % 10), fromISR);
    termWriteByte((uint8_t)('0' + (n % 10)), fromISR);
  } else if (n >= 10) {
    termWriteByte((uint8_t)('0' + (n / 10)), fromISR);
    termWriteByte((uint8_t)('0' + (n % 10)), fromISR);
  } else {
    termWriteByte((uint8_t)('0' + n), fromISR);
  }
}

/**
 * Rewrite DECSTBM (CSI Ps;Ps r) so the last row is never in the scroll region.
 * Otto's VT100_SCROLL_SCREEN_FULL sends CSI r (full screen); FabGL then scrolls
 * the status bar up and the next footer paint leaves a duplicate line.
 */
static void ottoFilterVtToTerminal(uint8_t c, bool fromISR)
{
  enum : uint8_t { ST_NORM = 0, ST_ESC = 1, ST_CSI = 2 };
  static uint8_t st = ST_NORM;
  static char    params[24];
  static uint8_t plen = 0;
  static bool    priv = false;  // CSI ?

  if (st == ST_NORM) {
    if (c == 0x1B) {
      st = ST_ESC;
      return;
    }
    termWriteByte(c, fromISR);
    return;
  }

  if (st == ST_ESC) {
    if (c == '[') {
      st   = ST_CSI;
      plen = 0;
      priv = false;
      return;
    }
    termWriteByte(0x1B, fromISR);
    termWriteByte(c, fromISR);
    st = ST_NORM;
    return;
  }

  // ST_CSI
  if (plen == 0 && c == '?') {
    priv = true;
    return;
  }

  // Parameter / intermediate bytes
  if (c >= 0x20 && c <= 0x3F) {
    if (plen < sizeof(params))
      params[plen++] = (char)c;
    return;
  }

  // Final byte (or invalid) — emit / rewrite then reset
  if (c >= 0x40 && c <= 0x7E && !priv && c == 'r') {
    // DECSTBM: clamp bottom to rows-1 so the footer never scrolls.
    int top = 0, down = 0;
    int * cur = &top;
    for (uint8_t i = 0; i < plen; ++i) {
      char ch = params[i];
      if (ch >= '0' && ch <= '9')
        *cur = (*cur) * 10 + (ch - '0');
      else if (ch == ';')
        cur = &down;
    }
    int const R = termRows();
    int const maxDown = (R >= 2) ? (R - 1) : 1;
    if (top < 1)
      top = 1;
    if (down < 1)
      down = maxDown;
    if (down > maxDown)
      down = maxDown;
    if (top > down)
      top = 1;
    termWriteByte(0x1B, fromISR);
    termWriteByte('[', fromISR);
    termWriteDec(top, fromISR);
    termWriteByte(';', fromISR);
    termWriteDec(down, fromISR);
    termWriteByte('r', fromISR);
  } else {
    termWriteByte(0x1B, fromISR);
    termWriteByte('[', fromISR);
    if (priv)
      termWriteByte('?', fromISR);
    for (uint8_t i = 0; i < plen; ++i)
      termWriteByte((uint8_t)params[i], fromISR);
    termWriteByte(c, fromISR);
  }
  st   = ST_NORM;
  plen = 0;
  priv = false;
}

static constexpr size_t kOttoSerialRingSize = 512;
static char            s_ottoSerialRing[kOttoSerialRingSize];
static size_t          s_ottoSerialRingLen = 0;

static void ottoSerialRingPush(uint8_t value)
{
  uint8_t c = value;
  if (c == '\r')
    c = '\n';
  if (!(c == '\n' || (c >= 32 && c < 127)))
    return;

  // No memmove here — this can run while draining on the main task only.
  if (s_ottoSerialRingLen >= kOttoSerialRingSize - 1) {
    s_ottoSerialRingLen = 0;
    s_ottoSerialRing[0] = '\0';
  }
  s_ottoSerialRing[s_ottoSerialRingLen++] = (char)c;
  s_ottoSerialRing[s_ottoSerialRingLen] = '\0';
}

static bool ottoParseKernelVersionFromSerial(char * out, size_t outLen)
{
  if (!out || outLen == 0)
    return false;
  out[0] = '\0';

  char const * p = strstr(s_ottoSerialRing, "Kernel - v");
  if (!p)
    p = strstr(s_ottoSerialRing, "KERNEL - v");
  if (!p)
    return false;
  p += 9;  /* points at 'v' in "Kernel - v1.2.x" */

  size_t i = 0;
  while (p[i] && p[i] != ' ' && p[i] != '(' && p[i] != '\n' && i < outLen - 1) {
    out[i] = p[i];
    ++i;
  }
  out[i] = '\0';
  return out[0] == 'v' && i > 1;
}

static void ottoSerialRx(void * /*args*/, uint8_t value, bool fromISR)
{
#if OTTO_USB_MIRROR
  ottoUsbMirrorPush(value, fromISR);
#endif
  // ISR must stay tiny: only enqueue. Painting Terminal from the UART ISR
  // stalls FIFO drain and overflows (same truncation on VGA + USB mirror).
  (void)ottoTermPendPush(value);
  if (!fromISR)
    ottoTermPendDrain(false);
}

static bool ottoSerialRxReady(void * /*args*/, bool fromISR)
{
  (void)fromISR;
  // Never apply Terminal backpressure to the UART RX path. Returning false
  // makes FabGL leave bytes in the ESP32 FIFO until it overflows.
  return true;
}
static int             s_selectedApp  = 0;
static char            s_uiFooter[96] = "";
static char            s_menuMsg[80]     = "";
#if OTTO_XFER_DEBUG
static char            s_menuDbg[80]     = "";
#endif
static QueueHandle_t   s_menuKeyQueue   = nullptr;  // VirtualKeyItem
static bool            s_xferUiLite     = false;    // skip heavy status bar during upload
static volatile bool   s_uploadCancel   = false;

static bool recvUiKey(VirtualKeyItem * out, uint32_t timeoutMs);
static void runWifiSetup();
static void runDisplaySetup();
static void runColorSetup();
static void runSettings();
static void startSettings();

static void colorOtto()   { Terminal.write("\e[40;97m"); }  // Otto console body
static void colorUi()     { ottoSettingsWritePageColors(Terminal); }
static void colorUiTitle(){ ottoSettingsWritePageColors(Terminal); }
static void colorUiSelect(){ ottoSettingsWritePageSelect(Terminal); }
static void colorUiMuted(){ ottoSettingsWritePageMuted(Terminal); }
static void colorFooter() { ottoSettingsWriteFooterColors(Terminal); }

static void moveAbs(int row, int col) { Terminal.printf("\e[%d;%dH", row, col); }

/** Write exactly `width` cells (caller should disable wrap for full-width rows). */
static void writePadded(char const * text, int width)
{
  char line[96];
  if (width < 1)
    return;
  if (width > (int)sizeof(line) - 1)
    width = (int)sizeof(line) - 1;
  int n = 0;
  if (text) {
    while (text[n] && n < width) {
      line[n] = text[n];
      ++n;
    }
  }
  while (n < width)
    line[n++] = ' ';
  line[n] = '\0';
  Terminal.write(line);
}

static void setMenuMsg(char const * msg)
{
  if (!msg) { s_menuMsg[0] = '\0'; return; }
  strncpy(s_menuMsg, msg, sizeof(s_menuMsg) - 1);
  s_menuMsg[sizeof(s_menuMsg) - 1] = '\0';
}

/** Footer text while F1/F10/F11 (or upload) overlay is active. */
static void setUiFooter(char const * text)
{
  if (!text) {
    s_uiFooter[0] = '\0';
    return;
  }
  strncpy(s_uiFooter, text, sizeof(s_uiFooter) - 1);
  s_uiFooter[sizeof(s_uiFooter) - 1] = '\0';
}

static void setUiFooterHints(char const * action, char const * keys)
{
  if (action && action[0] && keys && keys[0])
    snprintf(s_uiFooter, sizeof(s_uiFooter), " %s | %s ", action, keys);
  else if (action && action[0])
    snprintf(s_uiFooter, sizeof(s_uiFooter), " %s ", action);
  else if (keys && keys[0])
    snprintf(s_uiFooter, sizeof(s_uiFooter), " %s ", keys);
  else
    s_uiFooter[0] = '\0';
}

#if OTTO_XFER_DEBUG
static void setMenuDbg(char const * msg)
{
  if (!msg) {
    s_menuDbg[0] = '\0';
    return;
  }
  strncpy(s_menuDbg, msg, sizeof(s_menuDbg) - 1);
  s_menuDbg[sizeof(s_menuDbg) - 1] = '\0';
}
#endif

static void wrapOff() { Terminal.write("\e[?7l"); }
static void wrapOn()  { Terminal.write("\e[?7h"); }

static void setupScrollingForFooter()
{
  int const R = termRows();
  if (R >= 3)
    Terminal.printf("\e[%d;%dr", 1, R - 1);  // DECSTBM: leave last row alone
}

static void waitTerminalInputDrained()
{
  // availableForWrite() == inputQueueSize means the consumer drained the queue.
  for (int i = 0; i < 100; ++i) {
    if (Terminal.availableForWrite() >= Terminal.inputQueueSize)
      return;
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

/**
 * Paint footer on the last row (Otto idle or UI overlay).
 */
static void drawTerminalFooter(bool restoreCursor)
{
  int const R = termRows();
  int const C = termCols();
  if (R < 2 || C < 8)
    return;

  int col = 1, row = 1;
  bool pausedRx = false;

  if (restoreCursor) {
    ottoEnableSerialToTerm(false);
    pausedRx = true;
    waitTerminalInputDrained();
    ottoMuteSerialSend(true);
    fabgl::TerminalController tc(&Terminal);
    tc.getCursorPos(&col, &row);
    ottoMuteSerialSend(false);
    if (row < 1)
      row = 1;
    if (row >= R)
      row = R - 1;
    if (col < 1)
      col = 1;
    if (col > C)
      col = C;
  }

  setupScrollingForFooter();

  char bar[96];
  if (s_uiBusy && s_uiFooter[0]) {
    snprintf(bar, sizeof(bar), "%s", s_uiFooter);
  } else {
    snprintf(bar, sizeof(bar),
             " %s v%u | F1 Help - F10 Upload - F11 Settings ",
             OTTO_APP_NAME, (unsigned)OTTO_APP_VERSION_MAJ);
  }

  moveAbs(R, 1);
  colorFooter();
  wrapOff();
  writePadded(bar, C);

  if (restoreCursor)
    moveAbs(row, col);
  else
    moveAbs(R - 1, 1);
  wrapOn();
  colorOtto();

  if (pausedRx) {
    waitTerminalInputDrained();
    if (!s_uiBusy)
      ottoEnableSerialToTerm(true);
    ottoTermPendDrain(false);
  }
}

/** @deprecated alias — use drawTerminalFooter */
static void drawStatusBar(bool restoreCursor) { drawTerminalFooter(restoreCursor); }

static void clearScreenBlack()
{
  // USASCII G0: Otto/VT may leave DEC graphics active (wrong glyphs for punctuation)
  Terminal.write("\e(B\e[40m\e[2J\e[H");
  colorOtto();
}

// --- Otto screen snapshot (restore after F1/F10/F11 overlays) ----------------

static uint32_t * s_screenSnap      = nullptr;
static size_t     s_screenSnapBytes = 0;
static int        s_snapCol         = 1;
static int        s_snapRow         = 1;
static bool       s_snapValid       = false;

/** Capture current text map + cursor before a UI overlay overwrites the screen. */
static bool saveOttoScreen()
{
  waitTerminalInputDrained();
  int const cols = termCols();
  int const rows = termRows();
  uint32_t const * src = DisplayController.mapPtr();
  if (!src || cols < 1 || rows < 1)
    return false;

  size_t const bytes = (size_t)cols * (size_t)rows * sizeof(uint32_t);
  if (!s_screenSnap || s_screenSnapBytes != bytes) {
    if (s_screenSnap) {
      heap_caps_free(s_screenSnap);
      s_screenSnap = nullptr;
    }
    s_screenSnap = (uint32_t *)heap_caps_malloc(bytes, MALLOC_CAP_8BIT | MALLOC_CAP_INTERNAL);
    if (!s_screenSnap)
      s_screenSnap = (uint32_t *)heap_caps_malloc(bytes, MALLOC_CAP_8BIT | MALLOC_CAP_SPIRAM);
    s_screenSnapBytes = s_screenSnap ? bytes : 0;
  }
  if (!s_screenSnap) {
    s_snapValid = false;
    return false;
  }

  memcpy(s_screenSnap, src, bytes);

  ottoMuteSerialSend(true);
  fabgl::TerminalController tc(&Terminal);
  tc.getCursorPos(&s_snapCol, &s_snapRow);
  ottoMuteSerialSend(false);
  if (s_snapRow < 1)
    s_snapRow = 1;
  if (s_snapRow >= rows)
    s_snapRow = rows - 1;
  if (s_snapCol < 1)
    s_snapCol = 1;
  if (s_snapCol > cols)
    s_snapCol = cols;

  s_snapValid = true;
  return true;
}

/** Restore text map + cursor after leaving a UI overlay. */
static void restoreOttoScreen()
{
  waitTerminalInputDrained();
  uint32_t const * dst = DisplayController.mapPtr();
  if (!s_snapValid || !s_screenSnap || !dst) {
    clearScreenBlack();
    setupScrollingForFooter();
    moveAbs(1, 1);
    colorOtto();
    Terminal.enableCursor(true);
    return;
  }

  memcpy((void *)dst, s_screenSnap, s_screenSnapBytes);
  // Re-bind map so VGA ISR sees restored cells (same pointer, forces sync wait).
  DisplayController.setTextMap(dst, termRows());
  s_snapValid = false;

  setupScrollingForFooter();
  moveAbs(s_snapRow, s_snapCol);
  colorOtto();
  Terminal.enableCursor(true);
}

/** Common exit from F1/F10/F11: restore Otto console under the overlay. */
static void leaveUiToOtto()
{
  s_uiFooter[0] = '\0';
  ottoMuteSerialSend(false);
  restoreOttoScreen();
  drawTerminalFooter(true);
  waitTerminalInputDrained();
  ottoInstallSerialBridge();
  ottoUartFlushHwRx();
}

// --- Menu -------------------------------------------------------------------

static int listTopRow() { return 5; }
static int listBottomRow() { return termRows() - 1; }

static int menuFindTargetById(char const * id)
{
  if (!id || !id[0])
    return -1;
  for (int i = 0; i < s_targets.count; ++i) {
    if (strcmp(s_targets.targets[i].id, id) == 0)
      return i;
  }
  return -1;
}

static int menuFindTargetByKernel(char const * kernelVer)
{
  if (!kernelVer || !kernelVer[0])
    return -1;
  for (int i = 0; i < s_targets.count; ++i) {
    if (strcmp(s_targets.targets[i].kernel_version, kernelVer) == 0)
      return i;
  }
  return -1;
}

static void menuInitFallbackTargets()
{
  s_targets.count = 1;
  s_targets.default_target_id[0] = '\0';
  OttoWifiTarget & t = s_targets.targets[0];
  strncpy(t.id, "current", sizeof(t.id) - 1);
  strncpy(t.kernel_version, "latest", sizeof(t.kernel_version) - 1);
  strncpy(t.label, "Latest", sizeof(t.label) - 1);
  strncpy(t.catalog_path, "roms/apps/current/asm", sizeof(t.catalog_path) - 1);
  strncpy(s_targets.default_target_id, "current", sizeof(s_targets.default_target_id) - 1);
}

static void menuResolveTarget(bool useAutoDetect)
{
  if (useAutoDetect)
    ottoParseKernelVersionFromSerial(s_detectedKernel, sizeof(s_detectedKernel));
  else if (!s_detectedKernel[0])
    ottoParseKernelVersionFromSerial(s_detectedKernel, sizeof(s_detectedKernel));

  int idx = -1;
  if (s_detectedKernel[0])
    idx = menuFindTargetByKernel(s_detectedKernel);
  if (idx < 0) {
    char last[OTTO_WIFI_TARGET_ID_MAX];
    ottoWifiGetLastAppTarget(last, sizeof(last));
    if (last[0])
      idx = menuFindTargetById(last);
  }
  if (idx < 0 && s_targets.default_target_id[0])
    idx = menuFindTargetById(s_targets.default_target_id);
  if (idx < 0 && s_targets.count > 0)
    idx = 0;
  if (idx >= 0)
    s_selectedTarget = idx;
}

static bool menuFetchCatalogForTarget(char * msg, size_t msgLen)
{
  if (s_targets.count <= 0 || s_selectedTarget < 0 || s_selectedTarget >= s_targets.count) {
    snprintf(msg, msgLen, "No kernel target");
    return false;
  }

  OttoWifiTarget const & t = s_targets.targets[s_selectedTarget];
  OttoWifiResult const r = ottoWifiFetchCatalogPath(t.catalog_path, &s_catalog);
  char detail[96];
  ottoWifiGetLastDetail(detail, sizeof(detail));
  snprintf(msg, msgLen, "%s - %s", ottoWifiResultStr(r), detail);
  if (r == OttoWifiResult::Ok)
    ottoWifiSetLastAppTarget(t.id);
  if (s_selectedApp >= s_catalog.count)
    s_selectedApp = s_catalog.count > 0 ? s_catalog.count - 1 : 0;
  return r == OttoWifiResult::Ok;
}

static void menuCycleTarget(int delta)
{
  if (s_targets.count <= 1)
    return;
  s_selectedTarget = (s_selectedTarget + delta + s_targets.count) % s_targets.count;
  char msg[80];
  setMenuMsg("Fetching catalog...");
  refreshMenuFooter();
  menuFetchCatalogForTarget(msg, sizeof(msg));
  setMenuMsg(msg);
  redrawMenu();
}

/** Paint overlay body rows 1..(last-1) with page UI colors (footer row untouched). */
static void fillUiPageBackground()
{
  int const C = termCols();
  int const bot = listBottomRow();
  wrapOff();
  for (int r = 1; r <= bot; ++r) {
    moveAbs(r, 1);
    colorUi();
    writePadded("", C);
  }
  wrapOn();
}

static void drawMenuChrome()
{
  int const C = termCols();
  bool const online = ottoWifiIsConnected();

  Terminal.write("\e[r");
  fillUiPageBackground();
  wrapOff();

  moveAbs(1, 1); colorUiTitle();
  writePadded(" Apps Repository ", C);

  moveAbs(2, 1); colorUiMuted();
  char targetLine[96];
  if (s_targets.count > 0 && s_selectedTarget >= 0 && s_selectedTarget < s_targets.count) {
    OttoWifiTarget const & t = s_targets.targets[s_selectedTarget];
    if (s_detectedKernel[0]) {
      bool const match = strcmp(t.kernel_version, s_detectedKernel) == 0;
      snprintf(targetLine, sizeof(targetLine),
               " Kernel target: < %s >  Otto: %s%s",
               t.label, s_detectedKernel, match ? " (match)" : "");
    } else {
      snprintf(targetLine, sizeof(targetLine), " Kernel target: < %s >  (%s)",
               t.label, t.kernel_version);
    }
  } else {
    snprintf(targetLine, sizeof(targetLine), " Kernel target: (not loaded - press R)");
  }
  writePadded(targetLine, C);

  moveAbs(3, 1); colorUiMuted();
  char info[80];
  if (online) {
    snprintf(info, sizeof(info), " WiFi OK   %d app(s)   %s",
             s_catalog.count, ottoWifiSsid());
  } else if (ottoWifiHasCredentials()) {
    snprintf(info, sizeof(info), " WiFi offline (%s) - use F11 Settings", ottoWifiSsid());
  } else {
    snprintf(info, sizeof(info), " WiFi not configured - use F11 Settings");
  }
  writePadded(info, C);

  moveAbs(4, 1); colorUi(); writePadded("", C);

  wrapOn();
}

static void drawAppList()
{
  int const top = listTopRow();
  int const bot = listBottomRow();
  int const visible = bot - top + 1;
  int const C = termCols();

  wrapOff();
  if (s_catalog.count <= 0) {
    moveAbs(top, 1);
    colorUi();
    if (!ottoWifiIsConnected())
      writePadded("  (WiFi required - connect first, then R to fetch)", C);
    else
      writePadded("  (empty - press R to refresh catalog)", C);
    wrapOn();
    return;
  }

  if (s_selectedApp < 0)
    s_selectedApp = 0;
  if (s_selectedApp >= s_catalog.count)
    s_selectedApp = s_catalog.count - 1;

  int window = 0;
  if (s_selectedApp >= visible)
    window = s_selectedApp - visible + 1;

  for (int i = 0; i < visible; ++i) {
    int const idx = window + i;
    moveAbs(top + i, 1);
    if (idx >= s_catalog.count) {
      colorUi();
      writePadded("", C);
      continue;
    }
    char line[82];
    snprintf(line, sizeof(line), " %c %2d  %s",
             (idx == s_selectedApp) ? '>' : ' ',
             idx + 1, s_catalog.apps[idx].name);
    if (idx == s_selectedApp)
      colorUiSelect();
    else
      colorUi();
    writePadded(line, C);
  }
  wrapOn();
}

static void redrawMenu()
{
  drawMenuChrome();
  drawAppList();
  Terminal.enableCursor(false);
  if (s_menuMsg[0])
    setUiFooterHints(s_menuMsg, "ESC to exit");
  else if (ottoWifiIsConnected())
    setUiFooterHints("On Otto: u+Enter, then pick app",
                     "Enter upload  Tab target  A auto  R refresh  ESC");
  else
    setUiFooterHints("WiFi required", "F11 Settings  ESC exit");
  drawTerminalFooter(false);
}

static void refreshMenuFooter()
{
#if OTTO_XFER_DEBUG
  if (s_xferUiLite && s_menuDbg[0]) {
    char combined[96];
    snprintf(combined, sizeof(combined), " %s | %s ", s_menuMsg, s_menuDbg);
    setUiFooter(combined);
  } else
#endif
  if (s_menuMsg[0])
    setUiFooterHints(s_menuMsg, s_xferUiLite ? "ESC cancel" : "ESC exit");
  drawTerminalFooter(false);
}

static bool requireWifiForApps()
{
  if (ottoWifiIsConnected())
    return true;
  if (ottoWifiHasCredentials())
    setMenuMsg("WiFi offline - configure in F11 Settings");
  else
    setMenuMsg("WiFi not configured - use F11 Settings");
  refreshMenuFooter();
  return false;
}

static void menuRefresh()
{
  if (!requireWifiForApps())
    return;

  setMenuMsg("Fetching targets...");
  refreshMenuFooter();
  OttoWifiResult tr = ottoWifiFetchTargets(&s_targets);
  if (tr != OttoWifiResult::Ok)
    menuInitFallbackTargets();

  menuResolveTarget(true);

  char msg[80];
  setMenuMsg("Fetching catalog...");
  refreshMenuFooter();
  menuFetchCatalogForTarget(msg, sizeof(msg));
  setMenuMsg(msg);
  redrawMenu();
}

static void wifiStatusToMenu(void * /*ctx*/, char const * msg)
{
  if (!msg) return;
  setMenuMsg(msg);
  refreshMenuFooter();
}

static OttoUartRaw * s_uploadUartPump = nullptr;

/** True when user pressed ESC during upload/download (menu still open). */
static bool pollUploadCancel(void * /*ctx*/)
{
  if (s_uploadCancel)
    return true;

  VirtualKeyItem item{};
  while (s_menuKeyQueue && xQueueReceive(s_menuKeyQueue, &item, 0) == pdTRUE) {
    VirtualKey const vk = item.vk;
    if (vk == VirtualKey::VK_ESCAPE) {
      s_uploadCancel = true;
      return true;
    }
  }
  return false;
}

static void wifiProgressToMenu(void * /*ctx*/, size_t got, size_t total)
{
  (void)pollUploadCancel(nullptr);

  if (s_uploadUartPump)
    s_uploadUartPump->pumpRx();

#if OTTO_XFER_DEBUG
  if (s_uploadUartPump) {
    char d[80];
    snprintf(d, sizeof(d), "DL %u/%u ring=%u",
             (unsigned)got,
             (unsigned)(total > 0 ? total : got),
             (unsigned)s_uploadUartPump->rxPendingCount());
    setMenuDbg(d);
  }
#endif

  char msg[48];
  if (total > 0)
    snprintf(msg, sizeof(msg), "Download %u / %u", (unsigned)got, (unsigned)total);
  else
    snprintf(msg, sizeof(msg), "Download %u bytes", (unsigned)got);
  setMenuMsg(msg);
  refreshMenuFooter();
}

static void xmodemStatusToMenu(void * /*ctx*/, char const * msg)
{
  if (!msg) return;
  setMenuMsg(msg);
  refreshMenuFooter();
}

#if OTTO_XFER_DEBUG
static void xmodemDbgToMenu(void * /*ctx*/, char const * msg)
{
  if (!msg) return;
  setMenuDbg(msg);
  refreshMenuFooter();
}
#endif

static bool menuUpload()
{
  if (!requireWifiForApps())
    return false;
  if (s_catalog.count <= 0) {
    setMenuMsg("No apps - press R first");
    refreshMenuFooter();
    return false;
  }
  if (s_selectedApp < 0 || s_selectedApp >= s_catalog.count)
    s_selectedApp = 0;

  OttoWifiApp const & app = s_catalog.apps[s_selectedApp];
  if (!app.url[0]) {
    setMenuMsg("Empty URL - refresh catalog");
    refreshMenuFooter();
    return false;
  }

  s_xferUiLite = true;
  s_uploadCancel = false;
#if OTTO_XFER_DEBUG
  setMenuDbg("debug: starting upload");
#endif

  // Variant A: user already typed `u` on Otto. Take UART before WiFi download so
  // Otto's repeating 'C' is captured while the .bin is fetched from GitHub.
  OttoUartRaw uart;
  if (!uart.begin(&SerialPort, &SerialPortTerminalConnector, &Terminal)) {
    setMenuMsg("UART not ready");
    refreshMenuFooter();
    s_xferUiLite = false;
    return false;
  }

  s_uploadUartPump = &uart;
  ottoMuteSerialSend(true);

  char msg[80];
  snprintf(msg, sizeof(msg), "DL %s (ESC=cancel)...", app.name);
  setMenuMsg(msg);
  refreshMenuFooter();

  char dlUrl[OTTO_WIFI_URL_MAX + 32];
  ottoWifiCacheBustUrl(app.url, dlUrl, sizeof(dlUrl));

  uint8_t * data = nullptr;
  size_t len = 0;
  OttoWifiResult const dr = ottoWifiDownload(
    dlUrl, &data, &len, wifiProgressToMenu, nullptr, wifiStatusToMenu, nullptr,
    pollUploadCancel, nullptr);
  if (dr != OttoWifiResult::Ok || !data || len == 0) {
    char detail[96];
    ottoWifiGetLastDetail(detail, sizeof(detail));
    if (dr == OttoWifiResult::Aborted)
      snprintf(msg, sizeof(msg), "Download cancelled");
    else
      snprintf(msg, sizeof(msg), "%s - %s", ottoWifiResultStr(dr), detail);
    setMenuMsg(msg);
    ottoWifiFree(data);
    s_uploadUartPump = nullptr;
    uart.abortOttoReceiver();
    uart.end();
    ottoMuteSerialSend(false);
    ottoInstallSerialBridge();
    refreshMenuFooter();
    s_xferUiLite = false;
#if OTTO_XFER_DEBUG
    setMenuDbg(nullptr);
#endif
    return false;
  }

  snprintf(msg, sizeof(msg), "Got %u B - XMODEM (ESC=cancel)...", (unsigned)len);
  setMenuMsg(msg);
  refreshMenuFooter();

  ottoWifiPauseForUart();

  OttoXmodemOptions opts;
  opts.sendUploadCommand = false;  // Otto already in receive mode (minicom-style)
  opts.maxRetries        = 8;

  OttoXmodemStatus st;
  st.onStatus    = xmodemStatusToMenu;
#if OTTO_XFER_DEBUG
  st.onDbg       = xmodemDbgToMenu;
#else
  st.onDbg       = nullptr;
#endif
  st.shouldAbort = pollUploadCancel;
  st.ctx         = nullptr;

  OttoXmodemResult const xr = ottoXmodemSend(uart, data, len, opts, &st);
  s_uploadUartPump = nullptr;
  uart.end();
  ottoMuteSerialSend(false);
  ottoInstallSerialBridge();
  ottoEnableSerialToTerm(false);  // stay in F10: do not paint Otto chatter into the menu
  ottoWifiFree(data);
  s_xferUiLite = false;
#if OTTO_XFER_DEBUG
  setMenuDbg(nullptr);
#endif

  if (xr == OttoXmodemResult::Ok) {
    setMenuMsg("Upload OK - returning...");
    refreshMenuFooter();
    vTaskDelay(pdMS_TO_TICKS(400));
    return true;
  }

  if (xr == OttoXmodemResult::Aborted)
    snprintf(msg, sizeof(msg), "Upload cancelled");
  else if (xr == OttoXmodemResult::Timeout)
    snprintf(msg, sizeof(msg), "No XMODEM C - u+Enter on Otto first");
  else
    snprintf(msg, sizeof(msg), "%s - retry or ESC", ottoXmodemResultStr(xr));
  setMenuMsg(msg);
  refreshMenuFooter();
  return false;
}

static void runWifiMenu()
{
  // Stop Otto bytes from painting into the menu
  ottoEnableSerialToTerm(false);

  // Draw on the MAIN text map (no 1049h). Keep Terminal active so writes paint
  // the CRT; keys are routed via s_menuKeyQueue (see onVirtualKeyItem).
  setMenuMsg("");
  saveOttoScreen();
  clearScreenBlack();
  waitTerminalInputDrained();
  redrawMenu();
  waitTerminalInputDrained();

  // Cached catalog: refresh from network only when empty; R forces update.
  if (s_targets.count <= 0 || s_catalog.count <= 0) {
    if (ottoWifiIsConnected())
      menuRefresh();
    else if (s_targets.count <= 0)
      menuInitFallbackTargets();
  } else {
    menuResolveTarget(true);
  }

  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;

    if (vk == VirtualKey::VK_ESCAPE)
      break;

    if (vk == VirtualKey::VK_UP) {
      if (s_catalog.count > 0) {
        s_selectedApp = (s_selectedApp <= 0) ? s_catalog.count - 1 : s_selectedApp - 1;
        drawAppList();
      }
    } else if (vk == VirtualKey::VK_DOWN) {
      if (s_catalog.count > 0) {
        s_selectedApp = (s_selectedApp + 1) % s_catalog.count;
        drawAppList();
      }
    } else if (vk == VirtualKey::VK_TAB) {
      menuCycleTarget(+1);
    } else if (vk == VirtualKey::VK_RETURN || vk == VirtualKey::VK_KP_ENTER) {
      if (menuUpload())
        break;
    } else if (vk == VirtualKey::VK_r || vk == VirtualKey::VK_R) {
      menuRefresh();
    } else if (item.ASCII == '[') {
      menuCycleTarget(-1);
    } else if (item.ASCII == ']') {
      menuCycleTarget(+1);
    } else if (item.ASCII == 'a' || item.ASCII == 'A') {
      menuResolveTarget(true);
      char msg[80];
      setMenuMsg("Fetching catalog...");
      refreshMenuFooter();
      menuFetchCatalogForTarget(msg, sizeof(msg));
      setMenuMsg(msg);
      redrawMenu();
    }
  }

  leaveUiToOtto();

  ottoEnableSerialToTerm(true);
  if (s_menuKeyQueue)
    xQueueReset(s_menuKeyQueue);
  Terminal.keyboard()->emptyVirtualKeyQueue();
}

static void wifiMenuTask(void * /*arg*/)
{
  runWifiMenu();
  s_uiBusy = false;
  vTaskDelete(nullptr);
}

static bool ensureMenuKeyQueue()
{
  if (s_menuKeyQueue)
    return true;
  s_menuKeyQueue = xQueueCreate(32, sizeof(VirtualKeyItem));
  return s_menuKeyQueue != nullptr;
}

static void startWifiMenu()
{
  if (s_uiBusy)
    return;
  if (!ensureMenuKeyQueue())
    return;
  xQueueReset(s_menuKeyQueue);
  s_uiBusy = true;
  ottoTermPendClear();
  drawStatusBar(true);
  BaseType_t const ok = xTaskCreatePinnedToCore(
    wifiMenuTask, "otto_wifi_menu", OTTO_WIFI_MENU_STACK, nullptr, 5, nullptr, 0);
  if (ok != pdPASS) {
    s_uiBusy = false;
  }
}


// --- F11 WiFi setup (scan / password / NVS) ---------------------------------

static OttoWifiNetworkList s_wifiNets{};
static int                 s_wifiSel = 0;

static bool recvUiKey(VirtualKeyItem * out, uint32_t timeoutMs)
{
  if (!out || !s_menuKeyQueue)
    return false;
  return xQueueReceive(s_menuKeyQueue, out, pdMS_TO_TICKS(timeoutMs)) == pdTRUE;
}

static void drawWifiSetupList()
{
  int const top = listTopRow();
  int const bot = listBottomRow();
  int const visible = bot - top + 1;
  int const C = termCols();

  wrapOff();
  if (s_wifiNets.count <= 0) {
    moveAbs(top, 1);
    colorUi();
    writePadded("  (no networks - press R to rescan)", C);
    wrapOn();
    return;
  }

  if (s_wifiSel < 0)
    s_wifiSel = 0;
  if (s_wifiSel >= s_wifiNets.count)
    s_wifiSel = s_wifiNets.count - 1;

  int window = 0;
  if (s_wifiSel >= visible)
    window = s_wifiSel - visible + 1;

  for (int i = 0; i < visible; ++i) {
    int const idx = window + i;
    moveAbs(top + i, 1);
    if (idx >= s_wifiNets.count) {
      colorUi();
      writePadded("", C);
      continue;
    }
    OttoWifiNetwork const & n = s_wifiNets.nets[idx];
    char line[82];
    int const pad = 28 - (int)strlen(n.ssid);
    snprintf(line, sizeof(line), " %c %s%*s %4ddBm %s",
             (idx == s_wifiSel) ? '>' : ' ',
             n.ssid,
             pad > 0 ? pad : 0, "",
             (int)n.rssi,
             n.open ? "open" : "sec");
    if (idx == s_wifiSel)
      colorUiSelect();
    else
      colorUi();
    writePadded(line, C);
  }
  wrapOn();
}

static void drawWifiSetupChrome()
{
  int const C = termCols();
  Terminal.write("\e[r");
  wrapOff();
  fillUiPageBackground();
  moveAbs(1, 1); colorUiTitle();
  writePadded(" WiFi Setup - select network (saved in NVS) ", C);

  moveAbs(2, 1); colorUiMuted();
  char info[80];
  if (ottoWifiHasCredentials())
    snprintf(info, sizeof(info), " Saved: %-28s  %s",
             ottoWifiSsid(),
             ottoWifiIsConnected() ? "connected" : "not connected");
  else
    snprintf(info, sizeof(info), " Saved: (none) - pick an AP below");
  writePadded(info, C);

  moveAbs(3, 1); colorUi(); writePadded("", C);

  wrapOn();
}

static void redrawWifiSetup()
{
  drawWifiSetupChrome();
  drawWifiSetupList();
  Terminal.enableCursor(false);
  setUiFooterHints(s_menuMsg[0] ? s_menuMsg : "Select WiFi network",
                   "Up/Dn  Enter  R rescan  D clear  ESC exit");
  drawTerminalFooter(false);
}

static void wifiSetupRescan()
{
  setMenuMsg("Scanning WiFi...");
  refreshMenuFooter();
  OttoWifiResult const r = ottoWifiScanList(&s_wifiNets);
  char detail[96];
  ottoWifiGetLastDetail(detail, sizeof(detail));
  char msg[80];
  snprintf(msg, sizeof(msg), "%s - %s", ottoWifiResultStr(r), detail);
  setMenuMsg(msg);
  s_wifiSel = 0;
  redrawWifiSetup();
}

static bool wifiSetupPassword(char const * ssid, bool isOpen)
{
  char pass[OTTO_WIFI_PASS_MAX];
  pass[0] = '\0';
  size_t plen = 0;

  int const C = termCols();

  auto paint = [&]() {
    Terminal.write("\e[r");
    fillUiPageBackground();
    wrapOff();
    moveAbs(1, 1); colorUiTitle();
    writePadded(" WiFi Setup - password ", C);
    moveAbs(3, 1); colorUi();
    char line[80];
    snprintf(line, sizeof(line), " SSID: %s%s", ssid, isOpen ? "  (open network)" : "");
    writePadded(line, C);
    moveAbs(5, 1); colorUiMuted();
    writePadded(" Type password, Enter to save, Esc cancel, Backspace delete", C);
    moveAbs(7, 1); colorUiSelect();
    char stars[OTTO_WIFI_PASS_MAX];
    for (size_t i = 0; i < plen; ++i)
      stars[i] = '*';
    stars[plen] = '\0';
    snprintf(line, sizeof(line), " Password: %s", stars);
    writePadded(line, C);
    setUiFooterHints(isOpen ? "Open network" : "Enter password to save",
                     "Enter save  ESC cancel");
    wrapOn();
    drawTerminalFooter(false);
    Terminal.enableCursor(true);
  };

  if (isOpen) {
    setMenuMsg("Open network - Enter saves with empty password");
  } else {
    setMenuMsg("Enter password");
  }
  paint();

  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;

    if (vk == VirtualKey::VK_ESCAPE)
      return false;

    if (vk == VirtualKey::VK_RETURN || vk == VirtualKey::VK_KP_ENTER) {
      if (!ottoWifiSaveCredentials(ssid, pass)) {
        setMenuMsg("NVS save failed");
        paint();
        continue;
      }
      setMenuMsg("Saved - connecting...");
      paint();
      waitTerminalInputDrained();
      OttoWifiResult const cr = ottoWifiConnect(20000);
      char detail[96];
      ottoWifiGetLastDetail(detail, sizeof(detail));
      char msg[80];
      snprintf(msg, sizeof(msg), "%s - %s", ottoWifiResultStr(cr), detail);
      setMenuMsg(msg);
      // brief pause so user sees result
      for (int i = 0; i < 30; ++i) {
        VirtualKeyItem skip{};
        recvUiKey(&skip, 50);
      }
      return true;
    }

    if (vk == VirtualKey::VK_BACKSPACE) {
      if (plen > 0) {
        pass[--plen] = '\0';
        paint();
      }
      continue;
    }

    uint8_t ch = item.ASCII;
    if (ch >= 32 && ch < 127 && plen + 1 < sizeof(pass)) {
      pass[plen++] = (char)ch;
      pass[plen] = '\0';
      paint();
    }
  }
}

/** Interactive WiFi setup; assumes RX already disabled and key queue active. */
static void runWifiSetup()
{
  setMenuMsg("Scanning...");
  clearScreenBlack();
  waitTerminalInputDrained();
  redrawWifiSetup();
  waitTerminalInputDrained();
  wifiSetupRescan();

  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;

    if (vk == VirtualKey::VK_ESCAPE)
      break;

    if (vk == VirtualKey::VK_UP) {
      if (s_wifiNets.count > 0) {
        s_wifiSel = (s_wifiSel <= 0) ? s_wifiNets.count - 1 : s_wifiSel - 1;
        drawWifiSetupList();
      }
    } else if (vk == VirtualKey::VK_DOWN) {
      if (s_wifiNets.count > 0) {
        s_wifiSel = (s_wifiSel + 1) % s_wifiNets.count;
        drawWifiSetupList();
      }
    } else if (vk == VirtualKey::VK_r || vk == VirtualKey::VK_R) {
      wifiSetupRescan();
    } else if (vk == VirtualKey::VK_d || vk == VirtualKey::VK_D) {
      ottoWifiClearCredentials();
      ottoWifiDisconnect();
      setMenuMsg("Cleared saved credentials");
      redrawWifiSetup();
    } else if (vk == VirtualKey::VK_RETURN || vk == VirtualKey::VK_KP_ENTER) {
      if (s_wifiNets.count <= 0) {
        setMenuMsg("No networks - press R");
        refreshMenuFooter();
        continue;
      }
      OttoWifiNetwork const & net = s_wifiNets.nets[s_wifiSel];
      if (wifiSetupPassword(net.ssid, net.open)) {
        // stay on setup screen showing updated saved SSID
      }
      redrawWifiSetup();
    }
  }
}


static int s_settingsSel = 0;
static int s_displaySel  = 0;

static void drawDisplaySetup()
{
  int const C = termCols();
  Terminal.write("\e[r");
  wrapOff();
  Terminal.enableCursor(false);
  fillUiPageBackground();

  moveAbs(1, 1); colorUiTitle();
  writePadded(" Settings - Display size ", C);

  moveAbs(2, 1); colorUiMuted();
  char cur[80];
  char sz[16];
  ottoSettingsFormatSize(ottoSettingsFontPreset(), sz, sizeof(sz));
  snprintf(cur, sizeof(cur), " Now: %s (cols fixed at 80 by VGA text hardware)", sz);
  writePadded(cur, C);

  moveAbs(3, 1); colorUi();
  writePadded(" VGATextController is 640x480; only font height changes row count.", C);

  int const n = ottoSettingsPresetCount();
  if (s_displaySel < 0)
    s_displaySel = 0;
  if (s_displaySel >= n)
    s_displaySel = n - 1;

  int row = 5;
  for (int i = 0; i < n; ++i) {
    OttoFontPresetInfo const & info = ottoSettingsPresetInfo(i);
    bool const active = ((int)ottoSettingsFontPreset() == i);
    char line[82];
    snprintf(line, sizeof(line), " %c %s%s",
             (i == s_displaySel) ? '>' : ' ',
             info.label,
             active ? "  [active]" : "");
    moveAbs(row++, 1);
    if (i == s_displaySel)
      colorUiSelect();
    else
      colorUi();
    writePadded(line, C);
  }

  wrapOn();
}

static void redrawDisplaySetup()
{
  drawDisplaySetup();
  setUiFooterHints(s_menuMsg[0] ? s_menuMsg : "Pick display size",
                   "Enter save+reboot  ESC back");
  drawTerminalFooter(false);
}

static void runDisplaySetup()
{
  s_displaySel = (int)ottoSettingsFontPreset();
  setMenuMsg("Pick a size - Enter saves to NVS and reboots");
  clearScreenBlack();
  waitTerminalInputDrained();
  redrawDisplaySetup();
  waitTerminalInputDrained();

  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;

    if (vk == VirtualKey::VK_ESCAPE)
      break;

    if (vk == VirtualKey::VK_UP) {
      s_displaySel = (s_displaySel <= 0) ? ottoSettingsPresetCount() - 1 : s_displaySel - 1;
      redrawDisplaySetup();
    } else if (vk == VirtualKey::VK_DOWN) {
      s_displaySel = (s_displaySel + 1) % ottoSettingsPresetCount();
      redrawDisplaySetup();
    } else if (vk == VirtualKey::VK_RETURN || vk == VirtualKey::VK_KP_ENTER) {
      OttoFontPreset const p = (OttoFontPreset)s_displaySel;
      if (p == ottoSettingsFontPreset()) {
        setMenuMsg("Already active");
        redrawDisplaySetup();
        continue;
      }
      if (!ottoSettingsSetFontPreset(p)) {
        setMenuMsg("NVS save failed");
        redrawDisplaySetup();
        continue;
      }
      char sz[16];
      ottoSettingsFormatSize(p, sz, sizeof(sz));
      char msg[80];
      snprintf(msg, sizeof(msg), "Saved %s - rebooting...", sz);
      setMenuMsg(msg);
      redrawDisplaySetup();
      waitTerminalInputDrained();
      vTaskDelay(pdMS_TO_TICKS(600));
      ESP.restart();
    }
  }
}

static int s_colorField = 0;

static void drawColorSetup(uint8_t ftBg, uint8_t ftFg, uint8_t pgBg, uint8_t pgFg, int field)
{
  int const C = termCols();
  Terminal.write("\e[r");
  wrapOff();
  Terminal.enableCursor(false);
  fillUiPageBackground();

  moveAbs(1, 1); colorUiTitle();
  writePadded(" Settings - UI colors ", C);

  moveAbs(2, 1); colorUiMuted();
  writePadded(" Footer and F1/F10/F11 pages can use different colors ", C);

  char line[82];
  struct { int id; char const * label; uint8_t value; bool isBg; } rows[] = {
    { 0, "Footer background:", ftBg, true },
    { 1, "Footer foreground:", ftFg, false },
    { 2, "Page background:", pgBg, true },
    { 3, "Page foreground:", pgFg, false },
  };
  int row = 4;
  for (auto const & r : rows) {
    snprintf(line, sizeof(line), " %c %s %s",
             (field == r.id) ? '>' : ' ',
             r.label,
             ottoSettingsAnsiColorName(r.value));
    moveAbs(row++, 1);
    if (field == r.id)
      colorUiSelect();
    else
      colorUi();
    writePadded(line, C);
  }

  moveAbs(row + 1, 1); colorUi();
  writePadded(" Page preview: OttoTerminal menu text ", C);

  wrapOn();
}

static void redrawColorSetup(uint8_t ftBg, uint8_t ftFg, uint8_t pgBg, uint8_t pgFg, int field)
{
  drawColorSetup(ftBg, ftFg, pgBg, pgFg, field);
  setUiFooterHints("Left/Right change color  Up/Dn select field", "ESC exit");
  drawTerminalFooter(false);
}

static void runColorSetup()
{
  uint8_t ftBg = ottoSettingsFooterBg();
  uint8_t ftFg = ottoSettingsFooterFg();
  uint8_t pgBg = ottoSettingsPageBg();
  uint8_t pgFg = ottoSettingsPageFg();
  s_colorField = 0;
  setMenuMsg("Footer bar uses footer colors");
  clearScreenBlack();
  waitTerminalInputDrained();
  redrawColorSetup(ftBg, ftFg, pgBg, pgFg, s_colorField);
  waitTerminalInputDrained();

  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;

    if (vk == VirtualKey::VK_ESCAPE)
      break;

    bool changed = false;
    if (vk == VirtualKey::VK_UP) {
      s_colorField = (s_colorField + 3) % 4;
      redrawColorSetup(ftBg, ftFg, pgBg, pgFg, s_colorField);
    } else if (vk == VirtualKey::VK_DOWN) {
      s_colorField = (s_colorField + 1) % 4;
      redrawColorSetup(ftBg, ftFg, pgBg, pgFg, s_colorField);
    } else if (vk == VirtualKey::VK_LEFT || vk == VirtualKey::VK_RIGHT) {
      int const delta = (vk == VirtualKey::VK_RIGHT) ? 1 : -1;
      switch (s_colorField) {
        case 0:
          ftBg = (uint8_t)((ftBg + delta + 8) % 8);
          break;
        case 1:
          ftFg = (uint8_t)((ftFg + delta + 16) % 16);
          break;
        case 2:
          pgBg = (uint8_t)((pgBg + delta + 8) % 8);
          break;
        default:
          pgFg = (uint8_t)((pgFg + delta + 16) % 16);
          break;
      }
      changed = true;
    }

    if (changed) {
      ottoSettingsSetFooterColors(ftBg, ftFg);
      ottoSettingsSetPageColors(pgBg, pgFg);
      redrawColorSetup(ftBg, ftFg, pgBg, pgFg, s_colorField);
    }
  }
}

static void drawSettingsHub()
{
  int const C = termCols();
  Terminal.write("\e[r");
  wrapOff();
  Terminal.enableCursor(false);
  fillUiPageBackground();

  moveAbs(1, 1); colorUiTitle();
  writePadded(" Settings ", C);

  moveAbs(2, 1); colorUiMuted();
  char info[80];
  char sz[16];
  ottoSettingsFormatSize(ottoSettingsFontPreset(), sz, sizeof(sz));
  if (ottoWifiHasCredentials())
    snprintf(info, sizeof(info), " Display %s   WiFi: %s%s",
             sz, ottoWifiSsid(), ottoWifiIsConnected() ? " OK" : "");
  else
    snprintf(info, sizeof(info), " Display %s   WiFi: (not configured)", sz);
  writePadded(info, C);

  char const * items[] = {
    " WiFi networks & password",
    " Display size (rows via font height)",
    " UI colors (footer + menu pages)",
  };
  int const n = 3;
  if (s_settingsSel < 0)
    s_settingsSel = 0;
  if (s_settingsSel >= n)
    s_settingsSel = n - 1;

  for (int i = 0; i < n; ++i) {
    moveAbs(4 + i, 1);
    char line[82];
    snprintf(line, sizeof(line), " %c %s", (i == s_settingsSel) ? '>' : ' ', items[i]);
    if (i == s_settingsSel)
      colorUiSelect();
    else
      colorUi();
    writePadded(line, C);
  }

  wrapOn();
}

static void redrawSettingsHub()
{
  drawSettingsHub();
  setUiFooterHints(s_menuMsg[0] ? s_menuMsg : "Choose a category",
                   "Enter open  ESC exit");
  drawTerminalFooter(false);
}

static void runSettings()
{
  setMenuMsg("Choose a category");
  clearScreenBlack();
  waitTerminalInputDrained();
  redrawSettingsHub();
  waitTerminalInputDrained();

  int const n = 3;
  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;

    if (vk == VirtualKey::VK_ESCAPE)
      break;

    if (vk == VirtualKey::VK_UP) {
      s_settingsSel = (s_settingsSel <= 0) ? n - 1 : s_settingsSel - 1;
      redrawSettingsHub();
    } else if (vk == VirtualKey::VK_DOWN) {
      s_settingsSel = (s_settingsSel + 1) % n;
      redrawSettingsHub();
    } else if (vk == VirtualKey::VK_RETURN || vk == VirtualKey::VK_KP_ENTER) {
      if (s_settingsSel == 0) {
        runWifiSetup();
        setMenuMsg("Back to settings");
        redrawSettingsHub();
      } else if (s_settingsSel == 1) {
        runDisplaySetup();
        setMenuMsg("Back to settings");
        redrawSettingsHub();
      } else {
        runColorSetup();
        setMenuMsg("Back to settings");
        redrawSettingsHub();
      }
    }
  }
}

static void settingsTask(void * /*arg*/)
{
  ottoEnableSerialToTerm(false);
  saveOttoScreen();
  runSettings();
  leaveUiToOtto();
  ottoEnableSerialToTerm(true);
  if (s_menuKeyQueue)
    xQueueReset(s_menuKeyQueue);
  Terminal.keyboard()->emptyVirtualKeyQueue();
  s_uiBusy = false;
  vTaskDelete(nullptr);
}

static void startSettings()
{
  if (s_uiBusy)
    return;
  if (!ensureMenuKeyQueue())
    return;
  xQueueReset(s_menuKeyQueue);
  s_uiBusy = true;
  ottoTermPendClear();
  drawStatusBar(true);
  BaseType_t const ok = xTaskCreatePinnedToCore(
    settingsTask, "otto_settings", OTTO_WIFI_MENU_STACK, nullptr, 5, nullptr, 0);
  if (ok != pdPASS) {
    s_uiBusy = false;
  }
}


// --- F1 Help ----------------------------------------------------------------

static void helpWriteLine(int row, char const * text)
{
  int const C = termCols();
  moveAbs(row, 1);
  colorUi();
  writePadded(text ? text : "", C);
}

static void drawHelpPage()
{
  int const C = termCols();

  Terminal.write("\e[r");
  wrapOff();
  Terminal.enableCursor(false);
  fillUiPageBackground();

  moveAbs(1, 1); colorUiTitle();
  writePadded(" OttoTerminal - Help ", C);

  char line[96];
  int row = 3;

  helpWriteLine(row++, " About");
  snprintf(line, sizeof(line), "   %s v%s", OTTO_APP_NAME, OTTO_APP_VERSION);
  helpWriteLine(row++, line);
  snprintf(line, sizeof(line), "   %s by %s", OTTO_PROJECT_NAME, OTTO_PROJECT_AUTHOR);
  helpWriteLine(row++, line);
  snprintf(line, sizeof(line), "   GitHub          %s", OTTO_PROJECT_REPO);
  helpWriteLine(row++, line);
  helpWriteLine(row++, "");

  helpWriteLine(row++, " Keys");
  helpWriteLine(row++, "   F1              This help page");
  helpWriteLine(row++, "   F10             Apps Repository + XMODEM upload to Otto");
  helpWriteLine(row++, "   F11             Settings: WiFi, display size, UI colors");
  helpWriteLine(row++, "   Esc             Close any overlay (help, upload, settings)");
  helpWriteLine(row++, "");

  helpWriteLine(row++, " Console");
  snprintf(line, sizeof(line), "   Text mode       %dx%d (VGA 640x480, font sets rows)",
           termCols(), termRows());
  helpWriteLine(row++, line);
  helpWriteLine(row++, "   Body            Otto serial (bright white on black)");
  helpWriteLine(row++, "   Footer          UI chrome on last row (colors in F11)");
  helpWriteLine(row++, "");

  helpWriteLine(row++, " UART to Otto (ACIA #1, level shifter required)");
  snprintf(line, sizeof(line), "   ESP32 TX=GPIO%d  RX=GPIO%d  %d 8N1  UART%d",
           OTTO_UART_TX, OTTO_UART_RX, 115200, OTTO_UART_NUM);
  helpWriteLine(row++, line);
  helpWriteLine(row++, "   Otto TX (pin 2) -> shifter -> ESP32 RX");
  helpWriteLine(row++, "   ESP32 TX        -> shifter -> Otto RX (pin 3)");
  helpWriteLine(row++, "");

  helpWriteLine(row++, " WiFi / display / colors (F11) / upload (F10)");
  helpWriteLine(row++, "   Credentials     NVS (F11 WiFi); optional seed otto_secrets.h");
  helpWriteLine(row++, "   Display         Font height sets rows; columns always 80");
  helpWriteLine(row++, "   UI colors       Footer bar and F1/F10/F11 pages (F11)");
  helpWriteLine(row++, "   Catalog         HTTPS catalog.json + per-kernel app folders");
  helpWriteLine(row++, "   Kernel target   Tab or [ ] cycle; A auto-detect from Otto serial");
  helpWriteLine(row++, "   Upload (F10)    1) On Otto: u + Enter (XMODEM receive)");
  helpWriteLine(row++, "                   2) F10, pick app, Enter to send");
  helpWriteLine(row++, "                   u020000 on Otto for apps outside 0x8400");
  helpWriteLine(row++, "   Apps menu       Up/Dn  Enter upload  Tab target  A auto  R refresh");
  helpWriteLine(row++, "");

  snprintf(line, sizeof(line), " Memory           DRAM %u KB free   DMA %u KB free",
           (unsigned)(heap_caps_get_free_size(MALLOC_CAP_INTERNAL) / 1024),
           (unsigned)(heap_caps_get_free_size(MALLOC_CAP_DMA) / 1024));
  helpWriteLine(row++, line);

  wrapOn();
}

static void redrawHelpPage()
{
  drawHelpPage();
  setUiFooterHints("Reference", "ESC to exit");
  drawTerminalFooter(false);
}

static void runHelpPage()
{
  ottoEnableSerialToTerm(false);
  saveOttoScreen();
  clearScreenBlack();
  waitTerminalInputDrained();
  redrawHelpPage();
  waitTerminalInputDrained();

  for (;;) {
    VirtualKeyItem item{};
    if (!recvUiKey(&item, 50))
      continue;
    VirtualKey const vk = item.vk;
    if (vk == VirtualKey::VK_ESCAPE)
      break;
  }

  leaveUiToOtto();

  ottoEnableSerialToTerm(true);
  if (s_menuKeyQueue)
    xQueueReset(s_menuKeyQueue);
  Terminal.keyboard()->emptyVirtualKeyQueue();
}

static void helpTask(void * /*arg*/)
{
  runHelpPage();
  s_uiBusy = false;
  vTaskDelete(nullptr);
}

static void startHelpPage()
{
  if (s_uiBusy)
    return;
  if (!ensureMenuKeyQueue())
    return;
  xQueueReset(s_menuKeyQueue);
  s_uiBusy = true;
  ottoTermPendClear();
  drawStatusBar(true);
  BaseType_t const ok = xTaskCreatePinnedToCore(
    helpTask, "otto_help", 4096, nullptr, 5, nullptr, 0);
  if (ok != pdPASS) {
    s_uiBusy = false;
  }
}

void setup()
{
  // FabGL + WiFi/TLS on this board: WDT disabled to avoid spurious resets during
  // long HTTPS downloads (re-enable only after profiling stack/heap headroom).
  disableCore0WDT();
  delay(100);
  disableCore1WDT();

#if OTTO_USB_MIRROR
  ottoUsbMirrorInit();
#endif

  Terminal.keyboardReaderTaskStackSize = 4096;

  PS2Controller.begin(PS2Preset::KeyboardPort0);

  ottoSettingsInit();

  DisplayController.begin();
  DisplayController.setFont(ottoSettingsFont());  // before setResolution
  DisplayController.setResolution();

  Terminal.begin(&DisplayController);
  Terminal.connectLocally();  // needed for TerminalController::getCursorPos replies
  SerialPortTerminalConnector.connect(&SerialPort, &Terminal);

  SerialPort.setSignals(OTTO_UART_RX, OTTO_UART_TX, OTTO_UART_RTS, OTTO_UART_CTS);
  SerialPort.setup(OTTO_UART_NUM, 115200, 8, 'N', 1.0, fabgl::FlowControl::None);
  ottoInstallSerialBridge();  // after setup: filtered RX + muted FabGL TX replies


  Terminal.keyboard()->setLayout(&fabgl::ItalianLayout);
  Terminal.setTerminalType(TermType::ANSILegacy);
  Terminal.setBackgroundColor(Color::Black);
  Terminal.setForegroundColor(Color::BrightWhite);
  Terminal.enableCursor(true);

  // Quiet boot: blank console + footer; Otto paints when it starts.
  clearScreenBlack();
  setupScrollingForFooter();
  waitTerminalInputDrained();
  moveAbs(1, 1);
  colorOtto();
  drawStatusBar(true);
  waitTerminalInputDrained();

  ottoWifiInit();
  if (ottoWifiHasCredentials()) {
    ottoWifiStartBackground();
    drawStatusBar(true);
  }

  Terminal.onVirtualKeyItem = [&](VirtualKeyItem * vkItem) {
    if (s_uiBusy) {
      if (vkItem->down && vkItem->vk != VirtualKey::VK_NONE && s_menuKeyQueue)
        xQueueSend(s_menuKeyQueue, vkItem, pdMS_TO_TICKS(5));
      vkItem->vk    = VirtualKey::VK_NONE;
      vkItem->ASCII = 0;  // else FabGL still sends the key to Otto via onSend
      return;
    }
    if (vkItem->CTRL || vkItem->LALT || vkItem->RALT || !vkItem->down)
      return;
    if (vkItem->vk == VirtualKey::VK_F1) {
      vkItem->vk = VirtualKey::VK_NONE;
      startHelpPage();
    } else if (vkItem->vk == VirtualKey::VK_F10) {
      vkItem->vk = VirtualKey::VK_NONE;
      startWifiMenu();
    } else if (vkItem->vk == VirtualKey::VK_F11) {
      vkItem->vk = VirtualKey::VK_NONE;
      startSettings();
    }
  };
}

void loop()
{
  static uint32_t last = 0;
  uint32_t const now = millis();
#if OTTO_USB_MIRROR
  ottoUsbMirrorPump();
#endif
  // Drain Otto→Terminal promptly; spin briefly while the soft queue is hot.
  for (int i = 0; i < 8; ++i) {
    size_t const before = ottoTermPendCount();
    ottoTermPendDrain(false);
    if (ottoTermPendCount() == 0 || ottoTermPendCount() == before)
      break;
  }
  // getCursorPos briefly gates Terminal painting (s_serialToTerm=false) but UART
  // keeps draining into the soft pending queue.
  if (!s_uiBusy && (now - last > 3000)) {
    last = now;
    drawStatusBar(true);
  }
  vTaskDelay((ottoTermPendCount() > 0 ? 1 : 20) / portTICK_PERIOD_MS);
}
