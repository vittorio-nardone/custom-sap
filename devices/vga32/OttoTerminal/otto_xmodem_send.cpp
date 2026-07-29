#include "otto_xmodem_send.h"

#include "otto_config.h"

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

namespace {

constexpr uint8_t XMODEM_SOH = 0x01;
constexpr uint8_t XMODEM_EOT = 0x04;
constexpr uint8_t XMODEM_ACK = 0x06;
constexpr uint8_t XMODEM_NAK = 0x15;
constexpr uint8_t XMODEM_CRC_START = 0x43;
constexpr size_t  XMODEM_BLOCK_SIZE = 128;

static const uint8_t CRC_LO_TABLE[256] = {
  0x00, 0x21, 0x42, 0x63, 0x84, 0xA5, 0xC6, 0xE7, 0x08, 0x29, 0x4A, 0x6B, 0x8C, 0xAD, 0xCE, 0xEF,
  0x31, 0x10, 0x73, 0x52, 0xB5, 0x94, 0xF7, 0xD6, 0x39, 0x18, 0x7B, 0x5A, 0xBD, 0x9C, 0xFF, 0xDE,
  0x62, 0x43, 0x20, 0x01, 0xE6, 0xC7, 0xA4, 0x85, 0x6A, 0x4B, 0x28, 0x09, 0xEE, 0xCF, 0xAC, 0x8D,
  0x53, 0x72, 0x11, 0x30, 0xD7, 0xF6, 0x95, 0xB4, 0x5B, 0x7A, 0x19, 0x38, 0xDF, 0xFE, 0x9D, 0xBC,
  0xC4, 0xE5, 0x86, 0xA7, 0x40, 0x61, 0x02, 0x23, 0xCC, 0xED, 0x8E, 0xAF, 0x48, 0x69, 0x0A, 0x2B,
  0xF5, 0xD4, 0xB7, 0x96, 0x71, 0x50, 0x33, 0x12, 0xFD, 0xDC, 0xBF, 0x9E, 0x79, 0x58, 0x3B, 0x1A,
  0xA6, 0x87, 0xE4, 0xC5, 0x22, 0x03, 0x60, 0x41, 0xAE, 0x8F, 0xEC, 0xCD, 0x2A, 0x0B, 0x68, 0x49,
  0x97, 0xB6, 0xD5, 0xF4, 0x13, 0x32, 0x51, 0x70, 0x9F, 0xBE, 0xDD, 0xFC, 0x1B, 0x3A, 0x59, 0x78,
  0x88, 0xA9, 0xCA, 0xEB, 0x0C, 0x2D, 0x4E, 0x6F, 0x80, 0xA1, 0xC2, 0xE3, 0x04, 0x25, 0x46, 0x67,
  0xB9, 0x98, 0xFB, 0xDA, 0x3D, 0x1C, 0x7F, 0x5E, 0xB1, 0x90, 0xF3, 0xD2, 0x35, 0x14, 0x77, 0x56,
  0xEA, 0xCB, 0xA8, 0x89, 0x6E, 0x4F, 0x2C, 0x0D, 0xE2, 0xC3, 0xA0, 0x81, 0x66, 0x47, 0x24, 0x05,
  0xDB, 0xFA, 0x99, 0xB8, 0x5F, 0x7E, 0x1D, 0x3C, 0xD3, 0xF2, 0x91, 0xB0, 0x57, 0x76, 0x15, 0x34,
  0x4C, 0x6D, 0x0E, 0x2F, 0xC8, 0xE9, 0x8A, 0xAB, 0x44, 0x65, 0x06, 0x27, 0xC0, 0xE1, 0x82, 0xA3,
  0x7D, 0x5C, 0x3F, 0x1E, 0xF9, 0xD8, 0xBB, 0x9A, 0x75, 0x54, 0x37, 0x16, 0xF1, 0xD0, 0xB3, 0x92,
  0x2E, 0x0F, 0x6C, 0x4D, 0xAA, 0x8B, 0xE8, 0xC9, 0x26, 0x07, 0x64, 0x45, 0xA2, 0x83, 0xE0, 0xC1,
  0x1F, 0x3E, 0x5D, 0x7C, 0x9B, 0xBA, 0xD9, 0xF8, 0x17, 0x36, 0x55, 0x74, 0x93, 0xB2, 0xD1, 0xF0
};

static const uint8_t CRC_HI_TABLE[256] = {
  0x00, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x81, 0x91, 0xA1, 0xB1, 0xC1, 0xD1, 0xE1, 0xF1,
  0x12, 0x02, 0x32, 0x22, 0x52, 0x42, 0x72, 0x62, 0x93, 0x83, 0xB3, 0xA3, 0xD3, 0xC3, 0xF3, 0xE3,
  0x24, 0x34, 0x04, 0x14, 0x64, 0x74, 0x44, 0x54, 0xA5, 0xB5, 0x85, 0x95, 0xE5, 0xF5, 0xC5, 0xD5,
  0x36, 0x26, 0x16, 0x06, 0x76, 0x66, 0x56, 0x46, 0xB7, 0xA7, 0x97, 0x87, 0xF7, 0xE7, 0xD7, 0xC7,
  0x48, 0x58, 0x68, 0x78, 0x08, 0x18, 0x28, 0x38, 0xC9, 0xD9, 0xE9, 0xF9, 0x89, 0x99, 0xA9, 0xB9,
  0x5A, 0x4A, 0x7A, 0x6A, 0x1A, 0x0A, 0x3A, 0x2A, 0xDB, 0xCB, 0xFB, 0xEB, 0x9B, 0x8B, 0xBB, 0xAB,
  0x6C, 0x7C, 0x4C, 0x5C, 0x2C, 0x3C, 0x0C, 0x1C, 0xED, 0xFD, 0xCD, 0xDD, 0xAD, 0xBD, 0x8D, 0x9D,
  0x7E, 0x6E, 0x5E, 0x4E, 0x3E, 0x2E, 0x1E, 0x0E, 0xFF, 0xEF, 0xDF, 0xCF, 0xBF, 0xAF, 0x9F, 0x8F,
  0x91, 0x81, 0xB1, 0xA1, 0xD1, 0xC1, 0xF1, 0xE1, 0x10, 0x00, 0x30, 0x20, 0x50, 0x40, 0x70, 0x60,
  0x83, 0x93, 0xA3, 0xB3, 0xC3, 0xD3, 0xE3, 0xF3, 0x02, 0x12, 0x22, 0x32, 0x42, 0x52, 0x62, 0x72,
  0xB5, 0xA5, 0x95, 0x85, 0xF5, 0xE5, 0xD5, 0xC5, 0x34, 0x24, 0x14, 0x04, 0x74, 0x64, 0x54, 0x44,
  0xA7, 0xB7, 0x87, 0x97, 0xE7, 0xF7, 0xC7, 0xD7, 0x26, 0x36, 0x06, 0x16, 0x66, 0x76, 0x46, 0x56,
  0xD9, 0xC9, 0xF9, 0xE9, 0x99, 0x89, 0xB9, 0xA9, 0x58, 0x48, 0x78, 0x68, 0x18, 0x08, 0x38, 0x28,
  0xCB, 0xDB, 0xEB, 0xFB, 0x8B, 0x9B, 0xAB, 0xBB, 0x4A, 0x5A, 0x6A, 0x7A, 0x0A, 0x1A, 0x2A, 0x3A,
  0xFD, 0xED, 0xDD, 0xCD, 0xBD, 0xAD, 0x9D, 0x8D, 0x7C, 0x6C, 0x5C, 0x4C, 0x3C, 0x2C, 0x1C, 0x0C,
  0xEF, 0xFF, 0xCF, 0xDF, 0xAF, 0xBF, 0x8F, 0x9F, 0x6E, 0x7E, 0x4E, 0x5E, 0x2E, 0x3E, 0x0E, 0x1E
};

bool xferAborted(OttoXmodemStatus const * st) {
  return st && st->shouldAbort && st->shouldAbort(st->ctx);
}

void statusMsg(OttoXmodemStatus const * st, char const * msg) {
  if (st && st->onStatus)
    st->onStatus(st->ctx, msg);
}

void dbgMsg(OttoXmodemStatus const * st, char const * fmt, ...) {
#if OTTO_XFER_DEBUG
  if (!st || !st->onDbg || !fmt)
    return;
  char buf[80];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  st->onDbg(st->ctx, buf);
#else
  (void)st;
  (void)fmt;
#endif
}

static char const * respName(uint8_t b) {
  switch (b) {
    case 0x06: return "ACK";
    case 0x15: return "NAK";
    case 0x43: return "C";
    case 0x1B: return "ESC";
    default: return "?";
  }
}

void crcUpdate(uint8_t byte, uint8_t & crcLo, uint8_t & crcHi) {
  uint8_t const idx = byte ^ crcHi;
  crcHi = crcLo ^ CRC_HI_TABLE[idx];
  crcLo = CRC_LO_TABLE[idx];
}

uint16_t blockCrc(uint8_t const * data, size_t len) {
  uint8_t crcLo = 0;
  uint8_t crcHi = 0;
  for (size_t i = 0; i < len; ++i)
    crcUpdate(data[i], crcLo, crcHi);
  return (static_cast<uint16_t>(crcHi) << 8) | crcLo;
}

bool readResponse(OttoUartRaw & uart, uint8_t * out, uint32_t timeoutMs, OttoXmodemStatus const * st,
                  uint8_t blockNo, uint8_t attempt) {
  TickType_t const t0 = xTaskGetTickCount();
  unsigned skippedC = 0;
  while ((xTaskGetTickCount() - t0) < pdMS_TO_TICKS(timeoutMs)) {
    if (xferAborted(st)) {
      statusMsg(st, "Upload cancelled");
      return false;
    }
    uart.pumpRx();
    uint8_t b = 0;
    if (!uart.readByte(&b, 25))
      continue;
    if (b == XMODEM_CRC_START) {
      ++skippedC;
      continue;
    }
    dbgMsg(st, "b%u a%u %s 0x%02X ring=%u", (unsigned)blockNo, (unsigned)attempt,
           respName(b), (unsigned)b, (unsigned)uart.rxPendingCount());
    if (skippedC)
      dbgMsg(st, "  skipped %u x C", skippedC);
    *out = b;
    return true;
  }
  dbgMsg(st, "b%u a%u ACK timeout ring=%u", (unsigned)blockNo, (unsigned)attempt,
         (unsigned)uart.rxPendingCount());
  return false;
}

bool waitForC(OttoUartRaw & uart, OttoXmodemStatus const * st, bool ottoAlreadyReceiving)
{
  statusMsg(st, "Waiting for XMODEM 'C' (ESC=cancel)...");
  TickType_t const t0 = xTaskGetTickCount();
  int  byteCount = 0;
  bool prevEol   = false;
  bool sawBanner = false;
  char const * needle = "XMODEM";
  int needlePos = 0;
  uint8_t lastByte = 0;
  char dbg[48];

  while ((xTaskGetTickCount() - t0) < pdMS_TO_TICKS(45000)) {
    if (xferAborted(st))
      return false;

    uint32_t const elapsedMs = (uint32_t)(xTaskGetTickCount() - t0) * portTICK_PERIOD_MS;

    uint8_t b = 0;
    if (!uart.readByte(&b, 100)) {
      if (byteCount == 0 && elapsedMs >= 3000 && (elapsedMs % 3000) < 350) {
        statusMsg(st, "No RX - u+Enter on Otto, ESC=cancel");
        dbgMsg(st, "wait C: rx=0 ring=%u t=%lus",
               (unsigned)uart.rxPendingCount(), (unsigned long)(elapsedMs / 1000));
      }
      continue;
    }

    byteCount++;
    lastByte = b;

    if (b == 0x1B) {
      statusMsg(st, "Otto aborted (ESC)");
      dbgMsg(st, "RX ESC during wait-C");
      return false;
    }

    if (!sawBanner) {
      if (b == (uint8_t)needle[needlePos]) {
        if (++needlePos == 6) {
          sawBanner = true;
          statusMsg(st, "Banner OK - waiting for 'C'...");
          dbgMsg(st, "banner OK, rx=%d", byteCount);
        }
      } else {
        needlePos = (b == (uint8_t)needle[0]) ? 1 : 0;
      }
    }

    if (b == XMODEM_CRC_START) {
      dbgMsg(st, "sync C ok rx=%d ban=%d ring=%u", byteCount, sawBanner ? 1 : 0,
             (unsigned)uart.rxPendingCount());
      // Variant A: Otto already in receive mode — ring may hold only 'C' after WiFi DL
      // (banner scrolled out of the 1 KB RX buffer). Trust sync when user armed Otto.
      if (sawBanner || prevEol || ottoAlreadyReceiving)
        return true;
    } else if (byteCount <= 12 || (byteCount % 16) == 0) {
      dbgMsg(st, "wait: 0x%02X '%c' rx=%d", (unsigned)b,
             (b >= 0x20 && b < 0x7F) ? (char)b : '.', byteCount);
    }

    prevEol = (b == 0x0A || b == 0x0D);
  }

  snprintf(dbg, sizeof(dbg), "Timeout (rx=%d, ban=%d)", byteCount, sawBanner ? 1 : 0);
  statusMsg(st, dbg);
  dbgMsg(st, "last=0x%02X ring=%u", (unsigned)lastByte, (unsigned)uart.rxPendingCount());
  return false;
}

bool sendBlock(OttoUartRaw & uart, uint8_t blockNo, uint8_t const * data, size_t dataLen,
               uint8_t retries, OttoXmodemStatus const * st) {
  uint8_t block[XMODEM_BLOCK_SIZE];
  memset(block, 0x1A, sizeof(block));
  if (dataLen > XMODEM_BLOCK_SIZE)
    dataLen = XMODEM_BLOCK_SIZE;
  memcpy(block, data, dataLen);

  uint16_t const crc = blockCrc(block, XMODEM_BLOCK_SIZE);

  for (uint8_t attempt = 0; attempt <= retries; ++attempt) {
    if (xferAborted(st))
      return false;

    uart.drainSyncCs();
    uart.writeByte(XMODEM_SOH);
    uart.writeByte(blockNo);
    uart.writeByte(static_cast<uint8_t>(~blockNo));
    uart.writeBytes(block, XMODEM_BLOCK_SIZE);
    uart.writeByte(static_cast<uint8_t>((crc >> 8) & 0xFF));
    uart.writeByte(static_cast<uint8_t>(crc & 0xFF));
    vTaskDelay(pdMS_TO_TICKS(5));

    uint8_t resp = 0;
    if (!readResponse(uart, &resp, 15000, st, blockNo, attempt)) {
      if (xferAborted(st))
        return false;
      statusMsg(st, "Timeout waiting for ACK/NAK");
      continue;
    }
    if (resp == XMODEM_ACK) {
      dbgMsg(st, "b%u ACK ok", (unsigned)blockNo);
      return true;
    }
    if (resp == XMODEM_NAK) {
      dbgMsg(st, "b%u NAK retry %u", (unsigned)blockNo, (unsigned)(attempt + 1));
      continue;
    }
    if (resp == 0x1B)
      return false;
    dbgMsg(st, "b%u bad resp 0x%02X", (unsigned)blockNo, (unsigned)resp);
  }
  dbgMsg(st, "b%u NAK limit", (unsigned)blockNo);
  statusMsg(st, "Too many NAKs on block");
  return false;
}

} // namespace

