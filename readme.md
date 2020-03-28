# cleanHUD

![standard_preview](preview.png) 
![animated_rpeview](preview.gif) 

# Information:

- Designed for macOS 10.12 and up   
- cleanHUD is a MacForge plugin that gives you a clean minimal volume/brightness HUD in macOS styled in 2 possible ways
- Author: [w0lfschild](https://github.com/w0lfschild)

# Settings

The avalible settings are:

- `macOSStyle` - `bool` 
- `useCustomColor` - `bool`
- `sliderColor` - `hex string`
- `iconColor` - `hex string`

Example: 

```
defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist macOSStyle -bool true
defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist useCustomColor -bool true
defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist sliderColor -string f5ad42
defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist iconColor -string f5426f
```

# Installation:

1. Download [MacForge](https://github.com/w0lfschild/app_updates/raw/master/MacForge/MacForge.zip)
2. Install [cleanHUD](https://www.macenhance.com/mflink?macforge://github.com/w0lfschild/myRepo/raw/master/myPaidRepo/org.w0lf.cleanHUD) in MacForge
