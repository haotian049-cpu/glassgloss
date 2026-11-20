<p align="center">
  <img src="docs/cover.png" width="100%" alt="GlassGloss workflow illustration. Select an English sentence to see its Chinese translation in a floating glass panel.">
</p>

<p align="center">
  <b>English</b> · <a href="README.zh-CN.md">简体中文</a> · <a href="https://github.com/haotian049-cpu/glassgloss/releases/latest">Release</a>
</p>

# GlassGloss

**Select English. Press ⌃⌥⌘Space. Keep reading in Chinese.**

GlassGloss brings English → Simplified Chinese translation to the page you're reading. A native macOS Liquid Glass panel opens beside the text. A sentence takes up a few lines. A long passage scrolls in place. **Esc** closes it.

- **One shortcut** reads the selection in a compatible browser, PDF reader, or editor.
- **On-device** translation uses Apple's installed models. No account, API key, upload, or translation history.
- **Compact by design** with a panel that sizes itself to the text, selectable source and translation, and one-click copy.

## Install

Requires **Apple silicon**, **macOS 26.4 or later**, and current Apple Command Line Tools. If the tools are missing, run `xcode-select --install`.

~~~sh
git clone https://github.com/haotian049-cpu/glassgloss.git
cd glassgloss
bash install.sh
~~~

1. Download English and Simplified Chinese in **System Settings → General → Language & Region → Translation Languages**. Apple provides the models, which run locally afterward. [Apple's translation guide](https://support.apple.com/en-us/guide/mac-help/mchldd8b3c15/mac)
2. Select English text and press **Control + Option + Command + Space**. If macOS asks for permission to read the selection or send Copy to your reader, open the settings from the panel and approve **GlassGloss**. If you see **Choose Apps**, authorize only the readers you use. The service lives at `~/Library/Services/GlassGloss.service`. [Apple's permission guide](https://support.apple.com/en-us/149699)

A scanned page needs a selectable text layer. When a reader does not expose its selection directly, GlassGloss uses its Copy command and updates the clipboard.

## Uninstall or build

Run `bash install.sh uninstall` to remove the service and per-user startup entry. You can remove any permission you granted in System Settings.

Run `bash install.sh build` to compile and sign the local bundle in `.build/` without installing it.

## Feedback

If GlassGloss helps you stay on the page, a star helps other Mac readers find it. For a selection or rendering issue, include the macOS version, reader name, and a short public example.

[MIT](LICENSE)
