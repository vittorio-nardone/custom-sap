#include "otto_wifi.h"

#include <HTTPClient.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_heap_caps.h>
#include <new>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace {

Preferences s_prefs;
char s_ssid[OTTO_WIFI_SSID_MAX] = "";
char s_pass[OTTO_WIFI_PASS_MAX] = "";
char s_lastDetail[96] = "";

constexpr char const * kNvsNs   = "otto_wifi";
constexpr char const * kNvsSsid = "ssid";
constexpr char const * kNvsPass = "pass";
constexpr char const * kNvsAppTarget = "app_tgt";

void setLastDetail(char const * fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(s_lastDetail, sizeof(s_lastDetail), fmt, ap);
  va_end(ap);
}

bool secretsLookConfigured() {
  return OTTO_WIFI_SSID[0] != '\0' && strcmp(OTTO_WIFI_SSID, "YOUR_SSID") != 0;
}

void copyCred(char * dst, size_t dstLen, char const * src) {
  if (!dst || dstLen == 0)
    return;
  if (!src) {
    dst[0] = '\0';
    return;
  }
  strncpy(dst, src, dstLen - 1);
  dst[dstLen - 1] = '\0';
}

size_t freeInternalHeap() {
  return heap_caps_get_free_size(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
}

size_t freeDmaHeap() {
  return heap_caps_get_free_size(MALLOC_CAP_DMA);
}

void * allocDownloadBuf(size_t n) {
  void * p = heap_caps_malloc(n, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  if (!p)
    p = malloc(n);
  return p;
}

void * reallocDownloadBuf(void * p, size_t n) {
  void * np = heap_caps_realloc(p, n, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  if (!np)
    np = realloc(p, n);
  return np;
}

void freeDownloadBuf(void * p) {
  heap_caps_free(p);
}

bool prepareWifiRadio() {
  // Avoid WiFi.mode(WIFI_OFF): full radio teardown freezes the PS/2 mouse on VGA32.
  WiFi.persistent(false);
  if (WiFi.getMode() != WIFI_STA)
    WiFi.mode(WIFI_STA);
  WiFi.setSleep(true);
  return true;
}

bool endsWithBin(char const * name) {
  size_t const len = strlen(name);
  return len > 4 && strcmp(name + len - 4, ".bin") == 0;
}

void copyDisplayName(char const * filename, char * out, size_t outLen) {
  strncpy(out, filename, outLen - 1);
  out[outLen - 1] = '\0';
  char * dot = strrchr(out, '.');
  if (dot)
    *dot = '\0';
}

bool urlIsHttps(char const * url) {
  return url && strncmp(url, "https://", 8) == 0;
}

char const * findJsonStringValue(char const * from, char const * key, char const * * valueEnd) {
  char pattern[48];
  snprintf(pattern, sizeof(pattern), "\"%s\"", key);
  char const * k = strstr(from, pattern);
  if (!k)
    return nullptr;
  char const * p = k + strlen(pattern);
  while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')
    p++;
  if (*p != ':')
    return nullptr;
  p++;
  while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')
    p++;
  if (*p != '"')
    return nullptr;
  p++;
  char const * end = p;
  while (*end && *end != '"') {
    if (*end == '\\' && end[1])
      end += 2;
    else
      end++;
  }
  if (*end != '"')
    return nullptr;
  if (valueEnd)
    *valueEnd = end;
  return p;
}

bool copyJsonString(char const * start, char const * end, char * out, size_t outLen) {
  if (!start || !end || end < start || outLen == 0)
    return false;
  size_t n = (size_t)(end - start);
  if (n >= outLen)
    n = outLen - 1;
  memcpy(out, start, n);
  out[n] = '\0';
  return true;
}

bool appendUrlQueryParam(char * url, size_t urlLen, char const * key, char const * value) {
  if (!url || !key || !value || urlLen == 0)
    return false;
  size_t const n = strlen(url);
  if (n >= urlLen - 1)
    return false;
  char const sep = strchr(url, '?') ? '&' : '?';
  int const wrote = snprintf(url + n, urlLen - n, "%c%s=%s", sep, key, value);
  return wrote > 0 && (size_t)n + (size_t)wrote < urlLen;
}

void buildGithubContentsUrl(char const * catalogPath, char * out, size_t outLen) {
  if (!catalogPath || !out || outLen == 0)
    return;
  snprintf(out, outLen,
           "https://api.github.com/repos/%s/contents/%s?ref=%s",
           OTTO_GITHUB_REPO_SLUG, catalogPath, OTTO_GITHUB_REF);
}

bool parseGithubCatalogJson(char * text, OttoWifiCatalog * out) {
  if (!text || !out)
    return false;
  out->count = 0;

  char * cursor = text;
  while (out->count < OTTO_WIFI_MAX_APPS) {
    char const * nameEnd = nullptr;
    char const * nameVal = findJsonStringValue(cursor, "name", &nameEnd);
    if (!nameVal)
      break;

    char name[OTTO_WIFI_NAME_MAX + 8];
    if (!copyJsonString(nameVal, nameEnd, name, sizeof(name))) {
      cursor = const_cast<char *>(nameEnd + 1);
      continue;
    }

    char const * nextName = strstr(nameEnd + 1, "\"name\"");
    char * saved = nullptr;
    char savedCh = 0;
    if (nextName) {
      saved = const_cast<char *>(nextName);
      savedCh = *saved;
      *saved = '\0';
    }

    char const * urlEnd = nullptr;
    char const * urlVal = findJsonStringValue(nameVal, "download_url", &urlEnd);
    char const * shaEnd = nullptr;
    char const * shaVal = findJsonStringValue(nameVal, "sha", &shaEnd);
    if (saved)
      *saved = savedCh;

    if (endsWithBin(name) && name[0] != '_' && urlVal) {
      OttoWifiApp & app = out->apps[out->count];
      copyDisplayName(name, app.name, sizeof(app.name));
      if (copyJsonString(urlVal, urlEnd, app.url, sizeof(app.url))) {
        char sha[41];
        if (shaVal && shaEnd > shaVal && copyJsonString(shaVal, shaEnd, sha, sizeof(sha)))
          appendUrlQueryParam(app.url, sizeof(app.url), "sha", sha);
        out->count++;
      }
    }

    cursor = const_cast<char *>(nameEnd + 1);
  }

  return out->count > 0;
}

bool parseTargetObject(char const * objStart, char const * objEnd, OttoWifiTarget * target) {
  if (!objStart || !objEnd || !target || objEnd <= objStart)
    return false;

  char const * end = nullptr;
  char const * v = findJsonStringValue(objStart, "id", &end);
  if (!v || end > objEnd)
    return false;
  if (!copyJsonString(v, end, target->id, sizeof(target->id)))
    return false;

  v = findJsonStringValue(objStart, "kernel_version", &end);
  if (!v || end > objEnd || !copyJsonString(v, end, target->kernel_version, sizeof(target->kernel_version)))
    return false;

  v = findJsonStringValue(objStart, "label", &end);
  if (!v || end > objEnd || !copyJsonString(v, end, target->label, sizeof(target->label)))
    strncpy(target->label, target->kernel_version, sizeof(target->label) - 1);

  v = findJsonStringValue(objStart, "catalog_path", &end);
  if (!v || end > objEnd || !copyJsonString(v, end, target->catalog_path, sizeof(target->catalog_path)))
    return false;

  return target->id[0] != '\0' && target->catalog_path[0] != '\0';
}

bool parseCatalogIndexJson(char * text, OttoWifiTargetList * out) {
  if (!text || !out)
    return false;
  out->count = 0;
  out->default_target_id[0] = '\0';

  char const * defEnd = nullptr;
  char const * defVal = findJsonStringValue(text, "default_target", &defEnd);
  if (defVal)
    copyJsonString(defVal, defEnd, out->default_target_id, sizeof(out->default_target_id));

  char const * targetsKey = strstr(text, "\"targets\"");
  if (!targetsKey)
    return false;
  char const * arr = strchr(targetsKey, '[');
  if (!arr)
    return false;

  char const * p = arr + 1;
  while (out->count < OTTO_WIFI_MAX_TARGETS && p && *p) {
    char const * objStart = strchr(p, '{');
    if (!objStart)
      break;
    char const * objEnd = strchr(objStart, '}');
    if (!objEnd)
      break;
    OttoWifiTarget & t = out->targets[out->count];
    if (parseTargetObject(objStart, objEnd, &t))
      out->count++;
    p = objEnd + 1;
  }

  return out->count > 0;
}

int wifiScanRaw() {
  prepareWifiRadio();
  WiFi.setSleep(false);
  if (WiFi.status() != WL_CONNECTED)
    WiFi.disconnect(false);
  delay(50);

  int n = WIFI_SCAN_FAILED;
  for (int attempt = 0; attempt < 3 && n == WIFI_SCAN_FAILED; ++attempt) {
    if (attempt > 0)
      delay(300);
    n = WiFi.scanNetworks(/*async=*/false, /*show_hidden=*/false);
  }
  return n;
}

} // namespace

bool ottoWifiSaveCredentials(char const * ssid, char const * password);
bool ottoWifiClearCredentials();

void ottoWifiFree(void * p) {
  freeDownloadBuf(p);
}

char const * ottoWifiResultStr(OttoWifiResult r) {
  switch (r) {
    case OttoWifiResult::Ok: return "OK";
    case OttoWifiResult::ConnectFailed: return "WiFi failed";
    case OttoWifiResult::HttpFailed: return "HTTP failed";
    case OttoWifiResult::TooLarge: return "File too large";
    case OttoWifiResult::ParseFailed: return "Bad catalog";
    case OttoWifiResult::NoMemory: return "Out of memory";
    case OttoWifiResult::BadConfig: return "WiFi not configured";
    case OttoWifiResult::SsidNotFound: return "SSID not found";
    case OttoWifiResult::ScanFailed: return "WiFi scan failed";
    case OttoWifiResult::Aborted: return "Cancelled";
    default: return "?";
  }
}

void ottoWifiGetLastDetail(char * out, size_t outLen) {
  if (!out || outLen == 0)
    return;
  strncpy(out, s_lastDetail, outLen - 1);
  out[outLen - 1] = '\0';
}

void ottoWifiGetLastAppTarget(char * out, size_t outLen) {
  if (!out || outLen == 0)
    return;
  out[0] = '\0';
  if (!s_prefs.begin(kNvsNs, true))
    return;
  String const v = s_prefs.getString(kNvsAppTarget, "");
  s_prefs.end();
  if (v.length() > 0)
    strncpy(out, v.c_str(), outLen - 1);
  out[outLen - 1] = '\0';
}

void ottoWifiSetLastAppTarget(char const * targetId) {
  if (!targetId || !targetId[0])
    return;
  if (!s_prefs.begin(kNvsNs, false))
    return;
  s_prefs.putString(kNvsAppTarget, targetId);
  s_prefs.end();
}

void ottoWifiInit() {
  s_ssid[0] = '\0';
  s_pass[0] = '\0';

  if (s_prefs.begin(kNvsNs, true)) {
    if (s_prefs.isKey(kNvsSsid)) {
      String ss = s_prefs.getString(kNvsSsid, "");
      String pw = s_prefs.getString(kNvsPass, "");
      copyCred(s_ssid, sizeof(s_ssid), ss.c_str());
      copyCred(s_pass, sizeof(s_pass), pw.c_str());
    }
    s_prefs.end();
  }

  if (s_ssid[0] == '\0' && secretsLookConfigured())
    ottoWifiSaveCredentials(OTTO_WIFI_SSID, OTTO_WIFI_PASSWORD);
}

bool ottoWifiHasCredentials() {
  return s_ssid[0] != '\0';
}

char const * ottoWifiSsid() {
  return s_ssid;
}

bool ottoWifiSaveCredentials(char const * ssid, char const * password) {
  if (!ssid || !ssid[0])
    return false;
  copyCred(s_ssid, sizeof(s_ssid), ssid);
  copyCred(s_pass, sizeof(s_pass), password ? password : "");

  if (!s_prefs.begin(kNvsNs, false))
    return false;
  s_prefs.putString(kNvsSsid, s_ssid);
  s_prefs.putString(kNvsPass, s_pass);
  s_prefs.end();
  return true;
}

bool ottoWifiClearCredentials() {
  s_ssid[0] = '\0';
  s_pass[0] = '\0';
  if (!s_prefs.begin(kNvsNs, false))
    return false;
  s_prefs.clear();
  s_prefs.end();
  return true;
}

void ottoWifiDisconnect() {
  if (WiFi.getMode() == WIFI_OFF)
    return;
  WiFi.disconnect(false);
}

void ottoWifiStartBackground() {
  if (!ottoWifiHasCredentials())
    return;
  if (WiFi.status() == WL_CONNECTED)
    return;
  prepareWifiRadio();
  WiFi.begin(s_ssid, s_pass);
}

OttoWifiResult ottoWifiScanList(OttoWifiNetworkList * out) {
  if (!out)
    return OttoWifiResult::ScanFailed;
  out->count = 0;
  s_lastDetail[0] = '\0';

  int n = wifiScanRaw();
  if (n == WIFI_SCAN_FAILED) {
    setLastDetail("radio fail DRAM=%u DMA=%u",
                  (unsigned)freeInternalHeap(), (unsigned)freeDmaHeap());
    WiFi.setSleep(true);
    return OttoWifiResult::ScanFailed;
  }

  for (int i = 0; i < n; ++i) {
    String ss = WiFi.SSID(i);
    if (ss.length() == 0)
      continue;
    int8_t const rssi = (int8_t)WiFi.RSSI(i);
    bool const open = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN);

    int found = -1;
    for (int j = 0; j < out->count; ++j) {
      if (strcmp(out->nets[j].ssid, ss.c_str()) == 0) {
        found = j;
        break;
      }
    }
    if (found >= 0) {
      if (rssi > out->nets[found].rssi) {
        out->nets[found].rssi = rssi;
        out->nets[found].open = open;
      }
      continue;
    }
    if (out->count >= OTTO_WIFI_MAX_SCAN)
      continue;
    OttoWifiNetwork & net = out->nets[out->count++];
    copyCred(net.ssid, sizeof(net.ssid), ss.c_str());
    net.rssi = rssi;
    net.open = open;
  }

  for (int i = 0; i + 1 < out->count; ++i) {
    for (int j = i + 1; j < out->count; ++j) {
      if (out->nets[j].rssi > out->nets[i].rssi) {
        OttoWifiNetwork tmp = out->nets[i];
        out->nets[i] = out->nets[j];
        out->nets[j] = tmp;
      }
    }
  }

  setLastDetail("%d AP(s) DRAM=%u", out->count, (unsigned)freeInternalHeap());
  WiFi.scanDelete();
  WiFi.setSleep(true);
  return OttoWifiResult::Ok;
}

OttoWifiResult ottoWifiScanReport(char const * targetSsid, OttoWifiScanReport * out) {
  if (!out)
    return OttoWifiResult::ScanFailed;

  out->networkCount = 0;
  out->targetFound  = false;
  out->targetRssi   = 0;
  out->detail[0]    = '\0';
  s_lastDetail[0]   = '\0';

  OttoWifiNetworkList list{};
  OttoWifiResult const r = ottoWifiScanList(&list);
  if (r != OttoWifiResult::Ok) {
    strncpy(out->detail, s_lastDetail, sizeof(out->detail) - 1);
    return r;
  }

  out->networkCount = list.count;
  if (targetSsid && targetSsid[0]) {
    for (int i = 0; i < list.count; ++i) {
      if (strcmp(list.nets[i].ssid, targetSsid) == 0) {
        out->targetFound = true;
        out->targetRssi  = list.nets[i].rssi;
        break;
      }
    }
  }

  unsigned const dram = (unsigned)freeInternalHeap();
  if (list.count == 0) {
    setLastDetail("0 APs DRAM=%u", dram);
  } else if (targetSsid && targetSsid[0]) {
    if (out->targetFound)
      setLastDetail("%d APs '%s' %ddBm DRAM=%u", list.count, targetSsid, out->targetRssi, dram);
    else
      setLastDetail("%d APs '%s' missing DRAM=%u", list.count, targetSsid, dram);
  } else {
    setLastDetail("%d APs DRAM=%u", list.count, dram);
  }

  strncpy(out->detail, s_lastDetail, sizeof(out->detail) - 1);
  out->detail[sizeof(out->detail) - 1] = '\0';
  return OttoWifiResult::Ok;
}

bool ottoWifiIsConnected() {
  return WiFi.status() == WL_CONNECTED;
}

void ottoWifiPauseForUart() {
  WiFi.setSleep(true);
  delay(50);
}

OttoWifiResult ottoWifiConnect(uint32_t timeoutMs) {
  s_lastDetail[0] = '\0';

  if (!ottoWifiHasCredentials()) {
    setLastDetail("F11: configure WiFi");
    return OttoWifiResult::BadConfig;
  }

  if (WiFi.status() == WL_CONNECTED) {
    setLastDetail("%s DRAM=%u", WiFi.localIP().toString().c_str(), (unsigned)freeInternalHeap());
    return OttoWifiResult::Ok;
  }

  prepareWifiRadio();
  WiFi.setSleep(false);
  WiFi.begin(s_ssid, s_pass);

  uint32_t const start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    wl_status_t const st = WiFi.status();
    if (st == WL_CONNECT_FAILED) {
      setLastDetail("auth failed - check password");
      return OttoWifiResult::ConnectFailed;
    }
    if (st == WL_NO_SSID_AVAIL) {
      setLastDetail("'%s' not in range (2.4GHz?)", s_ssid);
      return OttoWifiResult::ConnectFailed;
    }
    if ((millis() - start) >= timeoutMs) {
      setLastDetail("timeout DRAM=%u", (unsigned)freeInternalHeap());
      return OttoWifiResult::ConnectFailed;
    }
    delay(200);
  }

  WiFi.setSleep(true);
  setLastDetail("%s %ddBm DRAM=%u",
                WiFi.localIP().toString().c_str(), WiFi.RSSI(), (unsigned)freeInternalHeap());
  return OttoWifiResult::Ok;
}

