# Security Policy

## Supported Version

Security fixes are developed on the current `main` branch and are included in the next published ForgeText release. Older local builds and tags may not contain the current controls.

## Reporting A Vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's private vulnerability reporting flow on the repository Security tab and include:

- affected version, build, and macOS version
- exact feature and trust/policy state
- reproduction steps or proof of concept
- expected and observed impact
- relevant logs with credentials, document contents, usernames, and local paths removed

Please allow time to reproduce, patch, test, and coordinate disclosure before publishing details.

## Security Architecture

See [Security Hardening](docs/SECURITY_HARDENING.md) for ForgeText's trust boundaries, capability matrix, process/network/file controls, plugin signing format, release controls, and residual risks.
