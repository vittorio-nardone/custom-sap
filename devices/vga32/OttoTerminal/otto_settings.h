/*
 * Non-volatile settings for OttoTerminal (display font / UI colors; WiFi in otto_wifi).
 */
#pragma once

#include "fabgl.h"

#include <stdint.h>

/** Font height presets for VGATextController (width always 8 -> 80 columns). */
enum class OttoFontPreset : uint8_t {
  H8 = 0,   // 80x60
  H9,       // 80x53
  H13,      // 80x36
  H14,      // 80x34 (FabGL default)
  H16,      // 80x30
  H19,      // 80x25
  Count
};

struct OttoFontPresetInfo {
  OttoFontPreset     id;
  char const *       label;     // short UI label
  fabgl::FontInfo const * font;
  int                rows;      // 480 / height
};

void ottoSettingsInit();

OttoFontPreset ottoSettingsFontPreset();
bool ottoSettingsSetFontPreset(OttoFontPreset p);

/** Font to pass to VGATextController::setFont before setResolution. */
fabgl::FontInfo const * ottoSettingsFont();

int ottoSettingsPresetCount();
OttoFontPresetInfo const & ottoSettingsPresetInfo(int index);

/** Human-readable size e.g. "80x60". */
void ottoSettingsFormatSize(OttoFontPreset p, char * out, size_t outLen);

/** Footer colors (idle status bar). Background 0-7, foreground 0-15. */
uint8_t ottoSettingsFooterBg();
uint8_t ottoSettingsFooterFg();
bool ottoSettingsSetFooterColors(uint8_t bg, uint8_t fg);

/** Page colors (F1 / F10 / F11 overlays). Background 0-7, foreground 0-15. */
uint8_t ottoSettingsPageBg();
uint8_t ottoSettingsPageFg();
bool ottoSettingsSetPageColors(uint8_t bg, uint8_t fg);

char const * ottoSettingsAnsiColorName(uint8_t idx);

void ottoSettingsWriteFooterColors(fabgl::Terminal & term);
void ottoSettingsWritePageColors(fabgl::Terminal & term);
/** Muted page text (standard/dim foreground on page background). */
void ottoSettingsWritePageMuted(fabgl::Terminal & term);
/** Selection / highlight (reverse video on page colors). */
void ottoSettingsWritePageSelect(fabgl::Terminal & term);
