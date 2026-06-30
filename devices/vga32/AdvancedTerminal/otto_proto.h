/*
 * OTIO protocol v1 — Otto Terminal I/O (Project Otto + AdvancedTerminal)
 */
#pragma once

#include <stdint.h>

#define OTIO_SYNC       0xF0
#define OTIO_ETX        0xF1
#define OTIO_MAGIC_O    'O'
#define OTIO_MAGIC_T    'T'
#define OTIO_VER        0x01

#define OTIO_STAT_OK    0x00
#define OTIO_STAT_ERR   0x01
#define OTIO_STAT_EOF   0x03
#define OTIO_STAT_NAK   0x04

#define OTIO_CMD_PING   0x01
#define OTIO_CMD_LIST   0x10
#define OTIO_CMD_FOPEN  0x20
#define OTIO_CMD_FREAD  0x21
#define OTIO_CMD_FCLOSE 0x22

#define OTIO_ERR_NOT_FOUND    0x01
#define OTIO_ERR_NOT_FILE     0x02
#define OTIO_ERR_SD_ABSENT    0x03
#define OTIO_ERR_PATH_LONG    0x04
#define OTIO_ERR_PATH_INVALID 0x05
#define OTIO_ERR_SD_IO        0x06

#define OTIO_CAP_SD      0x01
#define OTIO_CAP_FOLDERS 0x02

#define OTIO_CHUNK_SIZE  64
#define OTIO_LIST_PAGE   4
#define OTIO_ENTRY_SIZE  26
#define OTIO_PATH_MAX    47
#define OTIO_NAME_MAX    24
#define OTIO_FRAME_MAX   160

class OttoSd;

class OttoProto {
public:
  void begin(OttoSd * sd, uint8_t fwMaj, uint8_t fwMin);
  bool feed(uint8_t byte);
  bool takeFrameDone();
  bool takeFrameEnded();
  void setTx(void (*fn)(uint8_t));
  void setStatusLine(void (*fn)(char const *));
  void setUartRestore(void (*fn)());

private:
  OttoSd *  m_sd    = nullptr;
  uint8_t   m_fwMaj = 0;
  uint8_t   m_fwMin = 0;
  void (*m_tx)(uint8_t) = nullptr;
  void (*m_status)(char const *) = nullptr;
  void (*m_uartRestore)() = nullptr;

  uint8_t m_rxBuf[OTIO_FRAME_MAX];
  int     m_rxLen   = 0;
  int     m_rxNeed  = 0;
  bool    m_rxActive  = false;
  bool    m_frameDone  = false;
  bool    m_frameEnded = false;

  static uint8_t checksum(uint8_t const * data, int len);
  void sendFrame(uint8_t stat, uint8_t const * payload, uint16_t len);
  void sendDataChunk(uint8_t handle, uint8_t seq, uint8_t const * data, uint8_t len);
  void handleFrame();
  void handleFramePayload(uint8_t cmd, uint8_t const * payload, uint16_t len);
  void cmdPing();
  void cmdList(uint8_t const * payload, uint16_t len);
  void cmdFopen(uint8_t const * payload, uint16_t len);
  void cmdFread(uint8_t const * payload, uint16_t len);
  void cmdFclose(uint8_t const * payload, uint16_t len);
  void sendErr(uint8_t code);
  void endSdSession(bool releaseSd);
  void replyFrame(uint8_t stat, uint8_t const * payload, uint16_t len, bool releaseSd);
  void replyErr(uint8_t code, bool releaseSd);
};
