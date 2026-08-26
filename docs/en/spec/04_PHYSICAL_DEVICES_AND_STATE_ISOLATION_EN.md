# 04. Physical devices and state isolation

English · [Русский](../../ru/spec/04_PHYSICAL_DEVICES_AND_STATE_ISOLATION_RU.md) · [Contents](README_EN.md)

- `devices` contains unique `{type, id}` or `{type, name}` values.
- A name must resolve to exactly one device; otherwise preflight records `simulator.ambiguous_name` or `physical.ambiguous_name`.
- Missing selectors produce `simulator.not_found`/`physical.not_found`; an unavailable simulator produces `simulator.unavailable`.
- `require_all_devices: true` forbids reducing the matrix.
- Build, `.xctestrun`, destination, export, and recovery are selected by type; recovery preserves the execution type.

`state_isolation: app_reset_hook` passes `XC_EASY_STATE_ISOLATION=app_reset_hook` to the UI-test process. The hook must be opt-in and clear only reviewed app-owned stores before UI construction. The runner does not remove the app or promise to reset privacy permissions.
