---
title: 添加小节号
tags:
  - 建站
  - hexo
categories: 网站建设
date: 2020-08-11 12:42:53
mathjax:
---

之前的文章，使用markdown语法的`#`符号可以创建一个`h1`标题，但是该标题没有自动增加序号的功能。为了使文章看起来更加舒心，我们要对hexo进行改造。
<!-- more -->

# 感谢
添加小节号的部分，要感谢下面的文章给予的帮助：  

> 孤傲小黑：[Hexo NexT文章中标题自动编号](https://blog.guaoxiaohei.com/posts/Hexo-Level/)

# 修改导航栏
首先，由于侧边的导航栏（目录）上是有序号的，我们要先将这个序号去掉。  
在`themes/next/_config.yml`中，找到toc节，也就是目录相关，其他的酌情修改，`enable`设为`true`，`number`设为`false`即可。（当然，如果不打算开启导航栏的话，直接将`enable`设为`false`就可以了）
```yml
toc:
  enable: true
  # Automatically add list number to toc.
  number: false
  # If true, all words will placed on next lines if header width longer then sidebar width.
  wrap: false
  # If true, all level of TOC in a post will be displayed, rather than the activated part of it.
  expand_all: false
  # Maximum heading depth of generated toc.
  max_depth: 6
```
# 修改文章正文
然后在`themes/next/scripts/filters`文件夹中，新建一个js脚本，名字任取，我命名为`contentAutoNumber.js`，然后向其中插入代码即可。
```js
'use strict'

let cheerio

hexo.extend.filter.register(
  'after_post_render',
  (data) => {
    if (!cheerio) cheerio = require('cheerio')

    const $ = cheerio.load(data.content, {
      decodeEntities: false,
    })
    const $excerpt = cheerio.load(data.excerpt, {
      decodeEntities: false,
    })

    let elHlist = $('h1,h2,h3,h4,h5,h6')
    // h1到h6的标题编号
    let h1 = '',
      h2 = '',
      h3 = '',
      h4 = '',
      h5 = '',
      h6 = '',
      // 相对于父级的第几个子标题
      h1index = 1,
      h2index = 1,
      h3index = 1,
      h4index = 1,
      h5index = 1,
      h6index = 1

    elHlist.each((i, el) => {
      // 标题编号
      let hindexString = ''
      switch ($(el).get(0).tagName) {
        case 'h1': {
          h2index = 1
          h1 = h1index
          h1index++
          hindexString = h1
          break
        }
        case 'h2': {
          h3index = 1
          h2 = h1 + '.' + h2index
          h2index++
          hindexString = h2
          break
        }
        case 'h3': {
          h4index = 1
          h3 = h2 + '.' + h3index
          h3index++
          hindexString = h3
          break
        }
        case 'h4': {
          h5index = 1
          h4 = h3 + '.' + h4index
          h4index++
          hindexString = h4
          break
        }
        case 'h5': {
          h6index = 1
          h5 = h4 + '.' + h5index
          h5index++
          hindexString = h5
          break
        }
        case 'h6': {
          h6 = h5 + '.' + h6index
          h6index++
          hindexString = h6
          break
        }
      }
      $(el).prepend(
        $('<span />')
          .addClass('post-title-index')
          .text(hindexString + '. ')
      )
    })

    data.content = $.html()
    data.excerpt = $excerpt.html()
  },
  10
)
```
核心代码其实很简单，利用`cheerio`库拿到页面render之后的`h1`到`h6`元素，然后依次遍历。在遍历时，根据不同的h标签进行`switch-case`：
```js
        case 'h2': {
          h3index = 1
          h2 = h1 + '.' + h2index
          h2index++
          hindexString = h2
          break
        }
```
* h3index = 1  
以`h2`为例，当发现该标签为`h2`时，首先恢复`h3`的计数为1（这样，每一个`h2`内的`h3`就都是从1开始重新计数了）
* h2 = h1 + '.' + h2index  
将当前`h1`标签的内容追加"."和h2目前的计数值，如`h1="3", h2index=2`的话，那么`h2="3.2"`
* h2index++  
`h2`计数器自增，为下一个相同`h1`下的`h2`做准备。
* hindexString = h2
将当前生成的`h2`标签值存储于`hindexString`中，方便后面统一写到html中。  

# 更新
这时候，使用`hexo d -g`更新到服务器上就可以了。最终效果同本文。
