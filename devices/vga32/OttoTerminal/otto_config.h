/*
 * OttoTerminal build options (Project Otto / VGA32).
 *
 * Settings (F11): WiFi credentials + display font (row count) in NVS.
 * Optional otto_secrets.h seeds WiFi NVS once if empty.
 * App catalog: GitHub catalog.json + per-kernel trees (roms/apps/v.../asm).
 *
 * Note: VGATextController is fixed 640x480 with 8-pixel-wide fonts => always
 * 80 columns. Row count = 480 / font_height (configurable).
 */
#pragma once

// --- Identity (shown on status bar / F1 help) ----------------------------------
#define OTTO_APP_NAME "OttoTerminal"
#if __has_include("otto_version_gen.h")
#include "otto_version_gen.h"
#else
#define OTTO_APP_VERSION_MAJ 1
#define OTTO_APP_VERSION_MIN 0
#define OTTO_APP_VERSION_PAT 0
#define OTTO_APP_VERSION     "1.0.0-dev"
#endif
#define OTTO_PROJECT_NAME    "Project Otto"
#define OTTO_PROJECT_AUTHOR  "Vittorio Nardone"
#define OTTO_PROJECT_REPO    "github.com/vittorio-nardone/custom-sap"

// --- WiFi credentials (from secrets file) ------------------------------------
#if __has_include("otto_secrets.h")
#include "otto_secrets.h"
#else
#define OTTO_WIFI_SSID     "YOUR_SSID"
#define OTTO_WIFI_PASSWORD "YOUR_PASSWORD"
#endif

// GitHub app repository (catalog index + per-kernel app folders).
#define OTTO_GITHUB_REPO_SLUG "vittorio-nardone/custom-sap"
#define OTTO_GITHUB_REF       "master"
#define OTTO_WIFI_CATALOG_INDEX_URL \
  "https://raw.githubusercontent.com/vittorio-nardone/custom-sap/master/roms/apps/catalog.json"

// Legacy single-folder API (fallback if catalog.json is unavailable).
#define OTTO_WIFI_APPS_API_URL \
  "https://api.github.com/repos/vittorio-nardone/custom-sap/contents/roms/apps/current/asm?ref=master"

// Max size of a single downloaded body (catalog JSON or .bin) - prefer PSRAM.
#define OTTO_WIFI_MAX_DOWNLOAD 65536

// Verbose upload/download lines on F10 menu (row above message). Set 0 to disable.
#ifndef OTTO_XFER_DEBUG
#define OTTO_XFER_DEBUG 0
#endif
