# forestile

A _slightly_ modified version of the _rivertile_ layout generator for
**[river]**

Compared to _rivertile_, _forestile_ adds:
- runtime mutatation of padding

## Building

Same requirements as **[river]**

```sh
git submodule update --init
zig build --prefix ~/.local
```

## Usage

Works exactly as _rivertile_, you can just replace _rivertile_ name by
_forestile_ in your config, and read `forestile(1)` man page for commands
specific to forestile.

`e.g.` In your **river** init (usually `$XDG_CONFIG_HOME/river/init`)

```sh
# Mod+H and Mod+L to decrease/increase the main ratio of forestile
riverctl map normal $mod H send-layout-cmd forestile "main-ratio -0.05"
riverctl map normal $mod L send-layout-cmd forestile "main-ratio +0.05"

# Mod+Shift+H and Mod+Shift+L to increment/decrement the main count of forestile
riverctl map normal $mod+Shift H send-layout-cmd forestile "main-count +1"
riverctl map normal $mod+Shift L send-layout-cmd forestile "main-count -1"

# Mod+{Up,Right,Down,Left} to change layout orientation
riverctl map normal $mod Up    send-layout-cmd forestile "main-location top"
riverctl map normal $mod Right send-layout-cmd forestile "main-location right"
riverctl map normal $mod Down  send-layout-cmd forestile "main-location bottom"
riverctl map normal $mod Left  send-layout-cmd forestile "main-location left"

# Add other forestile commands the same way with the keybinds you'd like.
# e.g.
riverctl map normal $mod G send-layout-cmd forestile "padding toggle"

# Set and exec into the default layout generator, forestile.
# River will send the process group of the init executable SIGTERM on exit.
riverctl default-layout forestile
forestile
```

### Command line options
See [forestile(1)](doc/forestile.md)

## Thanks

Much thanks to [novakane](https://sr.ht/~novakane/rivercarro/), as this project layout was heavily derived from their project.

Additionally, thanks to [isaac freund], the [river] project, and the [zig] lang.

## License

forestile is licensed under the [GNU General Public License v3.0 or later](LICENSE)

Files in `common/` and `protocol/` directories are released under various
licenses by various parties. You should refer to the copyright block of each
files for the licensing information.

[river]: https://github.com/ifreund/river
[zig]: https://ziglang.org/download/
[isaac freund]: https://github.com/ifreund
