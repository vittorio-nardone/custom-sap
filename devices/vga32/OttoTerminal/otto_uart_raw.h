/*
 * Raw UART access for Otto XMODEM.
 *
 * Takes exclusive ownership of UART2 for the session: disables ALL UART2
 * interrupts and polls the HW FIFO. This avoids FabGL ISR races and the
 * "bytes discarded while menu has RX gated" failure mode.
 *
 * end() restores interrupt enables and does NOT call connector->connect()
 * (that would wipe OttoTerminal's onSend mute gate).
 */
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace fabgl {
class SerialPort;
class SerialPortTerminalConnector;
class Terminal;
}

class OttoUartRaw {
public:
  OttoUartRaw() = default;

  bool begin(fabgl::SerialPort * port, fabgl::SerialPortTerminalConnector * connector, fabgl::Terminal * terminal);
  void end();

  void flushRx();
  /** Drain HW RX into internal ring (call during long waits, e.g. WiFi download). */
  void pumpRx();
  bool readByte(uint8_t * out, uint32_t timeoutMs);
  void writeByte(uint8_t value);
  void writeBytes(uint8_t const * data, size_t len);

  /** Send ESC a few times so Otto leaves XMODEM_RCV / escape wait. */
  void abortOttoReceiver();

  /** Drop Otto sync 'C' bytes that arrive while we wait for ACK/EOT. */
  void drainSyncCs();

  /** Bytes waiting in ring + HW FIFO (calls pumpRx). */
  size_t rxPendingCount();

  bool active() const { return m_active; }

private:
  static constexpr int kUartIndex = 2;

  fabgl::SerialPort *                m_port = nullptr;
  fabgl::SerialPortTerminalConnector * m_connector = nullptr;
  bool                m_active = false;
  uint32_t            m_savedIntEna = 0;

  int  rxFifoCount() const;
  bool tryReadFifo(uint8_t * out);
  bool popRing(uint8_t * out);
  void pushRing(uint8_t value);
  size_t ringUsed() const;

  static constexpr size_t kRxRingSize = 1024;
  uint8_t  m_rxRing[kRxRingSize]{};
  uint16_t m_rxHead = 0;
  uint16_t m_rxTail = 0;
};

void ottoUartFlushHwRx();
