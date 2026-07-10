# Contributing

Contributions are welcome when they keep the app local-first and do not require
contributors or CI to provide a real Nature Remo token.

## Development workflow

1. Create a focused branch from the default branch.
2. Make the smallest coherent change.
3. Run `swift test`.
4. Run `./script/build_and_run.sh --build-only --configuration release`.
5. Describe user-visible behavior and verification in the pull request.

## Credentials and fixtures

- Never commit a real token, account response, device ID, appliance ID, home
  name, serial number, email address, or sensor history.
- Add sanitized data under `Tests/NatureRemoMacTests/Fixtures` only.
- Use `MockURLProtocol` for API tests. CI must not call the live Nature API.
- If a credential is exposed, revoke it before attempting history cleanup.

## Code style

- Follow the existing Swift and SwiftUI structure.
- Keep API request construction in `NatureRemoClient`.
- Keep tokens behind the `TokenStoring` abstraction.
- Add or update tests for API endpoints, response decoding, and store behavior.
- Keep user-facing error messages free of raw provider response bodies.

## Scope

This repository currently publishes source code, not signed or notarized app
binaries. Changes to distribution, analytics, remote backends, or commercial
use require a separate design and legal review.
