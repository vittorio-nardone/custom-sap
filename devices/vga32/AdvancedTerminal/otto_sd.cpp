#include "otto_sd.h"
#include "otto_config.h"
#include "fabgl.h"
#include <cstring>
#include <dirent.h>
#include <driver/spi_common.h>
#include <stdio.h>
#include <sys/stat.h>

#define VGA_SD_VFS_MOUNT "/SD"

#if OTTO_SD_ENABLED

namespace {

struct PinCfg {
  int miso, mosi, clk, cs;
};

struct ListItem {
  char name[28];
  bool isDir;
};

static ListItem s_listItems[64];
static char    s_listChild[128];

static PinCfg s_workingPins = { 2, 12, 14, 13 };
static bool   s_pinsKnown   = false;

static void (*s_uartPause)()   = nullptr;
static void (*s_uartRestore)() = nullptr;
static bool   s_uiHold         = false;

PinCfg pinsForChip(int csPin) {
  if (s_pinsKnown)
    return s_workingPins;
  if (OttoSd::sdSharesUartTx())
    return { 2, 12, 14, csPin };
  return { 35, 12, 14, csPin };
}

static const PinCfg PIN_FALLBACKS[] = {
  { 2, 12, 14, 13 },
  { 35, 12, 14, 13 },
  { 16, 17, 14, 13 },
  { 16, 12, 14, 13 },
};

static int strcasecmp_path(char const * a, char const * b) {
  while (*a && *b) {
    char ca = *a;
    char cb = *b;
    if (ca >= 'A' && ca <= 'Z') ca += 32;
    if (cb >= 'A' && cb <= 'Z') cb += 32;
    if (ca != cb) return ca - cb;
    ++a; ++b;
  }
  return *a - *b;
}

} // namespace

void OttoSd::begin(int csPin) {
  m_csPin = csPin;
  for (int i = 0; i < MAX_HANDLES; ++i)
    m_handles[i].used = false;
  m_mounted  = false;
  m_sdKnown  = false;
}

bool OttoSd::sdSharesUartTx() {
  return fabgl::getChipPackage() == fabgl::ChipPackage::ESP32PICOD4;
}

void OttoSd::setUartHooks(void (*pause)(), void (*restore)()) {
  s_uartPause   = pause;
  s_uartRestore = restore;
}

bool OttoSd::ensureMounted() {
  if (m_mounted)
    return true;

  bool uartPaused = false;
  if (sdSharesUartTx() && s_uartPause) {
    s_uartPause();
    uartPaused = true;
  }

  fabgl::FileBrowser::setSDCardMaxFreqKHz(SDMMC_FREQ_PROBING);

  PinCfg tries[5];
  int n = 0;
  PinCfg primary = pinsForChip(m_csPin);
  tries[n++] = primary;
  for (auto const & fb : PIN_FALLBACKS) {
    bool dup = false;
    for (int i = 0; i < n; ++i)
      if (tries[i].miso == fb.miso && tries[i].mosi == fb.mosi)
        dup = true;
    if (!dup)
      tries[n++] = { fb.miso, fb.mosi, fb.clk, m_csPin };
  }

  for (int i = 0; i < n; ++i) {
    fabgl::FileBrowser::unmountSDCard();
    spi_bus_free(HSPI_HOST);

    if (fabgl::FileBrowser::mountSDCard(
            false, VGA_VFS_MOUNT, 4, 16 * 1024,
            tries[i].miso, tries[i].mosi, tries[i].clk, tries[i].cs)) {
      s_workingPins = tries[i];
      s_pinsKnown     = true;
      m_mounted       = true;
#if OTTO_UART_ON_HEADER
      fabgl::FileBrowser::setSDCardMaxFreqKHz(4000);
#else
      fabgl::FileBrowser::setSDCardMaxFreqKHz(10000);
#endif
      return true;
    }
  }

  fabgl::FileBrowser::setSDCardMaxFreqKHz(10000);
  if (uartPaused && s_uartRestore)
    s_uartRestore();
  return false;
}

