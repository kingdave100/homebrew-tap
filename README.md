# Homebrew tap

Homebrew packages for [Equicord](https://github.com/Equicord) on macOS.

| Package | Description |
| --- | --- |
| `discord+equicord` | Discord with Equicord and OpenAsar installed. |
| `equilotl-cli` | Command-line installer for Equicord. Installed automatically with the cask. |

## Install

To install Discord with Equicord and OpenAsar:

```sh
brew install --cask kingdave100/tap/discord+equicord
```

The cask conflicts with the standard `discord` cask. If you already have it installed, uninstall it first with `brew uninstall --cask discord`.

To install only the command-line tool:

```sh
brew install kingdave100/tap/equilotl-cli
```

Homebrew documentation: [docs.brew.sh](https://docs.brew.sh).
