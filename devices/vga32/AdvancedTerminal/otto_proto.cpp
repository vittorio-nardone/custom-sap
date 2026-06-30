#include "otto_proto.h"
#include "otto_sd.h"
#include <cstdio>
#include <cstring>

uint8_t OttoProto::checksum(uint8_t const * data, int len) {
  uint16_t s = 0;
  for (int i = 0; i < len; ++i)
    s += data[i];
  return (uint8_t)s;
}

void OttoProto::sendFrame(uint8_t stat, uint8_t const * payload, uint16_t len) {
  if (!m_tx)
    return;
  uint8_t body[4 + OTIO_FRAME_MAX];
  body[0] = OTIO_VER;
  body[1] = stat;
  body[2] = (uint8_t)(len & 0xFF);
  body[3] = (uint8_t)(len >> 8);
  if (len && payload)
    memcpy(body + 4, payload, len);

  m_tx(OTIO_SYNC);
  m_tx(OTIO_MAGIC_O);
  m_tx(OTIO_MAGIC_T);
  for (int i = 0; i < 4; ++i)
    m_tx(body[i]);
  for (uint16_t i = 0; i < len; ++i)
    m_tx(payload[i]);
  m_tx(checksum(body, 4 + len));
  m_tx(OTIO_ETX);
}

void OttoProto::sendDataChunk(uint8_t handle, uint8_t seq, uint8_t const * data, uint8_t len) {
  if (!m_tx)
    return;
  m_tx(OTIO_SYNC);
  m_tx(OTIO_MAGIC_O);
  m_tx('D');
  m_tx(handle);
  m_tx(seq);
  m_tx(len);
  uint16_t s = handle + seq + len;
  for (uint8_t i = 0; i < len; ++i) {
    m_tx(data[i]);
    s += data[i];
  }
  m_tx((uint8_t)s);
  m_tx(OTIO_ETX);
}

void OttoProto::sendErr(uint8_t code) {
  sendFrame(OTIO_STAT_ERR, &code, 1);
}

void OttoProto::begin(OttoSd * sd, uint8_t fwMaj, uint8_t fwMin) {
  m_sd       = sd;
  m_fwMaj    = fwMaj;
  m_fwMin    = fwMin;
  m_rxLen    = 0;
  m_rxNeed   = 0;
  m_rxActive = false;
  m_frameDone  = false;
  m_frameEnded = false;
}

bool OttoProto::takeFrameDone() {
  if (!m_frameDone)
    return false;
  m_frameDone = false;
  return true;
}

bool OttoProto::takeFrameEnded() {
  if (!m_frameEnded)
    return false;
  m_frameEnded = false;
  return true;
}

void OttoProto::setTx(void (*fn)(uint8_t)) {
  m_tx = fn;
}

void OttoProto::setStatusLine(void (*fn)(char const *)) {
  m_status = fn;
}

void OttoProto::setUartRestore(void (*fn)()) {
  m_uartRestore = fn;
}

void OttoProto::endSdSession(bool releaseSd) {
  if (releaseSd && m_sd)
    m_sd->release();
  // PICO-D4 shares SD MISO with UART TX (GPIO 2); WROVER uses GPIO 35 — no UART restore.
  if (releaseSd && m_uartRestore && m_sd && OttoSd::sdSharesUartTx())
    m_uartRestore();
}

void OttoProto::replyFrame(uint8_t stat, uint8_t const * payload, uint16_t len, bool releaseSd) {
  endSdSession(releaseSd);
  sendFrame(stat, payload, len);
}

void OttoProto::replyErr(uint8_t code, bool releaseSd) {
  endSdSession(releaseSd);
  sendErr(code);
}

