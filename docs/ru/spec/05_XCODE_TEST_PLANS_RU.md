# 05. Xcode test plans

Русский · [English](../../en/spec/05_XCODE_TEST_PLANS_EN.md) · [Оглавление](README_RU.md)

- Test plan входит в первоначальную config schema 1.0.0.
- `test_plan` и `test_configuration` должны присутствовать вместе и быть непустыми.
- Plan обязан быть подключён к указанной scheme; configuration обязана существовать в plan.
- Build использует `-testPlan NAME -only-test-configuration NAME`.
- Worker и recovery используют тот же `.xctestrun` и `-only-test-configuration`.
- Execution plan schema 1.0.0 содержит `{name, configuration}` или `null` для запуска без test plan.
- Для нескольких configurations вызывающая система создаёт отдельные runner launches.
