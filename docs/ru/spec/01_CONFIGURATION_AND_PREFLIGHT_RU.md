# R01 — Конфигурация и preflight

CLI проверяет config 1.0.0 до Xcode. Unknown keys, duplicate/empty devices, неподдерживаемый mode, неверный recovery limit и malformed selection завершаются явной ошибкой. Относительные workspace/output/baseline/policy paths считаются от config directory. Preflight сохраняет snapshot `simctl` и исключает недоступные devices, если `require_all_devices` не требует точную matrix.

Acceptance: malformed config не запускает Xcode; отсутствие healthy device приводит к failure; каждый accepted/rejected device и stable reason записаны до enumeration.
