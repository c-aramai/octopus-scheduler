# OctopusScheduler Release Process

## Prerequisites

- Xcode command line tools (`xcode-select --install`)
- `gh` CLI authenticated (`gh auth status`)
- Write access to c-aramai/octopus-scheduler

## Release Steps

### 1. Update Version

Edit `OctopusScheduler/OctopusScheduler/Info.plist`:
- `CFBundleShortVersionString` → new version (e.g., "1.3.0")
- `CFBundleVersion` → increment build number

Also update `version` in `Models/Config.swift` default config if needed.

### 2. Build Release

```bash
cd ~/ARAMAI/dev/octopus-scheduler/OctopusScheduler
xcodebuild -project OctopusScheduler.xcodeproj \
  -scheme OctopusScheduler \
  -configuration Release \
  build \
  CONFIGURATION_BUILD_DIR=./build/release
```

### 3. Create Distribution Package

```bash
VERSION=1.3.0
mkdir -p build/dist/OctopusScheduler-v${VERSION}/{prompts,config}

# Copy app
cp -R build/release/OctopusScheduler.app build/dist/OctopusScheduler-v${VERSION}/

# Copy prompts and config
cp ../prompts/*.md build/dist/OctopusScheduler-v${VERSION}/prompts/
cp build/dist/OctopusScheduler-v1.2.0/config/default-config.json build/dist/OctopusScheduler-v${VERSION}/config/

# Update version in default config
# Edit config/default-config.json version field

# Create zip
cd build/dist
zip -r OctopusScheduler-v${VERSION}.zip OctopusScheduler-v${VERSION}/ -x "*.DS_Store"
```

### 4. Update Release Notes

Edit `RELEASE_NOTES.md` with changes for this version.

### 5. Commit, Tag, and Release

```bash
git add -A
git commit -m "release: OctopusScheduler v${VERSION}"
git tag -a v${VERSION} -m "Release v${VERSION}"
git push && git push origin v${VERSION}

gh release create v${VERSION} \
  ./OctopusScheduler/build/dist/OctopusScheduler-v${VERSION}.zip \
  --title "OctopusScheduler v${VERSION}" \
  --notes-file RELEASE_NOTES.md
```

### 6. Verify

- Release visible at https://github.com/c-aramai/octopus-scheduler/releases
- Existing installs see "Update Available" via Check for Updates

## Version Numbering

- **Major** (x.0.0): Breaking config changes, major features
- **Minor** (0.x.0): New features, backward compatible
- **Patch** (0.0.x): Bug fixes, minor improvements

## Release Checklist

- [ ] Version bumped in Info.plist
- [ ] RELEASE_NOTES.md updated
- [ ] `xcodebuild` succeeds (Release config)
- [ ] App launches and works locally
- [ ] Distribution zip created with app + prompts + config + README
- [ ] Git tagged and pushed
- [ ] GitHub release created with zip asset
- [ ] "Check for Updates" shows new version from older install