bool OttoSd::tryMount() {
  return ensureMounted();
}

bool OttoSd::checkSdReady() {
  if (!tryMount())
    return false;
  DIR * dir = opendir(VGA_SD_ROOT);
  bool ok = (dir != nullptr);
  if (dir)
    closedir(dir);
  release();
  if (ok)
    m_sdKnown = true;
  return ok;
}

void OttoSd::setUiHold(bool hold) {
  s_uiHold = hold;
}

void OttoSd::release() {
  if (!m_mounted || s_uiHold)
    return;
  fabgl::FileBrowser::unmountSDCard();
  if (sdSharesUartTx())
    spi_bus_free(HSPI_HOST);
  m_mounted = false;
}

bool OttoSd::probePresent() {
  if (!ensureMounted())
    return false;
  DIR * dir = opendir(VGA_SD_ROOT);
  bool ok = (dir != nullptr);
  if (dir)
    closedir(dir);
  release();
  return ok;
}

int OttoSd::strcasecmp_path(char const * a, char const * b) {
  while (*a && *b) {
    char ca = *a;
    char cb = *b;
    if (ca >= 'A' && ca <= 'Z') ca += 32;
    if (cb >= 'A' && cb <= 'Z') cb += 32;
    if (ca != cb) return ca - cb;
    ++a; ++b;
  }
  return *a - *b;
}

static void sortListItems(ListItem * items, int n, int start) {
  for (int i = start; i < n - 1; ++i)
    for (int j = i + 1; j < n; ++j) {
      if (items[i].isDir != items[j].isDir) {
        if (!items[i].isDir && items[j].isDir) {
          ListItem t = items[i];
          items[i] = items[j];
          items[j] = t;
        }
      } else if (strcasecmp_path(items[i].name, items[j].name) > 0) {
        ListItem t = items[i];
        items[i] = items[j];
        items[j] = t;
      }
    }
}

bool OttoSd::validatePath(char const * relPath) const {
  if (!relPath)
    return false;
  if (strlen(relPath) > VGA_SD_PATH_MAX)
    return false;
  int depth = 0;
  int segLen = 0;
  for (char const * p = relPath; ; ++p) {
    char c = *p;
    if (c == 0 || c == '/') {
      if (segLen > VGA_SD_NAME_MAX)
        return false;
      if (segLen > 0)
        ++depth;
      segLen = 0;
      if (c == 0)
        break;
      if (depth > 4)
        return false;
      continue;
    }
    if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.'))
      return false;
    ++segLen;
  }
  return true;
}

bool OttoSd::buildAbs(char const * rel, char * out, size_t outLen) const {
  if (!validatePath(rel ? rel : ""))
    return false;
  if (strlen(VGA_SD_ROOT) + 1 + strlen(rel ? rel : "") >= outLen)
    return false;
  strcpy(out, VGA_SD_ROOT);
  if (rel && rel[0]) {
    strcat(out, "/");
    strcat(out, rel);
  }
  return true;
}

int OttoSd::findFreeHandle() {
  for (int i = 0; i < MAX_HANDLES; ++i)
    if (!m_handles[i].used)
      return i;
  return -1;
}

