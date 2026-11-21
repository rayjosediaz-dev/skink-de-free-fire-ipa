# Panther FF Skin Viewer — iOS prototype

## What works
- SwiftUI dark/blue interface for iOS 15+
- Files picker, reads file bytes and identifies `UnityFS` header and Unity version
- Displays basic 3D `.scn` and `.dae` models with SceneKit controls
- Clothing category UI (empty until a real catalog is implemented)
- Saves outfit **names** locally, not actual wardrobe combinations
- GitHub Actions workflow generates an **unsigned** IPA

## Not yet implemented
- Decompressing UnityFS asset bundles or extracting meshes/textures/materials
- Auto-identifying Free Fire outfits or loading an exhaustive official wardrobe
- Changing meshes/clothing on imported characters
- Signed IPA or App Store distribution

## Build
1. Upload all project contents (including hidden `.github` directory) to a GitHub repository.
2. Open Actions > Build unsigned IPA > Run workflow.
3. Download the artifact and sign the IPA with a valid signing method before installing on iPhone.

Local build on macOS: `brew install xcodegen && xcodegen generate`, then open `.xcodeproj` in Xcode.

`SampleFiles` includes the user-provided UnityFS file for testing. It is NOT automatically bundled into the app.