OttoWifiResult ottoWifiDownload(char const * url, uint8_t ** outData, size_t * outLen,
                                void (*onProgress)(void *, size_t, size_t), void * progressCtx,
                                void (*onStatus)(void *, char const *), void * statusCtx,
                                OttoWifiAbortFn shouldAbort, void * abortCtx) {
  if (!url || !outData || !outLen)
    return OttoWifiResult::HttpFailed;
  *outData = nullptr;
  *outLen  = 0;

  auto status = [&](char const * msg) {
    if (onStatus)
      onStatus(statusCtx, msg);
  };

  if (ottoWifiConnect() != OttoWifiResult::Ok)
    return OttoWifiResult::ConnectFailed;

  WiFi.setSleep(false);
  delay(50);  // let radio wake fully before TLS

  bool const https = urlIsHttps(url);
  status(https ? "TLS setup..." : "HTTP setup...");

  // Heap-allocate TLS client - large stack object + HTTPClient can hang/OOM quietly.
  WiFiClientSecure * secure = nullptr;
  WiFiClient * plain = nullptr;
  HTTPClient http;
  http.setReuse(false);
  http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
  http.setTimeout(12000);
  http.setUserAgent("Otto-VGA32-Terminal");

  bool began = false;
  if (https) {
    secure = new (std::nothrow) WiFiClientSecure();
    if (!secure) {
      setLastDetail("OOM TLS client DRAM=%u", (unsigned)freeInternalHeap());
      WiFi.setSleep(true);
      return OttoWifiResult::NoMemory;
    }
    secure->setInsecure();
    secure->setHandshakeTimeout(20);
    secure->setTimeout(12000);
    status("http.begin (HTTPS)...");
    began = http.begin(*secure, url);
  } else {
    plain = new (std::nothrow) WiFiClient();
    if (!plain) {
      setLastDetail("OOM HTTP client DRAM=%u", (unsigned)freeInternalHeap());
      WiFi.setSleep(true);
      return OttoWifiResult::NoMemory;
    }
    status("http.begin (HTTP)...");
    began = http.begin(*plain, url);
  }

  if (!began) {
    setLastDetail("http.begin fail DRAM=%u", (unsigned)freeInternalHeap());
    http.end();
    delete secure;
    delete plain;
    WiFi.setSleep(true);
    return OttoWifiResult::HttpFailed;
  }

  char getMsg[48];
  snprintf(getMsg, sizeof(getMsg), "GET DRAM=%u...", (unsigned)freeInternalHeap());
  status(getMsg);

  int const code = http.GET();
  {
    char codeMsg[40];
    snprintf(codeMsg, sizeof(codeMsg), "HTTP %d", code);
    status(codeMsg);
  }

  if (code != HTTP_CODE_OK) {
    setLastDetail("HTTP %d DRAM=%u", code, (unsigned)freeInternalHeap());
    http.end();
    delete secure;
    delete plain;
    WiFi.setSleep(true);
    return OttoWifiResult::HttpFailed;
  }

  int const cl = http.getSize();
  if (cl > (int)OTTO_WIFI_MAX_DOWNLOAD) {
    http.end();
    delete secure;
    delete plain;
    WiFi.setSleep(true);
    return OttoWifiResult::TooLarge;
  }

  size_t capacity = (cl > 0) ? (size_t)cl : 4096;
  if (capacity > OTTO_WIFI_MAX_DOWNLOAD)
    capacity = OTTO_WIFI_MAX_DOWNLOAD;

  uint8_t * buf = static_cast<uint8_t *>(allocDownloadBuf(capacity));
  if (!buf) {
    setLastDetail("OOM need %u DRAM=%u", (unsigned)capacity, (unsigned)freeInternalHeap());
    http.end();
    delete secure;
    delete plain;
    WiFi.setSleep(true);
    return OttoWifiResult::NoMemory;
  }

  status("Reading body...");
  WiFiClient * stream = http.getStreamPtr();
  size_t got = 0;
  uint32_t lastDataMs = millis();
  uint32_t const startMs = millis();
  while (http.connected() || (stream && stream->available())) {
    if (shouldAbort && shouldAbort(abortCtx)) {
      freeDownloadBuf(buf);
      http.end();
      delete secure;
      delete plain;
      setLastDetail("cancelled");
      WiFi.setSleep(true);
      return OttoWifiResult::Aborted;
    }
    if ((millis() - startMs) > 45000) {
      freeDownloadBuf(buf);
      http.end();
      delete secure;
      delete plain;
      setLastDetail("read timeout total DRAM=%u", (unsigned)freeInternalHeap());
      WiFi.setSleep(true);
      return OttoWifiResult::HttpFailed;
    }
    size_t avail = stream ? stream->available() : 0;
    if (!avail) {
      if ((millis() - lastDataMs) > 15000) {
        freeDownloadBuf(buf);
        http.end();
        delete secure;
        delete plain;
        setLastDetail("read idle timeout got=%u", (unsigned)got);
        WiFi.setSleep(true);
        return OttoWifiResult::HttpFailed;
      }
      delay(2);
      if (!http.connected() && !(stream && stream->available()))
        break;
      continue;
    }
    lastDataMs = millis();

    if (got + avail > OTTO_WIFI_MAX_DOWNLOAD) {
      freeDownloadBuf(buf);
      http.end();
      delete secure;
      delete plain;
      WiFi.setSleep(true);
      return OttoWifiResult::TooLarge;
    }
    if (got + avail > capacity) {
      size_t next = capacity * 2;
      if (next < got + avail)
        next = got + avail;
      if (next > OTTO_WIFI_MAX_DOWNLOAD)
        next = OTTO_WIFI_MAX_DOWNLOAD;
      uint8_t * nbuf = static_cast<uint8_t *>(reallocDownloadBuf(buf, next));
      if (!nbuf) {
        freeDownloadBuf(buf);
        setLastDetail("OOM realloc DRAM=%u", (unsigned)freeInternalHeap());
        http.end();
        delete secure;
        delete plain;
        WiFi.setSleep(true);
        return OttoWifiResult::NoMemory;
      }
      buf = nbuf;
      capacity = next;
    }

    int n = stream->readBytes(buf + got, avail);
    if (n <= 0)
      break;
    got += (size_t)n;
    if (onProgress)
      onProgress(progressCtx, got, cl > 0 ? (size_t)cl : got);
  }

  http.end();
  delete secure;
  delete plain;
  WiFi.setSleep(true);

  if (got == 0) {
    freeDownloadBuf(buf);
    setLastDetail("empty body DRAM=%u", (unsigned)freeInternalHeap());
    return OttoWifiResult::HttpFailed;
  }

  *outData = buf;
  *outLen  = got;
  return OttoWifiResult::Ok;
}

