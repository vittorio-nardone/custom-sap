#include "otto_uart_raw.h"

#include "fabgl.h"

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "soc/uart_reg.h"
#include "soc/uart_struct.h"

namespace {

constexpr int kOttoUartIndex = 2;

volatile uart_dev_t * uartDev()
{
  return reinterpret_cast<volatile uart_dev_t *>(DR_REG_UART2_BASE);
}

} // namespace

int OttoUartRaw::rxFifoCount() const
{
  volatile uart_dev_t * dev = uartDev();
  // Match FabGL SerialPort::uartGetRXFIFOCount
  return (int)dev->status.rxfifo_cnt | ((int)(dev->mem_cnt_status.rx_cnt) << 8);
}

bool OttoUartRaw::tryReadFifo(uint8_t * out)
{
  volatile uart_dev_t * dev = uartDev();
  // FabGL also keeps reading while wr_addr != rd_addr (HW FIFO quirk).
  if (rxFifoCount() == 0 &&
      dev->mem_rx_status.wr_addr == dev->mem_rx_status.rd_addr)
    return false;
  // Match FabGL uart_isr / uartFlushRXFIFO — fifo.rw_byte handles mem-RX too.
  *out = static_cast<uint8_t>(dev->fifo.rw_byte);
  return true;
}

bool OttoUartRaw::popRing(uint8_t * out)
{
  if (m_rxHead == m_rxTail)
    return false;
  *out = m_rxRing[m_rxTail];
  m_rxTail = static_cast<uint16_t>((m_rxTail + 1) % kRxRingSize);
  return true;
}

void OttoUartRaw::pushRing(uint8_t value)
{
  uint16_t const next = static_cast<uint16_t>((m_rxHead + 1) % kRxRingSize);
  if (next == m_rxTail)
    m_rxTail = static_cast<uint16_t>((m_rxTail + 1) % kRxRingSize);  // drop oldest
  m_rxRing[m_rxHead] = value;
  m_rxHead = next;
}

size_t OttoUartRaw::ringUsed() const
{
  if (m_rxHead >= m_rxTail)
    return m_rxHead - m_rxTail;
  return kRxRingSize - m_rxTail + m_rxHead;
}

size_t OttoUartRaw::rxPendingCount()
{
  pumpRx();
  return ringUsed() + static_cast<size_t>(rxFifoCount());
}

void OttoUartRaw::pumpRx()
{
  uint8_t b = 0;
  while (tryReadFifo(&b))
    pushRing(b);
}

bool OttoUartRaw::begin(fabgl::SerialPort * port, fabgl::SerialPortTerminalConnector * connector, fabgl::Terminal * /*terminal*/)
{
  if (!port || !port->initialized())
    return false;

  if (m_active)
    end();

  m_port      = port;
  m_connector = connector;
  m_rxHead    = 0;
  m_rxTail    = 0;

  // Stop FabGL from stealing RX bytes (connector flag is harmless with our
  // callbacks, but keep it off so a reconnect cannot paint binary into the UI).
  if (m_connector)
    m_connector->disableSerialPortRX(true);

  // Disable ALL UART2 interrupts — we own the FIFO until end().
  m_savedIntEna = READ_PERI_REG(UART_INT_ENA_REG(kUartIndex));
  WRITE_PERI_REG(UART_INT_ENA_REG(kUartIndex), 0);
  WRITE_PERI_REG(UART_INT_CLR_REG(kUartIndex), 0xffffffff);

  flushRx();
  m_active = true;
  return true;
}

void OttoUartRaw::end()
{
  if (!m_active)
    return;

  flushRx();

  WRITE_PERI_REG(UART_INT_CLR_REG(kUartIndex), 0xffffffff);
  // Restore whatever FabGL had enabled (typically RX FIFO full + error IRQs).
  if (m_savedIntEna == 0) {
    WRITE_PERI_REG(UART_INT_ENA_REG(kUartIndex),
                   UART_RXFIFO_FULL_INT_ENA_M | UART_FRM_ERR_INT_ENA_M |
                   UART_PARITY_ERR_INT_ENA_M | UART_RXFIFO_OVF_INT_ENA_M |
                   UART_BRK_DET_INT_ENA_M);
  } else {
    WRITE_PERI_REG(UART_INT_ENA_REG(kUartIndex), m_savedIntEna);
  }

  if (m_connector)
    m_connector->disableSerialPortRX(false);

  m_port      = nullptr;
  m_connector = nullptr;
  m_active    = false;
  m_savedIntEna = 0;
}

void OttoUartRaw::flushRx()
{
  uint8_t b = 0;
  while (tryReadFifo(&b))
    ;
  m_rxHead = 0;
  m_rxTail = 0;
}

void OttoUartRaw::drainSyncCs()
{
  pumpRx();
  uint8_t keep[kRxRingSize];
  size_t  n = 0;
  uint8_t b = 0;
  while (popRing(&b)) {
    if (b != 0x43 && n < kRxRingSize)
      keep[n++] = b;
  }
  for (size_t i = 0; i < n; ++i)
    pushRing(keep[i]);
}

bool OttoUartRaw::readByte(uint8_t * out, uint32_t timeoutMs)
{
  if (!m_active || !out)
    return false;

  pumpRx();
  if (popRing(out))
    return true;

  TickType_t const start = xTaskGetTickCount();
  TickType_t const wait  = pdMS_TO_TICKS(timeoutMs);
  while ((xTaskGetTickCount() - start) < wait) {
    pumpRx();
    if (popRing(out))
      return true;
    vTaskDelay(pdMS_TO_TICKS(1));
  }
  pumpRx();
  return popRing(out);
}

void OttoUartRaw::writeByte(uint8_t value)
{
  // Same path as FabGL SerialPort::send — direct AHB FIFO write.
  volatile uart_dev_t * dev = uartDev();
  while (dev->status.txfifo_cnt == 0x7F)
    ;
  WRITE_PERI_REG(UART_FIFO_AHB_REG(kUartIndex), value);
}

void OttoUartRaw::writeBytes(uint8_t const * data, size_t len)
{
  if (!data)
    return;
  for (size_t i = 0; i < len; ++i)
    writeByte(data[i]);
}

void OttoUartRaw::abortOttoReceiver()
{
  // 1) ESC aborts Otto XMODEM_RCV (required — otherwise Otto hangs until reboot).
  writeByte(0x1B);
  vTaskDelay(pdMS_TO_TICKS(100));

  // 2) If Otto was still at the menu, bare ESC blocks in ACIA_READ_ESCAPE_KEY.
  //    Finish a CSI sequence so it returns to the prompt loop.
  writeByte('[');
  writeByte('B');
  vTaskDelay(pdMS_TO_TICKS(50));

  // 3) Erase any leftover chars that landed in the menu input buffer.
  for (int i = 0; i < 8; ++i)
    writeByte(0x08);
  vTaskDelay(pdMS_TO_TICKS(30));
  flushRx();
}

void ottoUartFlushHwRx()
{
  volatile uart_dev_t * dev = uartDev();
  while (dev->status.rxfifo_cnt != 0 ||
         dev->mem_rx_status.wr_addr != dev->mem_rx_status.rd_addr)
    (void)dev->fifo.rw_byte;
}