bool OttoSd::list(char const * relPath, uint16_t offset, VgaSdListEntry * out, int maxOut, int * outCount, bool * eof) {
  *outCount = 0;
  *eof = true;
  if (!ensureMounted())
    return false;

  char abs[96];
  if (!buildAbs(relPath ? relPath : "", abs, sizeof(abs)))
    return false;

  DIR * dir = opendir(abs);
  if (!dir)
    return false;

  int n = 0;
  bool atRoot = (relPath == nullptr || relPath[0] == 0);

  if (!atRoot && offset == 0 && n < 64) {
    strcpy(s_listItems[n].name, "..");
    s_listItems[n].isDir = true;
    ++n;
  }

  struct dirent * ent;
  while ((ent = readdir(dir)) != nullptr && n < 64) {
    if (ent->d_name[0] == '.')
      continue;
    snprintf(s_listChild, sizeof(s_listChild), "%s/%s", abs, ent->d_name);
    struct stat st;
    if (stat(s_listChild, &st) != 0)
      continue;
    strncpy(s_listItems[n].name, ent->d_name, 27);
    s_listItems[n].name[27] = 0;
    s_listItems[n].isDir = S_ISDIR(st.st_mode);
    ++n;
  }
  closedir(dir);

  if (n > 0 && strcmp(s_listItems[0].name, "..") != 0)
    sortListItems(s_listItems, n, 0);
  else if (n > 1)
    sortListItems(s_listItems, n, 1);

  int idx = (int)offset;
  if (idx >= n) {
    *eof = true;
    return true;
  }

  int added = 0;
  while (idx < n && added < maxOut) {
    out[added].type = s_listItems[idx].isDir ? VGA_SD_LIST_TYPE_DIR : VGA_SD_LIST_TYPE_FILE;
    out[added].nameLen = (uint8_t)strlen(s_listItems[idx].name);
    strncpy(out[added].name, s_listItems[idx].name, VGA_SD_NAME_MAX);
    out[added].name[VGA_SD_NAME_MAX] = 0;
    ++added;
    ++idx;
  }
  *outCount = added;
  *eof = (idx >= n);
  return true;
}

bool OttoSd::open(char const * relPath, uint8_t * handle, uint32_t * size) {
  if (!ensureMounted())
    return false;
  char abs[96];
  if (!buildAbs(relPath, abs, sizeof(abs)))
    return false;
  FILE * f = fopen(abs, "rb");
  if (!f)
    return false;
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return false;
  }
  long sz = ftell(f);
  fclose(f);
  if (sz < 0)
    return false;
  int h = findFreeHandle();
  if (h < 0)
    return false;
  m_handles[h].used = true;
  strncpy(m_handles[h].path, abs, sizeof(m_handles[h].path) - 1);
  m_handles[h].path[sizeof(m_handles[h].path) - 1] = 0;
  m_handles[h].size = (uint32_t)sz;
  *handle = (uint8_t)h;
  *size = m_handles[h].size;
  return true;
}

bool OttoSd::read(uint8_t handle, uint32_t offset, uint8_t * buf, uint8_t len, uint8_t * outLen) {
  *outLen = 0;
  if (!ensureMounted())
    return false;
  if (handle >= MAX_HANDLES || !m_handles[handle].used)
    return false;
  if (offset >= m_handles[handle].size)
    return true;
  FILE * f = fopen(m_handles[handle].path, "rb");
  if (!f)
    return false;
  if (fseek(f, (long)offset, SEEK_SET) != 0) {
    fclose(f);
    return false;
  }
  int toRead = len;
  if (offset + toRead > m_handles[handle].size)
    toRead = (int)(m_handles[handle].size - offset);
  int n = (int)fread(buf, 1, toRead, f);
  fclose(f);
  if (n < 0)
    return false;
  *outLen = (uint8_t)n;
  return true;
}

void OttoSd::close(uint8_t handle) {
  if (handle < MAX_HANDLES)
    m_handles[handle].used = false;
}

#else

void OttoSd::begin(int) {
  m_mounted  = false;
  m_sdKnown  = false;
}

bool OttoSd::sdSharesUartTx() {
  return fabgl::getChipPackage() == fabgl::ChipPackage::ESP32PICOD4;
}

void OttoSd::setUartHooks(void (*)( ), void (*)( )) {}

bool OttoSd::tryMount() { return false; }

bool OttoSd::checkSdReady() { return false; }

bool OttoSd::probePresent() { return false; }

void OttoSd::setUiHold(bool) {}

void OttoSd::release() {}

bool OttoSd::list(char const *, uint16_t, VgaSdListEntry *, int, int *, bool *) {
  return false;
}

bool OttoSd::open(char const *, uint8_t *, uint32_t *) {
  return false;
}

bool OttoSd::read(uint8_t, uint32_t, uint8_t *, uint8_t, uint8_t *) {
  return false;
}

void OttoSd::close(uint8_t) {}

#endif