OttoWifiResult ottoWifiFetchCatalogPath(char const * catalogPath, OttoWifiCatalog * out) {
  if (!out || !catalogPath || !catalogPath[0])
    return OttoWifiResult::ParseFailed;
  out->count = 0;

  char apiUrl[OTTO_WIFI_URL_MAX];
  buildGithubContentsUrl(catalogPath, apiUrl, sizeof(apiUrl));

  uint8_t * data = nullptr;
  size_t len = 0;
  OttoWifiResult const dr = ottoWifiDownload(apiUrl, &data, &len);
  if (dr != OttoWifiResult::Ok)
    return dr;

  char * text = static_cast<char *>(reallocDownloadBuf(data, len + 1));
  if (!text) {
    freeDownloadBuf(data);
    setLastDetail("OOM catalog DRAM=%u", (unsigned)freeInternalHeap());
    return OttoWifiResult::NoMemory;
  }
  text[len] = '\0';

  if (!parseGithubCatalogJson(text, out)) {
    freeDownloadBuf(text);
    setLastDetail("0 apps in %s", catalogPath);
    return OttoWifiResult::ParseFailed;
  }

  freeDownloadBuf(text);
  setLastDetail("%d apps (%s) DRAM=%u", out->count, catalogPath, (unsigned)freeInternalHeap());
  return OttoWifiResult::Ok;
}

