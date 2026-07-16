/*
 * VGA32 microSD (FabGL HSPI). Disabled when OTTO_SD_ENABLED=0 in otto_config.h.
 */
#pragma once

#include <stddef.h>
#include <stdint.h>

#define VGA_SD_ROOT "/SD/vga"

#define VGA_SD_NAME_MAX 24
#define VGA_SD_PATH_MAX 47

#define VGA_SD_LIST_TYPE_FILE 1
#define VGA_SD_LIST_TYPE_DIR  2

struct VgaSdListEntry {
  uint8_t type;
  uint8_t nameLen;
  char    name[VGA_SD_NAME_MAX + 1];
};

class OttoSd {
public:
  void begin(int csPin = 13);
  bool isMounted() const { return m_mounted; }
  bool isSdKnown() const { return m_sdKnown; }
  void markSdKnown() { m_sdKnown = true; }
  static bool sdSharesUartTx();
  static void setUartHooks(void (*pause)(), void (*restore)());
  bool checkSdReady();
  bool tryMount();
  bool probePresent();
  void release();

  static void setUiHold(bool hold);

  bool list(char const * relPath, uint16_t offset, VgaSdListEntry * out, int maxOut, int * outCount, bool * eof);
  bool open(char const * relPath, uint8_t * handle, uint32_t * size);
  bool read(uint8_t handle, uint32_t offset, uint8_t * buf, uint8_t len, uint8_t * outLen);
  void close(uint8_t handle);

private:
  bool ensureMounted();

  bool     m_mounted   = false;
  bool     m_sdKnown     = false;
  int      m_csPin     = 13;
  static constexpr int MAX_HANDLES = 2;

  struct OpenFile {
    bool     used;
    char     path[64];
    uint32_t size;
  };
  OpenFile m_handles[MAX_HANDLES];

  bool validatePath(char const * relPath) const;
  bool buildAbs(char const * rel, char * out, size_t outLen) const;
  int  findFreeHandle();
  static int strcasecmp_path(char const * a, char const * b);
};
