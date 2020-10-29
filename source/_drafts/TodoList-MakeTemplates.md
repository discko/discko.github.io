---
title: TodoList-创建前后端的模板并尝试发布
date: 2020-10-29 20:11:18
tags: [Spring Boot, Modularization, Vue3]
categories: TodoList
mathjax: false
---

# 本文目标
* 建立前后端开发环境（前端`Vue3`，后端`Spring Boot`），并且区分本地、开发、测试、生产环境。
* 使用GitHub Actions自动化CI和CD
* 前后端分离，并且完成时，前端可以访问后端API
<!--more-->

# 前情提要
在[上一篇](/2020/10/14/TodoList-Starting/)中，我们搭建了一个测试环境去尝试使用了GitHub Actions的工作流去集成和发布我们的后端程序，


[使用Webhook执行GitHub Actions的工作流](https://p3terx.com/archives/github-actions-manual-trigger.html#toc_2)