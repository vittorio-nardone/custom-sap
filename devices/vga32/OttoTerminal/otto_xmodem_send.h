/*
 * XMODEM-CRC sender for Project Otto (matches kernel/xmodem.asm receiver).
 */
#pragma once

#include <stddef.h>
#include <stdint.h>

#include "otto_uart_raw.h"

enum class OttoXmodemResult : uint8_t {
  Ok = 0,
  UartError,
  Timeout,
  NakExceeded,
  Aborted,
};

struct OttoXmodemOptions {
  /** If false, Otto must already be in XMODEM receive (kernel `u` + Enter). */
  bool sendUploadCommand = false;
  uint8_t maxRetries     = 5;
};

typedef void (*OttoXmodemStatusFn)(void * ctx, char const * msg);
typedef bool (*OttoXmodemAbortFn)(void * ctx);

struct OttoXmodemStatus {
  OttoXmodemStatusFn onStatus = nullptr;
  OttoXmodemStatusFn onDbg     = nullptr;  // optional second UI line
  OttoXmodemAbortFn  shouldAbort = nullptr;
  void *             ctx      = nullptr;
};

OttoXmodemResult ottoXmodemSend(
  OttoUartRaw & uart,
  uint8_t const * data,
  size_t len,
  OttoXmodemOptions const & opts,
  OttoXmodemStatus const * status);

char const * ottoXmodemResultStr(OttoXmodemResult r);
