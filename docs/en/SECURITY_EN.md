# Security policy

English · [Русский](../ru/SECURITY_RU.md)

Security fixes target the latest published release. Older preview releases may require an upgrade; there is no separate long-term support branch.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/qa-point/xceasy-runner/security/advisories/new). Include the affected version, impact, and minimal reproduction using synthetic data. Do not post passwords, tokens, private UI screenshots, or customer logs in public issues. If reporting is unavailable, open an issue requesting a private contact without vulnerability details.

## Diagnostics

XCEasy is a test framework: UI trees, field values, and screenshots are diagnostic evidence and can contain application data. Keep useful diagnostics enabled for synthetic test data. The existing text credential filter is best effort, not a guarantee of anonymization. Control access and retention when sharing test artifacts; never assume a screenshot is anonymized.

## Repository and build protection

CI actions are pinned to commit SHAs and updated through Dependabot. The security workflow checks reachable Git history with Gitleaks 8.30.1 using a pinned archive checksum; update the scanner version and checksum together after review. Narrow documented false-positive fingerprints are allowed; real credentials must be revoked, not suppressed.

GitHub secret scanning, push protection, private reporting, branch/tag rules and automatic security updates are repository settings, not enabled by these files alone. Dependency updates require review and green CI. Build jobs use read-only repository permissions and do not need a personal integration token for public dependencies.
