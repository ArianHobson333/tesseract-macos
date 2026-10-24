# Security policy

## Reporting a vulnerability

Please report security issues privately through GitHub:
**Security → Report a vulnerability** on
[tesseract-macos](https://github.com/ArianHobson333/tesseract-macos/security/advisories/new)
or [tesseract](https://github.com/ArianHobson333/tesseract/security/advisories/new).
Don't open a public issue.

Include the Tesseract version (Settings → About), macOS version and steps to
reproduce. You'll get a reply within a week.

Bugs in Chromium itself should go to the
[Chromium tracker](https://issues.chromium.org);
bugs in Helium patches to [Helium](https://github.com/imputnet/helium/security).

## Supported versions

Only the latest release gets fixes.

## Security updates

Tesseract follows Helium releases (which follow Chromium stable). The target
is a Tesseract build within 24 hours of each Helium release; an automatic job
checks every 6 hours. See [docs/syncing-upstream.md](docs/syncing-upstream.md).
