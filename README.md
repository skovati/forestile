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

```
$ forestile -h
Usage: forestile [options...]

  -h              Print this help message and exit.
  -version        Print the version number and exit.

  The following commands may also be sent to forestile at runtime:

  -main-location  Set the initial location of the main area in the
                  layout. (Default left)
  -main-count     Set the initial number of views in the main area of the
                  layout. (Default 1)
  -main-ratio     Set the initial ratio of main area to total layout
                  area. (Default: 0.6)
  -width-ratio    Set the ratio of the usable area width of the screen.
                  (Default: 1.0)

  See forestile(1) man page for more documentation.
```

## Contributing

See [CONTRIBUTING.md]

Much thanks to [novakane](https://sr.ht/~novakane/rivercarro/), as this project layout was heavily derived from their project.

## License

forestile is licensed under the [GNU General Public License v3.0 or later]

Files in `common/` and `protocol/` directories are released under various
licenses by various parties. You should refer to the copyright block of each
files for the licensing information.

[river]: https://github.com/ifreund/river
[zig]: https://ziglang.org/download/
[contributing.md]: CONTRIBUTING.md
[isaac freund]: https://github.com/ifreund
[gnu general public license v3.0 or later]: LICENSE
