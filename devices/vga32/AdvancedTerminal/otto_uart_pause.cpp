#include "otto_uart_pause.h"
#include "otto_sd.h"
#include "fabgl.h"
#include <driver/gpio.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <soc/uart_reg.h>

static constexpr int OTTO_UART_HW_NUM = 2;

void ottoUartPauseForSd(fabgl::SerialPort * serial) {
  if (!serial || !OttoSd::sdSharesUartTx())
    return;
  serial->setCallbacks(nullptr, nullptr, nullptr);
  serial->flowControl(false);
  WRITE_PERI_REG(UART_INT_ENA_REG(OTTO_UART_HW_NUM), 0);
  gpio_matrix_out(GPIO_NUM_2, 0x100, false, false);
  gpio_reset_pin(GPIO_NUM_2);
  gpio_set_direction(GPIO_NUM_2, GPIO_MODE_INPUT);
  gpio_set_pull_mode(GPIO_NUM_2, GPIO_PULLUP_ONLY);
  vTaskDelay(pdMS_TO_TICKS(2));
}

void ottoUartRemount(fabgl::SerialPort * serial, void (*restoreUart)()) {
  if (restoreUart)
    restoreUart();
  if (serial && !serial->readyToReceive())
    serial->flowControl(true);
}
