# Release secrets

Names and purpose only; values are entered by the owner in GitHub
(Settings → Environments, or `gh secret set NAME --env <env>`) and never
written to files, logs or chat.

## Environments

| Environment | Who can use it | Used by |
|-------------|----------------|---------|
| `signing` | Branches `main` and `m1/*` only | Every build phase (the last phase signs and notarizes) |
| `release` | Branch `main` only, **owner approval required** for each run | Release job: GitHub release and appcast publish |

Builds only start by manual dispatch, never from pull requests, so forks
can't reach these secrets.

## `signing` environment

| Secret | What it is | How to make it |
|--------|------------|----------------|
| `PROD_MACOS_CERTIFICATE` | Developer ID Application certificate + private key, `.p12`, base64 | Xcode → Settings → Accounts → Manage Certificates → + Developer ID Application; export from Keychain Access as .p12; `base64 -i cert.p12 \| pbcopy` |
| `PROD_MACOS_CERTIFICATE_PWD` | Password set when exporting the .p12 | |
| `PROD_MACOS_CERTIFICATE_NAME` | Full identity, e.g. `Developer ID Application: Your Name (TEAMID)` | `security find-identity -v -p codesigning` |
| `PROD_MACOS_CI_KEYCHAIN_PWD` | Any long random string (temporary CI keychain) | `openssl rand -base64 32` |
| `PROD_MACOS_NOTARIZATION_APPLE_ID` | Apple Account email of the developer account | |
| `PROD_MACOS_NOTARIZATION_TEAM_ID` | 10-character Team ID | developer.apple.com → Membership |
| `PROD_MACOS_NOTARIZATION_PWD` | App-specific password | account.apple.com → Sign-In and Security → App-Specific Passwords |
| `PROD_MACOS_SPARKLE_ED_PUB_KEY` | Sparkle EdDSA **public** key (turns on the updater in the build) | see Sparkle below |
| `PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_B64` | **Not used until M6** (passkey entitlement, needs Apple approval). Leave unset. | |

Without `PROD_MACOS_CERTIFICATE_NAME` the build is ad-hoc signed and not notarized.

## `release` environment

| Secret | What it is |
|--------|------------|
| `TESSERACT_SPARKLE_ED_PRIVATE_KEY` | Sparkle EdDSA **private** key. Signs each update. |

## Repository secret

| Secret | What it is |
|--------|------------|
| `TESSERACT_SYNC_TOKEN` | Fine-grained personal access token for `tesseract`, `tesseract-macos` and `tesseract-updates`: Contents, Pull requests, Issues read and write. Used by the Helium sync job and to push the appcast. Set an expiry and a calendar reminder. |

## Sparkle keys

```sh
# Sparkle 2.10.0 tools: https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0
./bin/generate_keys            # creates the key in your login Keychain, prints the public key
./bin/generate_keys -x sparkle_private_key.txt   # export the private key
```

Paste the public key into `PROD_MACOS_SPARKLE_ED_PUB_KEY` and the file's
contents into `TESSERACT_SPARKLE_ED_PRIVATE_KEY`, then delete the file. Keep
an offline backup of the private key (e.g. in a password manager): if it's
lost, every installed copy stops getting updates.

## Rotation

- Developer ID certificate: renew before expiry (5 years), re-export, replace
  the three certificate secrets.
- App-specific password / token: revoke the old one, create a new one,
  replace the secret.
- Sparkle key: rotating needs a release signed with both keys during the
  transition (Sparkle key rotation docs). Avoid unless the key leaks.