bool OttoProto::feed(uint8_t byte) {
  if (!m_rxActive) {
    if (byte != OTIO_SYNC)
      return false;
    m_rxActive = true;
    m_rxLen    = 0;
    m_rxNeed   = 0;
  }

  if (m_rxLen < OTIO_FRAME_MAX)
    m_rxBuf[m_rxLen++] = byte;

  if (m_rxLen >= 4 && m_rxNeed == 0) {
    if (m_rxBuf[1] != OTIO_MAGIC_O) {
      m_rxActive = false;
      m_rxLen    = 0;
      return byte == OTIO_SYNC;
    }
    if (m_rxBuf[2] == 'T' && m_rxLen >= 7) {
      uint16_t plen = m_rxBuf[5] | ((uint16_t)m_rxBuf[6] << 8);
      m_rxNeed = 7 + plen + 2;
    } else if (m_rxBuf[2] == 'D' && m_rxLen >= 6) {
      m_rxNeed = 6 + m_rxBuf[5] + 2;
    }
    if (m_rxNeed > OTIO_FRAME_MAX)
      m_rxNeed = OTIO_FRAME_MAX;
  }

  if (m_rxNeed > 0 && (int)m_rxLen >= m_rxNeed) {
    m_frameEnded = true;
    if (m_rxBuf[2] == 'T') {
      uint16_t plen = m_rxBuf[5] | ((uint16_t)m_rxBuf[6] << 8);
      uint8_t chk = checksum(m_rxBuf + 3, 4 + plen);
      if (chk == m_rxBuf[7 + plen] && m_rxBuf[8 + plen] == OTIO_ETX) {
        handleFrame();
        m_frameDone = true;
      }
    }
    m_rxActive = false;
    m_rxLen    = 0;
    m_rxNeed   = 0;
    return true;
  }

  if (m_rxLen >= OTIO_FRAME_MAX) {
    m_rxActive = false;
    m_rxLen    = 0;
    m_rxNeed   = 0;
  }
  return true;
}

void OttoProto::handleFrame() {
  if (m_rxBuf[3] != OTIO_VER)
    return;
  uint16_t plen = m_rxBuf[5] | ((uint16_t)m_rxBuf[6] << 8);
  handleFramePayload(m_rxBuf[4], m_rxBuf + 7, plen);
}

void OttoProto::handleFramePayload(uint8_t cmd, uint8_t const * payload, uint16_t len) {
  switch (cmd) {
    case OTIO_CMD_PING:   cmdPing(); break;
    case OTIO_CMD_LIST:   cmdList(payload, len); break;
    case OTIO_CMD_FOPEN:  cmdFopen(payload, len); break;
    case OTIO_CMD_FREAD:  cmdFread(payload, len); break;
    case OTIO_CMD_FCLOSE: cmdFclose(payload, len); break;
    default: sendErr(OTIO_ERR_PATH_INVALID); break;
  }
}

void OttoProto::cmdPing() {
  uint8_t caps = OTIO_CAP_FOLDERS;
  if (m_sd) {
    if (m_sd->isSdKnown())
      caps |= OTIO_CAP_SD;
    else if (!OttoSd::sdSharesUartTx() && m_sd->checkSdReady())
      caps |= OTIO_CAP_SD;
  }
  uint8_t p[4] = { OTIO_VER, m_fwMaj, m_fwMin, caps };
  sendFrame(OTIO_STAT_OK, p, 4);
}