OttoWifiResult ottoWifiFetchTargets(OttoWifiTargetList * out) {
  if (!out)
    return OttoWifiResult::ParseFailed;
  out->count = 0;
  out->default_target_id[0] = '\0';

  uint8_t * data = nullptr;
  size_t len = 0;
  char indexUrl[OTTO_WIFI_URL_MAX + 24];
  strncpy(indexUrl, OTTO_WIFI_CATALOG_INDEX_URL, sizeof(indexUrl) - 1);
  indexUrl[sizeof(indexUrl) - 1] = '\0';
  char tbuf[12];
  snprintf(tbuf, sizeof(tbuf), "%lu", (unsigned long)millis());
  appendUrlQueryParam(indexUrl, sizeof(indexUrl), "t", tbuf);
  OttoWifiResult const dr = ottoWifiDownload(indexUrl, &data, &len);
  if (dr != OttoWifiResult::Ok)
    return dr;

  char * text = static_cast<char *>(reallocDownloadBuf(data, len + 1));
  if (!text) {
    freeDownloadBuf(data);
    setLastDetail("OOM index DRAM=%u", (unsigned)freeInternalHeap());
    return OttoWifiResult::NoMemory;
  }
  text[len] = '\0';

  if (!parseCatalogIndexJson(text, out)) {
    freeDownloadBuf(text);
    setLastDetail("bad catalog.json");
    return OttoWifiResult::ParseFailed;
  }

  freeDownloadBuf(text);
  setLastDetail("%d targets DRAM=%u", out->count, (unsigned)freeInternalHeap());
  return OttoWifiResult::Ok;
}

OttoWifiResult ottoWifiFetchCatalog(OttoWifiCatalog * out) {
  return ottoWifiFetchCatalogPath("roms/apps/current/asm", out);
}
