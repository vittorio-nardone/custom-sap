#include "otto_bridge.h"
#include "otto_sd.h"
#include <dirent.h>
#include <driver/gpio.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <stdio.h>
#include <string.h>

static OttoBridge * s_bridge = nullptr;

static constexpr int OTIO_RX_QUEUE_LEN = 512;
static constexpr int OTIO_WORKER_STACK   = 8192;

OttoBridge & OttoBridge::instance() {
  static OttoBridge inst;
  return inst;
}

void OttoBridge::txByte(uint8_t b) {
  if (s_bridge && s_bridge->m_serial)
    s_bridge->m_serial->send(b);
}

void OttoBridge::statusLine(char const * msg) {
  if (s_bridge && s_bridge->m_terminal && msg) {
    s_bridge->m_terminal->write("\r\n");
    s_bridge->m_terminal->write(msg);
    s_bridge->m_terminal->write("\r\n");
  }
}

void OttoBridge::pauseUartForSd() {
  if (!m_serial || !OttoSd::sdSharesUartTx())
    return;
  m_serial->setCallbacks(nullptr, nullptr, nullptr);
  gpio_reset_pin(GPIO_NUM_2);
}

void OttoBridge::remountUart() {
  if (m_uartRestore)
    m_uartRestore();
  installRxHook();
  if (m_serial && !m_serial->readyToReceive())
    m_serial->flowControl(true);
}

static char const * chipPackageLabel() {
  switch (fabgl::getChipPackage()) {
    case fabgl::ChipPackage::ESP32PICOD4: return "PICO-D4";
    case fabgl::ChipPackage::ESP32D0WDQ5: return "WROVER";
    case fabgl::ChipPackage::ESP32D0WDQ6: return "WROOM";
    default: return "ESP32";
  }
}

void OttoBridge::probeBootSd(int csPin, char * buf, size_t bufLen) {
  if (!buf || bufLen < 16)
    return;
  buf[0] = '\0';

  int const miso = OttoSd::sdSharesUartTx() ? 2 : 35;
  char const * pkg = chipPackageLabel();

  // Probe runs before the UART claims GPIO 2 (shared SD MISO on PICO-D4),
  // so no pause/remount of the serial line is needed here — same conditions
  // as the standalone SdCardTest sketch.
  m_sd.begin(csPin);

  if (!m_sd.tryMount()) {
    snprintf(buf, bufLen, "mount FAILED (MISO=%d, %s)", miso, pkg);
    return;
  }

  DIR * dir = opendir(OTIO_SD_ROOT);
  bool const ottoOk = (dir != nullptr);
  if (dir)
    closedir(dir);
  if (ottoOk)
    m_sd.markSdKnown();

  m_sd.release();

  if (ottoOk)
    snprintf(buf, bufLen, "OK (%s, MISO=%d, %s)", OTIO_SD_ROOT, miso, pkg);
  else
    snprintf(buf, bufLen, "mounted, %s missing (MISO=%d)", OTIO_SD_ROOT, miso);
}

void OttoBridge::endOtioSession() {
  m_otioActive = false;
}

bool OttoBridge::beginUiSdSession() {
  drainRxQueue();
  m_otioActive  = false;
  m_uiSdSession = true;
  OttoSd::setUiHold(true);
  if (!m_sd.tryMount()) {
    endUiSdSession();
    return false;
  }
  return true;
}

void OttoBridge::endUiSdSession() {
  OttoSd::setUiHold(false);
  m_sd.release();
  m_uiSdSession = false;
  m_otioActive  = false;
  drainRxQueue();
}

void OttoBridge::drainRxQueue() {
  if (!m_rxQueue)
    return;
  uint8_t byte;
  while (xQueueReceive(m_rxQueue, &byte, 0) == pdTRUE) {}
}

void OttoBridge::begin(fabgl::SerialPort * serial, fabgl::Terminal * terminal,
                       fabgl::SerialPortTerminalConnector * connector,
                       uint8_t fwMaj, uint8_t fwMin, int sdCsPin,
                       void (*uartRestore)()) {
  m_serial      = serial;
  m_terminal    = terminal;
  m_connector   = connector;
  m_uartRestore = uartRestore;
  s_bridge      = this;

  m_sd.begin(sdCsPin);
  OttoSd::setUartHooks([]() { OttoBridge::instance().pauseUartForSd(); },
                       []() { OttoBridge::instance().remountUart(); });
  m_proto.begin(&m_sd, fwMaj, fwMin);
  m_proto.setTx(txByte);
  m_proto.setStatusLine(statusLine);
  m_proto.setUartRestore([]() { OttoBridge::instance().remountUart(); });

  if (!m_rxQueue)
    m_rxQueue = xQueueCreate(OTIO_RX_QUEUE_LEN, sizeof(uint8_t));
  if (!m_workerTask)
    xTaskCreate(workerTask, "otto_rx", OTIO_WORKER_STACK, this, 5, &m_workerTask);
  installRxHook();
}

void OttoBridge::installRxHook() {
  if (m_serial)
    m_serial->setCallbacks(this, serialRxReadyCallback, serialRxCallback);
}

void OttoBridge::workerTask(void * arg) {
  auto * self = static_cast<OttoBridge *>(arg);
  uint8_t byte;
  for (;;) {
    if (xQueueReceive(self->m_rxQueue, &byte, portMAX_DELAY) == pdTRUE) {
      if (!self->onRx(byte) && self->m_terminal)
        self->m_terminal->write(byte, false);
      if (self->m_serial && !self->m_serial->readyToReceive() &&
          uxQueueSpacesAvailable(self->m_rxQueue) > (OTIO_RX_QUEUE_LEN / 4))
        self->m_serial->flowControl(true);
    }
  }
}

void OttoBridge::serialRxCallback(void * args, uint8_t value, bool fromISR) {
  auto * self = static_cast<OttoBridge *>(args);
  if (!self->m_rxQueue)
    return;
  if (fromISR) {
    BaseType_t woken = pdFALSE;
    if (xQueueSendFromISR(self->m_rxQueue, &value, &woken) != pdTRUE)
      return;
    if (woken)
      portYIELD_FROM_ISR();
  } else {
    xQueueSend(self->m_rxQueue, &value, portMAX_DELAY);
  }
}

bool OttoBridge::serialRxReadyCallback(void * args, bool fromISR) {
  auto * self = static_cast<OttoBridge *>(args);
  if (!self->m_rxQueue)
    return false;
  (void)fromISR;
  return uxQueueSpacesAvailable(self->m_rxQueue) > 0;
}

bool OttoBridge::onRx(uint8_t byte) {
  if (m_uiSdSession) {
    if (byte == OTIO_SYNC)
      m_otioActive = true;
    if (m_otioActive) {
      if (byte == OTIO_ETX)
        m_otioActive = false;
      return true;
    }
    return false;
  }

  if (byte == OTIO_SYNC)
    m_otioActive = true;

  if (m_otioActive) {
    bool inFrame = m_proto.feed(byte);
    if (m_proto.takeFrameEnded()) {
      bool ok = m_proto.takeFrameDone();
      endOtioSession();
      if (!ok)
        drainRxQueue();
    }
    if (!inFrame) {
      endOtioSession();
      return false;
    }
    return true;
  }

  if (byte == OTIO_SYNC || byte == OTIO_ETX)
    return true;
  return false;
}