void OttoProto::cmdList(uint8_t const * payload, uint16_t len) {
  if (!m_sd || !m_sd->tryMount()) {
    if (m_status)
      m_status("SD: mount failed");
    replyErr(OTIO_ERR_SD_ABSENT, false);
    return;
  }
  if (len < 3) {
    replyErr(OTIO_ERR_PATH_INVALID, true);
    return;
  }
  char path[OTIO_PATH_MAX + 1];
  memset(path, 0, sizeof(path));
  size_t pe = 0;
  while (pe < len && payload[pe] != 0 && pe < OTIO_PATH_MAX)
    path[pe] = (char)payload[pe++];
  path[pe] = 0;
  if (pe + 3 > len) {
    replyErr(OTIO_ERR_PATH_INVALID, true);
    return;
  }
  uint16_t offset = payload[pe + 1] | ((uint16_t)payload[pe + 2] << 8);

  OttoListEntry entries[OTIO_LIST_PAGE];
  int count = 0;
  bool eof = false;
  if (!m_sd->list(path, offset, entries, OTIO_LIST_PAGE, &count, &eof)) {
    if (m_status) {
      char msg[80];
      if (path[0])
        snprintf(msg, sizeof(msg), "SD: list failed: %s/%s", OTIO_SD_ROOT, path);
      else
        snprintf(msg, sizeof(msg), "SD: list failed: %s", OTIO_SD_ROOT);
      m_status(msg);
    }
    replyErr(OTIO_ERR_NOT_FOUND, true);
    return;
  }

  uint8_t out[OTIO_LIST_PAGE * OTIO_ENTRY_SIZE];
  int o = 0;
  for (int e = 0; e < count; ++e) {
    out[o++] = entries[e].type;
    out[o++] = entries[e].nameLen;
    memset(out + o, 0, OTIO_NAME_MAX);
    memcpy(out + o, entries[e].name, entries[e].nameLen);
    o += OTIO_NAME_MAX;
  }
  replyFrame(eof ? OTIO_STAT_EOF : OTIO_STAT_OK, out, o, true);
}

void OttoProto::cmdFopen(uint8_t const * payload, uint16_t len) {
  if (!m_sd || !m_sd->tryMount()) {
    replyErr(OTIO_ERR_SD_ABSENT, false);
    return;
  }
  char path[OTIO_PATH_MAX + 1];
  size_t i = 0;
  while (i < len && payload[i] != 0 && i < OTIO_PATH_MAX)
    path[i] = (char)payload[i++];
  path[i] = 0;

  uint8_t handle = 0;
  uint32_t size = 0;
  if (!m_sd->open(path, &handle, &size)) {
    replyErr(OTIO_ERR_NOT_FOUND, true);
    return;
  }
  if (m_status) {
    char msg[48];
    snprintf(msg, sizeof(msg), "SD: loading %s...", path);
    m_status(msg);
  }
  uint8_t p[5];
  p[0] = handle;
  p[1] = (uint8_t)(size & 0xFF);
  p[2] = (uint8_t)((size >> 8) & 0xFF);
  p[3] = (uint8_t)((size >> 16) & 0xFF);
  p[4] = (uint8_t)((size >> 24) & 0xFF);
  replyFrame(OTIO_STAT_OK, p, 5, true);
}

void OttoProto::cmdFread(uint8_t const * payload, uint16_t len) {
  if (!m_sd || len < 5) {
    replyErr(OTIO_ERR_PATH_INVALID, false);
    return;
  }
  uint8_t handle = payload[0];
  uint32_t offset = payload[1] | ((uint32_t)payload[2] << 8) |
                    ((uint32_t)payload[3] << 16) | ((uint32_t)payload[4] << 24);
  uint8_t buf[OTIO_CHUNK_SIZE];
  uint8_t outLen = 0;
  static uint8_t seq = 0;

  if (!m_sd->tryMount()) {
    replyErr(OTIO_ERR_SD_ABSENT, false);
    return;
  }
  if (!m_sd->read(handle, offset, buf, OTIO_CHUNK_SIZE, &outLen)) {
    m_sd->close(handle);
    if (m_status)
      m_status("SD: load error");
    replyErr(OTIO_ERR_SD_IO, true);
    return;
  }
  endSdSession(true);
  if (outLen == 0) {
    sendFrame(OTIO_STAT_EOF, nullptr, 0);
    return;
  }
  sendDataChunk(handle, seq++, buf, outLen);
}

void OttoProto::cmdFclose(uint8_t const * payload, uint16_t len) {
  if (m_sd && len >= 1)
    m_sd->close(payload[0]);
  replyFrame(OTIO_STAT_OK, nullptr, 0, true);
}
