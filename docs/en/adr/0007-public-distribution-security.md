# Public distribution security

Installers preserve macOS quarantine instead of removing it. CI builds with read-only permissions; a separate job attests and publishes verified artifacts. Homebrew uses a checksummed universal release; Nix pins a reviewed stable Nixpkgs revision for both Darwin architectures. Apple Developer ID/notarization remain unconfigured without a signing identity.

Decision: keep diagnostic behavior unchanged; harden repository and distribution boundaries. Consequences: downloaded software may require an explicit macOS trust decision; existing tags are immutable; future releases require the verified build and separate publication job. Nixpkgs 26.05 is pinned because the previous unstable revision dropped Intel macOS. Reassess Intel support before that stable branch reaches end of support.
