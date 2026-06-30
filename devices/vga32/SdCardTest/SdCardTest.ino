/*
 * SdCardTest - VGA32 SD diagnostic (no UART, no OTIO).
 *
 * FabGL FileBrowser::mountSDCard() + optional Arduino SD.h fallback.
 * Works with ESP32 core 1.0.6 and 2.x.
 *
 * Flash: ./devices/vga32/build.sh upload-sd-test
 */

#include "fabgl.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include <SD.h>
#include <SPI.h>
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdarg.h>

#if defined(ESP_IDF_VERSION_MAJOR) && (ESP_IDF_VERSION_MAJOR >= 4)
#include "esp_task_wdt.h"
#endif

fabgl::BitmappedDisplayController * DisplayController;
fabgl::PS2Controller                PS2Controller;
fabgl::Terminal                     Terminal;

static SemaphoreHandle_t s_done;

struct PinCfg {
  const char * label;
  int miso, mosi, clk, cs;
};

static const PinCfg PIN_PICO  = { "PICO   2,12,14,13",  2, 12, 14, 13 };
static const PinCfg PIN_WROVER = { "WROVER 35,12,14,13", 35, 12, 14, 13 };

static void line(char const * msg) {
  Terminal.write(msg);
  Terminal.write("\r\n");
  Terminal.flush();
}

static void linef(char const * fmt, ...) {
  char buf[160];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  line(buf);
}

static const char * chipName() {
  switch (fabgl::getChipPackage()) {
    case fabgl::ChipPackage::ESP32PICOD4:  return "ESP32-PICO-D4";
    case fabgl::ChipPackage::ESP32D0WDQ5:  return "ESP32-D0WDQ5 (WROVER)";
    case fabgl::ChipPackage::ESP32D0WDQ6:  return "ESP32-D0WDQ6 (WROOM)";
    default: return "Unknown";
  }
}

static void prepareGpioForSd(int miso, int cs) {
  gpio_reset_pin((gpio_num_t)cs);
  gpio_set_direction((gpio_num_t)cs, GPIO_MODE_OUTPUT);
  gpio_set_level((gpio_num_t)cs, 1);
  gpio_reset_pin((gpio_num_t)miso);
  gpio_set_direction((gpio_num_t)miso, GPIO_MODE_INPUT);
  gpio_set_pull_mode((gpio_num_t)miso, GPIO_PULLUP_ONLY);
  delay(20);
}

static int readMisoLevel(int miso) {
  prepareGpioForSd(miso, 13);
  return gpio_get_level((gpio_num_t)miso);
}

static bool tryFabglMount(const PinCfg & p, int freqKhz) {
  prepareGpioForSd(p.miso, p.cs);
  fabgl::FileBrowser::unmountSDCard();
  fabgl::FileBrowser::setSDCardMaxFreqKHz(freqKhz);
  return fabgl::FileBrowser::mountSDCard(
      false, "/SD", 4, 16 * 1024, p.miso, p.mosi, p.clk, p.cs);
}

static void spiRelease() {
  SPI.end();
  fabgl::FileBrowser::unmountSDCard();
}

static bool tryArduinoSd(const PinCfg & p, uint32_t hz) {
  spiRelease();
  prepareGpioForSd(p.miso, p.cs);
  SPI.begin(p.clk, p.miso, p.mosi, p.cs);
  return SD.begin(p.cs, SPI, hz);
}

static void listDir(char const * path) {
  DIR * dir = opendir(path);
  if (!dir) {
    linef("  opendir(%s) errno=%d", path, errno);
    return;
  }
  struct dirent * ent;
  while ((ent = readdir(dir)) != nullptr) {
    if (ent->d_name[0] == '.')
      continue;
    linef("    %s", ent->d_name);
  }
  closedir(dir);
}

