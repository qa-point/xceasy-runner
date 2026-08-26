# 04. Physical devices и state isolation

Русский · [English](../../en/spec/04_PHYSICAL_DEVICES_AND_STATE_ISOLATION_EN.md) · [Оглавление](README_RU.md)

- `devices` содержит уникальные `{type, id}` или `{type, name}`.
- Name обязан разрешаться ровно в одно устройство; иначе preflight фиксирует `simulator.ambiguous_name` или `physical.ambiguous_name`.
- Missing selectors дают `simulator.not_found`/`physical.not_found`; недоступный simulator — `simulator.unavailable`.
- `require_all_devices: true` запрещает сокращать matrix.
- Build, `.xctestrun`, destination, export и recovery выбираются по типу; recovery не меняет тип execution.

`state_isolation: app_reset_hook` передаёт `XC_EASY_STATE_ISOLATION=app_reset_hook` в UI-test process. Hook должен быть opt-in и очищать только согласованные app-owned stores до построения UI. Runner не удаляет приложение и не обещает сброс privacy permissions.
