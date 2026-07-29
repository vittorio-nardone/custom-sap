#include "otto_settings.h"

#include <Preferences.h>
#include <stdio.h>
#include <string.h>

namespace {

Preferences s_prefs;
OttoFontPreset s_font = OttoFontPreset::H8;
uint8_t        s_ftBg = 4;   // blue — legacy footer/menus
uint8_t        s_ftFg = 14;  // bright cyan
uint8_t        s_pgBg = 4;
uint8_t        s_pgFg = 14;

constexpr char const * kNs    = "otto_term";
constexpr char const * kFont  = "font";
constexpr char const * kUiBg  = "uibg";   // legacy (migrated)
constexpr char const * kUiFg  = "uifg";
constexpr char const * kFtBg  = "ftbg";
constexpr char const * kFtFg  = "ftfg";
constexpr char const * kPgBg  = "pgbg";
constexpr char const * kPgFg  = "pgfg";

OttoFontPresetInfo const kPresets[] = {
  { OttoFontPreset::H8,  "Compact   8x8  -> 80x60 rows",  &fabgl::FONT_8x8,  60 },
  { OttoFontPreset::H9,  "Small     8x9  -> 80x53 rows",  &fabgl::FONT_8x9,  53 },
  { OttoFontPreset::H13, "Medium    8x13 -> 80x36 rows",  &fabgl::FONT_8x13, 36 },
  { OttoFontPreset::H14, "Standard  8x14 -> 80x34 rows",  &fabgl::FONT_8x14, 34 },
  { OttoFontPreset::H16, "Large     8x16 -> 80x30 rows",  &fabgl::FONT_8x16, 30 },
  { OttoFontPreset::H19, "Largest   8x19 -> 80x25 rows",  &fabgl::FONT_8x19, 25 },
};

char const * const kColorNames[] = {
  "Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White",
  "Bright Black", "Bright Red", "Bright Green", "Bright Yellow",
  "Bright Blue", "Bright Magenta", "Bright Cyan", "Bright White",
};

bool validPreset(uint8_t v) {
  return v < (uint8_t)OttoFontPreset::Count;
}

void writeSgr(fabgl::Terminal & term, uint8_t bg, uint8_t fg) {
  if (bg > 7)
    bg = 7;
  if (fg > 15)
    fg = 15;
  if (fg < 8)
    term.printf("\e[%d;%dm", 40 + bg, 30 + fg);
  else
    term.printf("\e[%d;%dm", 40 + bg, 90 + (fg - 8));
}

uint8_t loadColorU8(char const * key, uint8_t fallback, uint8_t maxVal) {
  uint8_t const v = (uint8_t)s_prefs.getUChar(key, fallback);
  return v <= maxVal ? v : fallback;
}

} // namespace

void ottoSettingsInit() {
  s_font = OttoFontPreset::H8;
  s_ftBg = 4;
  s_ftFg = 14;
  s_pgBg = 4;
  s_pgFg = 14;
  if (s_prefs.begin(kNs, true)) {
    uint8_t const v = (uint8_t)s_prefs.getUChar(kFont, (uint8_t)OttoFontPreset::H8);
    if (validPreset(v))
      s_font = (OttoFontPreset)v;

    uint8_t const legacyBg = loadColorU8(kUiBg, 4, 7);
    uint8_t const legacyFg = loadColorU8(kUiFg, 14, 15);
    bool const hasFooter = s_prefs.isKey(kFtBg);
    bool const hasPage   = s_prefs.isKey(kPgBg);

    if (hasFooter) {
      s_ftBg = loadColorU8(kFtBg, legacyBg, 7);
      s_ftFg = loadColorU8(kFtFg, legacyFg, 15);
    } else {
      s_ftBg = legacyBg;
      s_ftFg = legacyFg;
    }

    if (hasPage) {
      s_pgBg = loadColorU8(kPgBg, legacyBg, 7);
      s_pgFg = loadColorU8(kPgFg, legacyFg, 15);
    } else {
      s_pgBg = legacyBg;
      s_pgFg = legacyFg;
    }

    s_prefs.end();
  }
}

OttoFontPreset ottoSettingsFontPreset() {
  return s_font;
}

bool ottoSettingsSetFontPreset(OttoFontPreset p) {
  if (!validPreset((uint8_t)p))
    return false;
  s_font = p;
  if (!s_prefs.begin(kNs, false))
    return false;
  s_prefs.putUChar(kFont, (uint8_t)p);
  s_prefs.end();
  return true;
}

fabgl::FontInfo const * ottoSettingsFont() {
  return ottoSettingsPresetInfo((int)s_font).font;
}

int ottoSettingsPresetCount() {
  return (int)OttoFontPreset::Count;
}

OttoFontPresetInfo const & ottoSettingsPresetInfo(int index) {
  if (index < 0 || index >= (int)OttoFontPreset::Count)
    index = (int)OttoFontPreset::H14;
  return kPresets[index];
}

void ottoSettingsFormatSize(OttoFontPreset p, char * out, size_t outLen) {
  if (!out || outLen == 0)
    return;
  OttoFontPresetInfo const & info = ottoSettingsPresetInfo((int)p);
  snprintf(out, outLen, "80x%d", info.rows);
}

uint8_t ottoSettingsFooterBg() { return s_ftBg; }
uint8_t ottoSettingsFooterFg() { return s_ftFg; }

bool ottoSettingsSetFooterColors(uint8_t bg, uint8_t fg) {
  if (bg > 7 || fg > 15)
    return false;
  s_ftBg = bg;
  s_ftFg = fg;
  if (!s_prefs.begin(kNs, false))
    return false;
  s_prefs.putUChar(kFtBg, bg);
  s_prefs.putUChar(kFtFg, fg);
  s_prefs.end();
  return true;
}

uint8_t ottoSettingsPageBg() { return s_pgBg; }
uint8_t ottoSettingsPageFg() { return s_pgFg; }

bool ottoSettingsSetPageColors(uint8_t bg, uint8_t fg) {
  if (bg > 7 || fg > 15)
    return false;
  s_pgBg = bg;
  s_pgFg = fg;
  if (!s_prefs.begin(kNs, false))
    return false;
  s_prefs.putUChar(kPgBg, bg);
  s_prefs.putUChar(kPgFg, fg);
  s_prefs.end();
  return true;
}

char const * ottoSettingsAnsiColorName(uint8_t idx) {
  if (idx > 15)
    idx = 15;
  return kColorNames[idx];
}

void ottoSettingsWriteFooterColors(fabgl::Terminal & term) {
  writeSgr(term, s_ftBg, s_ftFg);
}

void ottoSettingsWritePageColors(fabgl::Terminal & term) {
  writeSgr(term, s_pgBg, s_pgFg);
}

void ottoSettingsWritePageMuted(fabgl::Terminal & term) {
  uint8_t fg = s_pgFg;
  if (fg >= 8)
    fg = static_cast<uint8_t>(fg - 8);
  writeSgr(term, s_pgBg, fg);
}

void ottoSettingsWritePageSelect(fabgl::Terminal & term) {
  writeSgr(term, s_pgFg < 8 ? s_pgFg : (uint8_t)(s_pgFg - 8), s_pgBg);
}