static void runSdTest() {
  const PinCfg * primary = (fabgl::getChipPackage() == fabgl::ChipPackage::ESP32PICOD4)
      ? &PIN_PICO : &PIN_WROVER;

  line("");
  linef("MISO GPIO%d idle (CS high): %d", primary->miso, readMisoLevel(primary->miso));
  line("  (1=high/floating, 0=shorted low)");
  line("");

  line("--- FabGL FileBrowser (HardwareTest path) ---");
  bool fabglOk = false;
  const PinCfg * tries[] = { &PIN_PICO, &PIN_WROVER };
  for (size_t i = 0; i < 2; ++i) {
    linef("FabGL %s ...", tries[i]->label);
    if (tryFabglMount(*tries[i], 400)) {
      line("  -> OK");
      fabglOk = true;
      if (tries[i] != primary)
        line("  (unexpected pin - not TTGO default)");
      break;
    }
    line("  -> FAILED");
    vTaskDelay(pdMS_TO_TICKS(50));
  }

  if (!fabglOk) {
    line("");
    line("--- Arduino SD.h fallback ---");
    for (size_t i = 0; i < 2; ++i) {
      linef("SD.h %s @ 400kHz ...", tries[i]->label);
      if (tryArduinoSd(*tries[i], 400000)) {
        line("  -> OK");
        fabglOk = true;
        break;
      }
      line("  -> FAILED");
      linef("SD.h %s @ 100kHz ...", tries[i]->label);
      if (tryArduinoSd(*tries[i], 100000)) {
        line("  -> OK");
        fabglOk = true;
        break;
      }
      line("  -> FAILED");
    }
    spiRelease();
  }

  line("");
  if (!fabglOk) {
    line("=== ALL FAILED ===");
    line("");
    line("You already see this in FabGL HardwareTest.");
    line("Software/pins look correct; suspect:");
    line("  - SD slot contacts / solder");
    line("  - damaged slot on board");
    line("  - try another microSD brand");
    line("");
    line("Remove card and re-run: MISO should read 1.");
    line("=== END ===");
    return;
  }

  line("=== SUCCESS ===");
  line("");
  line("Listing /SD :");
  listDir("/SD");
  line("");
  line("Listing /SD/otto :");
  if (opendir("/SD/otto") == nullptr)
    line("  (missing - create folder 'otto' on card)");
  else {
    listDir("/SD/otto");
    line("");
    line("Listing /SD/otto/apps :");
    listDir("/SD/otto/apps");
  }

  fabgl::FileBrowser::unmountSDCard();
  SD.end();
  line("");
  line("=== SD OK - re-flash AdvancedTerminal ===");
  line("=== END ===");
}

static void sdTestTask(void *) {
  runSdTest();
  xSemaphoreGive(s_done);
  vTaskDelete(NULL);
}

void setup() {
  disableCore0WDT();
  disableCore1WDT();
#if defined(ESP_IDF_VERSION_MAJOR) && (ESP_IDF_VERSION_MAJOR >= 4)
  esp_task_wdt_deinit();
#endif

  delay(200);
  fabgl::Mouse::quickCheckHardware();
  PS2Controller.begin(fabgl::PS2Preset::KeyboardPort0);

  DisplayController = new fabgl::VGA8Controller;
  DisplayController->begin();
  DisplayController->setResolution(SVGA_800x600_56Hz);

  Terminal.begin(DisplayController);
  Terminal.enableCursor(true);
  delay(100);

  Terminal.clear();
  line("*** VGA32 SD Card Test ***");
  linef("Chip: %s", chipName());
#if defined(ARDUINO_ESP32_GIT_VER)
  linef("ESP32 core: %s", ARDUINO_ESP32_GIT_VER);
#elif defined(ESP_ARDUINO_VERSION_STR)
  linef("ESP32 core: %s", ESP_ARDUINO_VERSION_STR);
#endif
  if (fabgl::getChipPackage() == fabgl::ChipPackage::ESP32PICOD4)
    line("TTGO pins: CS=13 MOSI=12 MISO=2 CLK=14");
  else
    line("TTGO pins: CS=13 MOSI=12 MISO=35 CLK=14");
  line("UART: not used");
  line("");
  line("Boot OK - starting SD task...");
  delay(200);

  s_done = xSemaphoreCreateBinary();
  xTaskCreate(sdTestTask, "sdtest", 10240, nullptr, 1, nullptr);
  xSemaphoreTake(s_done, portMAX_DELAY);
  vSemaphoreDelete(s_done);
  s_done = nullptr;
}

void loop() {
  delay(1000);
}