char const * ottoXmodemResultStr(OttoXmodemResult r) {
  switch (r) {
    case OttoXmodemResult::Ok: return "OK";
    case OttoXmodemResult::UartError: return "UART error";
    case OttoXmodemResult::Timeout: return "Timeout";
    case OttoXmodemResult::NakExceeded: return "NAK limit";
    case OttoXmodemResult::Aborted: return "Cancelled";
    default: return "?";
  }
}

OttoXmodemResult ottoXmodemSend(
  OttoUartRaw & uart,
  uint8_t const * data,
  size_t len,
  OttoXmodemOptions const & opts,
  OttoXmodemStatus const * status)
{
  if (!uart.active() || !data || len == 0)
    return OttoXmodemResult::UartError;

  bool const ottoInReceive = true;  // caller or kernel `u` already armed XMODEM receive
  bool transferStarted = false;
  auto fail = [&](OttoXmodemResult r) -> OttoXmodemResult {
    if (xferAborted(status))
      r = OttoXmodemResult::Aborted;
    if (ottoInReceive) {
      statusMsg(status, "Aborting Otto XMODEM...");
      uart.abortOttoReceiver();
    }
    return r;
  };

  if (opts.sendUploadCommand)
    uart.flushRx();

  if (opts.sendUploadCommand) {
    statusMsg(status, "Sending u+CR to Otto...");
    uart.flushRx();
    uart.writeByte('u');
    vTaskDelay(pdMS_TO_TICKS(30));
    uart.writeByte('\r');
    vTaskDelay(pdMS_TO_TICKS(80));
  } else {
    statusMsg(status, "Waiting for Otto XMODEM 'C'...");
  }

  if (!waitForC(uart, status, !opts.sendUploadCommand))
    return fail(xferAborted(status) ? OttoXmodemResult::Aborted : OttoXmodemResult::Timeout);

  uart.drainSyncCs();
  dbgMsg(status, "pre-send ring=%u", (unsigned)uart.rxPendingCount());
  vTaskDelay(pdMS_TO_TICKS(30));
  transferStarted = true;

  size_t const blockCount = (len + XMODEM_BLOCK_SIZE - 1) / XMODEM_BLOCK_SIZE;
  char blkMsg[40];
  snprintf(blkMsg, sizeof(blkMsg), "XMODEM %u block(s)...", (unsigned)blockCount);
  statusMsg(status, blkMsg);

  for (size_t i = 0; i < blockCount; ++i) {
    if (xferAborted(status))
      return fail(OttoXmodemResult::Aborted);

    uint8_t blockNo = static_cast<uint8_t>((i + 1) & 0xFF);
    size_t const offset = i * XMODEM_BLOCK_SIZE;
    size_t const chunk  = (len - offset > XMODEM_BLOCK_SIZE) ? XMODEM_BLOCK_SIZE : (len - offset);
    if (!sendBlock(uart, blockNo, data + offset, chunk, opts.maxRetries, status))
      return fail(xferAborted(status) ? OttoXmodemResult::Aborted : OttoXmodemResult::NakExceeded);
    if ((i & 3) == 0) {
      char prog[40];
      snprintf(prog, sizeof(prog), "Block %u / %u", (unsigned)(i + 1), (unsigned)blockCount);
      statusMsg(status, prog);
      dbgMsg(status, "ok thru blk %u/%u", (unsigned)(i + 1), (unsigned)blockCount);
    }
    vTaskDelay(pdMS_TO_TICKS(25));
  }

  statusMsg(status, "Sending EOT...");
  for (int attempt = 0; attempt < 5; ++attempt) {
    if (xferAborted(status))
      return fail(OttoXmodemResult::Aborted);
    uart.drainSyncCs();
    uart.writeByte(XMODEM_EOT);
    uint8_t resp = 0;
    if (readResponse(uart, &resp, 8000, status, 0, (uint8_t)attempt) && resp == XMODEM_ACK)
      break;
    if (xferAborted(status))
      return fail(OttoXmodemResult::Aborted);
    if (attempt == 4)
      return fail(OttoXmodemResult::Timeout);
  }

  statusMsg(status, "Upload complete");
  return OttoXmodemResult::Ok;
}
