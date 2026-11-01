# Monitoring Script

Мониторинг процесса `test` с логированием, проверкой HTTP и оповещениями в Telegram.

## Что проверяет скрипт
- Проверяет состояние сервиса `test` через `systemctl is-active`.
- Выполняет HTTPS-проверку по адресу `https://test.com/monitoring/test/api`.
- Логирует события в `/var/log/monitoring.log`.
- При падении процесса автоматически пытается выполнить `systemctl restart test`.
- Отправляет сообщение в Telegram, если токен и chat ID настроены.
- Возвращает корректные exit codes для автоматической обработки в cron, systemd или CI.

## Exit codes
- `0` — сервис активен и HTTP-ответ успешный.
- `1` — сервис был неактивен и/или перезапуск завершился с ошибкой.
- `2` — сервис активен, но HTTP-проверка не прошла.
- `3` — Telegram-уведомление не отправилось.

## Telegram alerting
Для включения Telegram-оповещений задайте переменные перед запуском службы:

```bash
sudo systemctl edit monitor-test.service
```

И добавьте секцию:

```ini
[Service]
Environment=MONITOR_URL=https://test.com/monitoring/test/api
Environment=TELEGRAM_BOT_TOKEN=123456:ABCDEF
Environment=TELEGRAM_CHAT_ID=123456789
```

После этого перезагрузите сервисы:

```bash
sudo systemctl daemon-reload
sudo systemctl restart monitor-test.service
```

Если переменные не заданы, Telegram-уведомления просто отключаются, а основной мониторинг продолжает работать.

## Установка

1. Скопируйте скрипт в системную директорию:

```bash
sudo cp monitor-test.sh /usr/local/bin/monitor_test.sh
sudo chmod +x /usr/local/bin/monitor_test.sh
```

2. Подключите systemd-unit:

```bash
sudo cp monitor-test.service /etc/systemd/system/
sudo cp monitor-test.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now monitor-test.timer
```

3. Проверьте состояние таймера:

```bash
sudo systemctl status monitor-test.timer
sudo journalctl -u monitor-test.service -f
```

## Пример логов

Пример содержимого `/var/log/monitoring.log`:

```text
2026-11-01 10:00:00 - test is running and HTTP check passed (HTTP 200)
2026-11-01 10:01:00 - test is running but HTTP check failed with code 503
2026-11-01 10:02:00 - test not running (status: inactive), restarting...
2026-11-01 10:02:01 - test restarted successfully
```

## Удаление systemd service

Чтобы полностью удалить мониторинг:

```bash
sudo systemctl disable --now monitor-test.timer
sudo rm -f /etc/systemd/system/monitor-test.service
sudo rm -f /etc/systemd/system/monitor-test.timer
sudo rm -f /usr/local/bin/monitor_test.sh
sudo systemctl daemon-reload
sudo systemctl reset-failed
sudo rm -f /var/log/monitoring.log
```

## Скриншот результата работы

![Результат работы мониторинга](monitor-result.png)
