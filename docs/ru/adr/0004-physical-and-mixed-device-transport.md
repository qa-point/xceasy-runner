# ADR 0004: physical и mixed device transport

Статус: принято, 2026-08-17.

## Решение

Config schema 1.0.0 описывает устройство объектом с `type` (`simulator`/`physical`) и ровно одним selector `id` или `name`. Runner отдельно выполняет `build-for-testing` для `iphonesimulator` и `iphoneos`; assignment хранит `device_type` и Xcode destination.

Simulator artifacts экспортируются через `simctl`, physical artifacts — через `devicectl device copy from` с domain `appDataContainer`. Recovery использует только healthy candidate того же типа.

## Ограничения

Signing, trust и developer mode остаются ответственностью Xcode/CI. Physical path покрыт fake contract tests; без hardware real-device acceptance не заявляется.
