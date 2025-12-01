# One-liners for enabling remote access on macOS

Remote Login (SSH):

```sh
sudo systemsetup -setremotelogin on
```

Remote Desktop (Screen Sharing/VNC):

```sh
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -allowAccessFor -allUsers -privs -all -restart -agent -menu
```

Or a simpler version that just enables screen sharing:

```sh
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

Both together (for a fresh install bootstrap):

## Enable SSH

```sh
sudo systemsetup -setremotelogin on
```

## Enable Screen Sharing (VNC)

```sh
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

> Note: On newer macOS versions (Ventura+), you may also need to grant permissions through System Settings > General > Sharing, or use:

## Full Remote Management with all privileges

```sh
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -allowAccessFor -allUsers \
  -privs -all \
  -restart -agent -menu
```
