<p align="center">
  <img src="docs/cover.png" width="100%" alt="GlassGloss 使用示意图：选中英文，按快捷键，在悬浮窗里查看中文译文。">
</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b> · <a href="https://github.com/haotian049-cpu/glassgloss/releases/latest">发布版本</a>
</p>

# GlassGloss

**选中英文，按 ⌃⌥⌘空格，中文就在原处。**

读论文、PDF 或技术文档时，GlassGloss 把译文放在原文旁边的 macOS 原生液态玻璃悬浮窗里。短句只占几行，长文在窗内滚动，按 **Esc** 回到阅读。

- **选中即译**。兼容的阅读器、浏览器和编辑器里，选中文字即可发起翻译。
- **本机离线**。使用 Apple 已下载的英文和简体中文模型，无需账号或 API Key，不上传选区，也不保存翻译历史。
- **随内容变化的浮窗**。原文、译文都能选中，也可以一键拷贝整段译文。

## 安装

**[下载完整安装包](https://github.com/haotian049-cpu/glassgloss/releases/latest)** · Apple 芯片 · macOS 26.4+

1. 下载 ZIP，解压后双击 **Install.command**。也可以在解压后的目录运行 `bash install.sh`。安装包已预编译，写入当前用户的资源库，无需 sudo。
2. 查单词时，退出并重新打开「词典」，在 **词典 → 设置**勾选新来源。此后可在词典 App 搜索，也可在支持的 App 里用原生「查询」。
3. 翻译整句时，在 **系统设置 → 通用 → 语言与地区 → 翻译语言**下载英语和简体中文。选中原文，按 **Control + Option + Command + 空格**。首次若被询问权限，有「选择 App」时只授权需要的阅读器。

发布包采用本地签名，**未获 Apple 公证**。如果当前系统拦截预编译服务，可使用下方的源码安装方式。 [Apple 的语言包说明](https://support.apple.com/zh-cn/guide/mac-help/mchldd8b3c15/mac) · [Apple 的权限说明](https://support.apple.com/en-us/149699)

## 包含什么

| 用途 | 内容 |
| --- | --- |
| 查词与专业术语 | ECDICT 简明英汉字典、Google AI、MDN 和 Python 双语术语库，接入 macOS 原生词典。 |
| 翻译句子和段落 | GlassGloss 本机离线英译中悬浮窗。 |

安装会跳过同名或同 ID 的现有词库。数据保留各自的[许可证和出处](docs/THIRD-PARTY.md)。扫描 PDF 需要先有可选中文字。有些阅读器需要服务代为复制，此时会更新剪贴板。

## 按需安装与卸载

- `bash install.sh translate` 只安装翻译。
- `bash install.sh dictionaries` 只安装完整 ZIP 里的四套词库。
- `bash install.sh uninstall` 卸载翻译服务和登录启动项。词库可在 `~/Library/Dictionaries/` 单独管理。

如需从源码安装，先运行 `xcode-select --install` 安装 Apple 命令行工具，再运行：

~~~sh
git clone https://github.com/haotian049-cpu/glassgloss.git
cd glassgloss
bash install.sh source
~~~

只编译、不安装可用 `bash install.sh build`。

如果它帮你读文档少切几次窗口，欢迎点个 Star。遇到兼容性问题，可以在 Issues 里附上 macOS 版本、阅读器名称和一段可公开的复现文本。

[MIT](LICENSE)
