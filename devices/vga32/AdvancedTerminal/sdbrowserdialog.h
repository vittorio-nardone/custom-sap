/*
 * SD card browser (read-only) - F11 on AdvancedTerminal for Project Otto.
 */

#pragma once

#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>

#include "fabui.h"
#include "otto_sd_host.h"
#include "otto_sd.h"
#include "confdialog.h"
#include "uistyle.h"

extern fabgl::BitmappedDisplayController * DisplayController;

static constexpr int OTTO_SD_UI_STACK = 8192;


class SdBrowserDialogApp : public uiApp {
public:
  Rect  frameRect;
  uiFrame * frame = nullptr;

  ~SdBrowserDialogApp() {
    OttoSdHost::endUiSession(ConfDialogApp::setupUartHardware);
  }

  void closeDialog() {
    quit(0);
  }

  void init() {
    setStyle(&dialogStyle);

    rootWindow()->frameProps().fillBackground = false;

    bool const sdOk = OttoSdHost::beginUiSession(ConfDialogApp::setupUartHardware);

    frame = new uiFrame(rootWindow(), "SD Card Browser", UIWINDOW_PARENTCENTER, Size(400, 270), true, STYLE_FRAME);
    frameRect = frame->rect(fabgl::uiOrigin::Screen);

    frame->frameProps().resizeable        = false;
    frame->frameProps().moveable          = false;
    frame->frameProps().hasCloseButton    = false;
    frame->frameProps().hasMaximizeButton = false;
    frame->frameProps().hasMinimizeButton = false;
    frame->windowProps().activeLook       = true;
    // Gray frame border contrasts with blue title bar (activeBorder defaults match title).
    frame->windowStyle().borderColor       = RGB888(128, 128, 128);
    frame->windowStyle().activeBorderColor = RGB888(128, 128, 128);

    frame->onKeyUp = [&](uiKeyEventInfo const & key) {
      if (key.VK == VirtualKey::VK_ESCAPE)
        closeDialog();
    };

    int y = 19;

    new uiStaticLabel(frame, "Arrows / Enter: folder   ESC: close", Point(88, y), true, STYLE_LABELHELP);

    y += 28;

    uiFileBrowser * browser = nullptr;
    if (sdOk) {
      browser = new uiFileBrowser(frame, Point(10, y), Size(380, 168), true, STYLE_LISTBOX);
      browser->listBoxProps().allowMultiSelect = false;
      browser->setParentProcessKbdEvents(true);
      browser->onKeyUp = [&](uiKeyEventInfo const & key) {
        if (key.VK == VirtualKey::VK_ESCAPE)
          closeDialog();
      };
      browser->setDirectory(VGA_SD_ROOT);
      frame->onShow = [&, browser]() {
        setFocusedWindow(browser);
      };
    } else {
      new uiStaticLabel(frame, "SD card not available.", Point(10, y + 20), true, STYLE_STATICLABEL);
      new uiStaticLabel(frame, "Use FAT32 with vga/ on the card.", Point(10, y + 36), true, STYLE_STATICLABEL);
    }

    y += 172;

    auto closeButton = new uiButton(frame, "Close", Point(10, y), Size(70, 20), uiButtonKind::Button, true, STYLE_BUTTON);
    closeButton->onClick = [&]() {
      closeDialog();
    };

    setActiveWindow(frame);
    if (browser)
      setFocusedWindow(browser);
    else
      setFocusedWindow(closeButton);
  }
};


/** Run the SD browser on a dedicated UI task (avoids stack overflow in the keyboard task). */
inline void runSdBrowserDialog(SdBrowserDialogApp * app) {
  SemaphoreHandle_t done = xSemaphoreCreateBinary();
  struct Ctx {
    SdBrowserDialogApp * app;
    SemaphoreHandle_t    done;
  } ctx = { app, done };

  auto taskFn = [](void * arg) {
    auto * c = static_cast<Ctx *>(arg);
    c->app->run(DisplayController);
    xSemaphoreGive(c->done);
    vTaskDelete(nullptr);
  };

  if (fabgl::CoreUsage::busiestCore() == -1)
    xTaskCreate(taskFn, "otto_sd_ui", OTTO_SD_UI_STACK, &ctx, 5, nullptr);
  else
    xTaskCreatePinnedToCore(taskFn, "otto_sd_ui", OTTO_SD_UI_STACK, &ctx, 5, nullptr, fabgl::CoreUsage::quietCore());

  xSemaphoreTake(done, portMAX_DELAY);
  vSemaphoreDelete(done);
}
