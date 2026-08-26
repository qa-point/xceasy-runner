# 05. Xcode test plans

English · [Русский](../../ru/spec/05_XCODE_TEST_PLANS_RU.md) · [Contents](README_EN.md)

- Test plans are part of the initial config schema 1.0.0.
- `test_plan` and `test_configuration` must both be present and non-empty.
- The plan must be associated with the configured scheme and the configuration must exist in that plan.
- Build uses `-testPlan NAME -only-test-configuration NAME`.
- Workers and recovery use the same `.xctestrun` and `-only-test-configuration`.
- Execution plan schema 1.0.0 contains `{name, configuration}`, or `null` without a test plan.
- The caller creates separate runner invocations for multiple configurations.
