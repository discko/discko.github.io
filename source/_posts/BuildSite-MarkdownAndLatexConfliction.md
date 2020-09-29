---
title: Markdown与Latex的冲突（'&#95;'下划线字符）
tags:
  - Markdown
  - Latex
categories: 网站建设
mathjax: true
date: 2020-09-29 11:40:30
---
记录Markdown与Latex关于下划线`'_'`冲突的解决办法
<!--more-->
在写[LC-0452-用最少数量的箭引爆气球](2020/09/29/LC-0452-MinimumNumberOfArrowsToBurstBalloons/)的时候，发布之后发现页面板式与我设想的很不一样：  
![错误的板式](ProblemView.png)  

查看了一下generate之后的html（不是线上的），大致是这样的：
```html
即满足$C<em>\text{start} \le T</em>\text{end}$，则表示可以被一支箭引爆
```
而原来的Markdown是：  
```markdown
即满足$C_\text{start} \le T_\text{end}$，则表示可以被一支箭引爆
```
也就是里面多了一些`<em>`标签，而且出现在了原本是`_`的位置。  


那么就很明白了，这个`_`下划线字符本来是Latex中的下标控制符的，却先被Markdown识别了，而且在这句话中有两个`_`，正好一开一合构成了`<em>`的语法。  

同时，也算是明白了hexo是如何generate的了。hexo只是将markdown进行翻译，变成了html，保留了其中的Latex语句（也就是`$`及其之间的）。在浏览器加载该html的时候，利用某些js将Latex语句在加载时转换为`<mjx-container>`标签并显示。

那么，解决这个冲突就很简单了，让Markdown选择性失明就行了。将`_`改为`\_`即可，即：
```markdown
即满足 $ C\_\text{start} \le T\_\text{end} $，则表示可以被一支箭引爆
```

最终显示效果如下：  
![修改后的板式](SolvedView.png)  


PS：在发布本文过程中，又发现了一个Markdown的冲突，在标题开头中，我原本写的是：  
![错误的标题写法](WrongTitle.png)
结果在从draft到post的publish的时候，报错了：  
![错误信息](WrongTitleErrorMsg.png)
那一定是那个`'_'`这个符号又触动了Markdown的什么神经，没办法，再转义一下咯，使用HTML字符实体进行转义就可以了，这个符号是ASCII中的第95个，所以直接`&#95;`就可以了。  
![正确的标题写法](CorrectTitle.png)

