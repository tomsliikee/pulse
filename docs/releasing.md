# Releasing

A release is a signed APK on the GitHub Releases page. The workflow in
`.github/workflows/android.yml` builds it when a tag `v*` is pushed and opens
a **draft** release; nothing is public until the draft is published by hand.

## The release key (once)

Create a keystore and keep it, and its passwords, somewhere safe outside the
repository. An APK signed with a different key cannot update an installed
one, so losing the key means every user has to uninstall first.

```bash
keytool -genkeypair -v -keystore pulse-release.jks -storetype JKS \
  -keyalg RSA -keysize 4096 -validity 10000 -alias pulse
```

Add four secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| :--- | :--- |
| `KEYSTORE_BASE64` | `base64 -w 0 pulse-release.jks` |
| `KEYSTORE_PASSWORD` | The keystore's password |
| `KEY_ALIAS` | `pulse` |
| `KEY_PASSWORD` | The key's password |

A tag build fails rather than fall back to the debug key when the secrets
are missing.

To build a signed APK locally, put the same values into
`android/key.properties` (ignored by git); `storeFile` is relative to
`android/app/` or absolute:

```properties
storeFile=/path/to/pulse-release.jks
storePassword=...
keyAlias=pulse
keyPassword=...
```

Without that file, `flutter build apk --release` signs with the debug key.

## Each release

1. Set `version` in `pubspec.yaml`, for example `1.0.0-beta.2+2`. The number
   after `+` is Android's version code and must grow with every release.
2. Write `docs/release-notes/v<version>.md`, without the `+` part.
3. Merge to `main`, then tag and push:
   ```bash
   git tag v1.0.0-beta.2
   git push origin v1.0.0-beta.2
   ```
4. When the workflow is green, open the draft under **Releases**, check the
   APK and its checksum, and publish it. A tag with a `-` (like `-beta.2`) is
   marked as a pre-release.
