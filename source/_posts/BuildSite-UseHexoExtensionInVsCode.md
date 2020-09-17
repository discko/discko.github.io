---
title: 在VS Code中使用Hexo的预览插件
tags:
  - 建站
  - hexo
  - 插件
categories: 网站建设
mathjax: true
date: 2020-08-11 13:18:45
---

在写hexo的md时，如果要预览文章，要么是通过`hexo s`开启一个服务，在浏览器中本地浏览，要么就直接通过`hexo d -g`发布到服务器上。前者总是占用着本地资源，而且三天两头才写一篇文章的话，很容易会忘记首先要打开`hexo s`；后者的话，就更麻烦了。为了解决这个问题，在VS Code的插件市场中苦苦寻觅，终于找到了一个还算不错的办法。
<!--more-->
之前一直在搜索的是hexo的插件，后来转念一想，我要在本地预览的无非是markdown文件，为什么不能直接使用markdown preview类型的插件呢。我的要求很明确：

* 实时预览，或通过最简单的命令异步预览  
* 支持主要的markdown语法，最起码不影响文章结构  
* 支持mathjax  
* pandoc渲染支持，因为hexo我已经换成用pandoc进行render了，希望本地预览与线上实际效果是一致的

于是在vs code的extension marketplace中以markdown preview为关键词进行搜索，很快一个基本符合我要求的插件就引入眼帘：markdown-preview-enhanced  
VS code的插件安装很简单，点击install按钮即可。安装完成后，打开该插件的settings。

# 自动打开预览
首先需要勾选下面这个选项，这样当打开md文件时，将会自动开启预览窗口。  
- [x] Automatically show preview of markdown being edited.
当然要是不嫌麻烦，也可以直接修改vs code的settings.json文件
```json
"markdown-preview-enhanced.automaticallyShowPreviewOfMarkdownBeingEdited": true
```
这时，就可以打开任意md文件，以启动预览窗口。（可能需要重启vs code）

# 调整renderer
然后根据数学公式使用的渲染器考量是否需要修改。找到Math Rendering Options，默认采用的是KaTex。由于我Hexo中使用的是MathJax，因此这里改成了MathJax。
```json
"markdown-preview-enhanced.mathRenderingOption": "MathJax"
```

# 替换renderer为pandoc
如果使用了pandoc作为渲染器的话，那么就需要修改以下内容，以求md preview中的效果和最终效果尽量一致。   
这里需要修改1~2个地方。首先将设置拉到最下面，倒数第3个选项，勾选Use Pandoc Parser，以替代原本的markdown-it。
```json
"markdown-preview-enhanced.pandocPath": "pandoc"
```
然后确认Pandoc Path是否正确。如果你的Pandoc是全局安装的，那么这里直接写"pandoc"就可以了。
```json
"markdown-preview-enhanced.pandocPath": "pandoc"
```
pandoc的安装很简单，在[Pandoc官网](https://www.pandoc.org/installing.html)下载和系统一致的版本，重启VS code即可。


# 调整界面样式
接着，打开任意一个md文件，在预览中观察是否有不舒服的地方（比如我的vs code主题是dark的，但是markdown preview仍然是亮色主题）。这里有几个可以修改的。  
## 主要主题
在pandocPath设置下一个，可以修改Preview Theme。这里我选用的是atom-dark：
```json
"markdown-preview-enhanced.previewTheme": "atom-dark.css"
```
当然，要是有能力的话，也可以直接修改该css文件的内容（我是真不会），该文件位于：`~/.vscode/extensions/shd101wyy.markdown-preview-enhanced-0.5.12/node_modules/@shd101wyy/mume/styles/prism_theme/src`。插件版本可能略有差异，如果确定要去修改的话，自己注意好路径。
## 代码块主题
修改过Preview Theme后，发现使用```包裹起来的代码块背景颜色仍然是白色的，为此，去修改设置。该设置位于插件设置的头部（第6个），Code Block Theme，选择与Preview Theme相协调的配色，或使用auto.css由插件自己选择即可。
```json
"markdown-preview-enhanced.codeBlockTheme": "auto.css"
```
## mermaid主题
如果使用了mermaid流程图的话，可以在这里修改其主题配色，位于Math Rendering Option的下一个，Mermaid Theme。
```json
"markdown-preview-enhanced.mermaidTheme": "default"
```