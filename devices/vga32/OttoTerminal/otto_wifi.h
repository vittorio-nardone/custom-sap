/*
 * WiFi + HTTPS helpers for Otto app catalog (GitHub Contents API + raw .bin).
 * Credentials: NVS (Preferences); optional seed from otto_secrets.h.
 */
#pragma once

#include <stddef.h>
#include <stdint.h>

#include "otto_config.h"

static constexpr int OTTO_WIFI_MAX_APPS   = 24;
static constexpr int OTTO_WIFI_MAX_TARGETS = 8;
static constexpr int OTTO_WIFI_NAME_MAX  = 32;
static constexpr int OTTO_WIFI_URL_MAX   = 192;
static constexpr int OTTO_WIFI_SSID_MAX  = 33;   // 32 + NUL
static constexpr int OTTO_WIFI_PASS_MAX  = 65;   // 64 + NUL
static constexpr int OTTO_WIFI_MAX_SCAN  = 24;
static constexpr int OTTO_WIFI_TARGET_ID_MAX = 16;
static constexpr int OTTO_WIFI_KERNEL_VER_MAX = 16;
static constexpr int OTTO_WIFI_LABEL_MAX = 24;
static constexpr int OTTO_WIFI_PATH_MAX = 64;

struct OttoWifiApp {
  char name[OTTO_WIFI_NAME_MAX];
  char url[OTTO_WIFI_URL_MAX];
};

struct OttoWifiCatalog {
  int         count;
  OttoWifiApp apps[OTTO_WIFI_MAX_APPS];
};

struct OttoWifiTarget {
  char id[OTTO_WIFI_TARGET_ID_MAX];
  char kernel_version[OTTO_WIFI_KERNEL_VER_MAX];
  char label[OTTO_WIFI_LABEL_MAX];
  char catalog_path[OTTO_WIFI_PATH_MAX];
};

struct OttoWifiTargetList {
  int           count;
  char          default_target_id[OTTO_WIFI_TARGET_ID_MAX];
  OttoWifiTarget targets[OTTO_WIFI_MAX_TARGETS];
};

struct OttoWifiNetwork {
  char ssid[OTTO_WIFI_SSID_MAX];
  int8_t rssi;
  bool open;   // true if no password required
};

struct OttoWifiNetworkList {
  int count;
  OttoWifiNetwork nets[OTTO_WIFI_MAX_SCAN];
};

enum class OttoWifiResult : uint8_t {
  Ok = 0,
  ConnectFailed,
  HttpFailed,
  TooLarge,
  ParseFailed,
  NoMemory,
  BadConfig,     // no SSID in NVS / secrets
  SsidNotFound,
  ScanFailed,
  Aborted,
};

/** Result of a WiFi scan (optionally checking one SSID). */
struct OttoWifiScanReport {
  int  networkCount;
  bool targetFound;
  int  targetRssi;
  char detail[96];
};

typedef bool (*OttoWifiAbortFn)(void * ctx);

char const * ottoWifiResultStr(OttoWifiResult r);

/** Load NVS (and seed from otto_secrets.h if NVS empty). Call once at boot. */
void ottoWifiInit();

/** True when a non-empty SSID is configured (NVS or seeded secrets). */
bool ottoWifiHasCredentials();

/** Current configured SSID (empty string if none). Never null. */
char const * ottoWifiSsid();

/** Save SSID/password to NVS and update runtime credentials. */
bool ottoWifiSaveCredentials(char const * ssid, char const * password);

/** Clear NVS credentials (and runtime). */
bool ottoWifiClearCredentials();

/** Disconnect STA (keeps radio in STA mode). */
void ottoWifiDisconnect();

/**
 * Scan 2.4 GHz networks into out (SSID/RSSI/open). Dedupes by SSID (keeps strongest).
 */
OttoWifiResult ottoWifiScanList(OttoWifiNetworkList * out);

/**
 * Scan and optionally check one SSID (summary only; does not keep AP list).
 */
OttoWifiResult ottoWifiScanReport(char const * targetSsid, OttoWifiScanReport * out);

void ottoWifiGetLastDetail(char * out, size_t outLen);

OttoWifiResult ottoWifiConnect(uint32_t timeoutMs = 20000);

/** Kick off WiFi.begin() without waiting (call once at boot after ottoWifiInit). */
void ottoWifiStartBackground();

bool ottoWifiIsConnected();

/** Reduce RF activity before timing-sensitive UART (XMODEM). */
void ottoWifiPauseForUart();

/** Copy url into out, appending ?t=millis to defeat CDN / HTTP caches at download time. */
void ottoWifiCacheBustUrl(char const * url, char * out, size_t outLen);

OttoWifiResult ottoWifiDownload(char const * url, uint8_t ** outData, size_t * outLen,
                                void (*onProgress)(void * ctx, size_t got, size_t total) = nullptr,
                                void * progressCtx = nullptr,
                                void (*onStatus)(void * ctx, char const * msg) = nullptr,
                                void * statusCtx = nullptr,
                                OttoWifiAbortFn shouldAbort = nullptr,
                                void * abortCtx = nullptr);

void ottoWifiFree(void * p);

/** Last F10 kernel target id (NVS), e.g. "v1.2.101" or "current". */
void ottoWifiGetLastAppTarget(char * out, size_t outLen);
void ottoWifiSetLastAppTarget(char const * targetId);

OttoWifiResult ottoWifiFetchTargets(OttoWifiTargetList * out);

/** Fetch app catalog from GitHub Contents API path (e.g. roms/apps/v1.2.101/asm). */
OttoWifiResult ottoWifiFetchCatalogPath(char const * catalogPath, OttoWifiCatalog * out);

/** Legacy: fetch default roms/apps/current/asm catalog. */
OttoWifiResult ottoWifiFetchCatalog(OttoWifiCatalog * out);
