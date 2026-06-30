/*
 * UART bridge: OTIO binary frames vs FabGL terminal.
 */
#pragma once

#include "fabgl.h"
#include "otto_proto.h"
#include "otto_sd.h"

#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

class OttoBridge {
public:
  static OttoBridge & instance();

  void begin(fabgl::SerialPort * serial, fabgl::Terminal * terminal,
             fabgl::SerialPortTerminalConnector * connector,
             uint8_t fwMaj, uint8_t fwMin, int sdCsPin = 13,
             void (*uartRestore)() = nullptr);

  void installRxHook();
  void pauseUartForSd();
  void remountUart();

  /** Boot SD probe — call before UART init (GPIO 2 = SD MISO on PICO-D4). */
  void probeBootSd(int csPin, char * buf, size_t bufLen);

  void markSdKnownFromBoot() { m_sd.markSdKnown(); }

  /** Mount SD for the F11 browser; blocks OTIO until endUiSdSession(). */
  bool beginUiSdSession();
  void endUiSdSession();
  bool isUiSdSession() const { return m_uiSdSession; }

  void endOtioSession();
  void drainRxQueue();
  bool onRx(uint8_t byte);
  bool isOtioActive() const { return m_otioActive; }

private:
  OttoBridge() = default;

  fabgl::SerialPort *                  m_serial    = nullptr;
  fabgl::Terminal *                    m_terminal  = nullptr;
  fabgl::SerialPortTerminalConnector * m_connector = nullptr;
  OttoSd                               m_sd;
  OttoProto                            m_proto;
  bool                                 m_otioActive  = false;
  bool                                 m_uiSdSession = false;

  QueueHandle_t                        m_rxQueue    = nullptr;
  TaskHandle_t                         m_workerTask = nullptr;
  void (*m_uartRestore)()              = nullptr;

  static void workerTask(void * arg);
  static void txByte(uint8_t b);
  static void statusLine(char const * msg);
  static void serialRxCallback(void * args, uint8_t value, bool fromISR);
  static bool serialRxReadyCallback(void * args, bool fromISR);
};
