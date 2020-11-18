---
title: TodoList-创建前后端的模板并尝试发布·前端
tags:
  - Modularization
  - Vue3
  - TypeScript
categories:
  - TodoList
mathjax: false
date: 2020-11-03 21:06:48
---


# 本文目标
* 建立后端开发环境（`Vue3`），并且区分本地、开发、测试、生产环境。
* 使用GitHub Actions自动化CI和CD
* 前后端分离，并且完成时，前端可以访问后端API
<!--more-->

# 写在前面
因为我以前也没怎么写过前端，加上最近Vue.js 3.0正好发布了，所以本文更多的是一个记录，记录我是如何一步步以应用为目的去学习Vue3的。  
原本是打算在WebStorm IDE里进行TodoList-frontend的开发的。但可能是版本或者环境有问题，自动生成的代码没有任何添加，就会出现下面的问题。  
![WebStormErrorInfo](WebStormErrorInfo.png)  
虽然不影响运行，这个也可以用@ts-ignore去压制，但对于有一点代码洁癖的人看着总归有点难受。因此最终还是换回了VS Code。
本文的代码见[这里](https://github.com/discko/TodoList-frontend/tree/base)

# Vue环境创建

官方已经提供了很方便的一键式构建工具`@vue/cli`（即原来的`vue-cli`，所以我们安装就可以了，已经安装过的只需要升个级到不低于v4.5即可。
```bash
#upgrade
vue upgrade --next
#install
npm i @vue/cli -g 
```
然后大致做了这些选择：  
![VueStartupConfig](VueStartupConfig.png)  
没什么特别要注意的，根据我自己的需要选择了Vue3和TypeScript。

初始化好的项目结构是这样的：  
![DirectoryStructure](DirectoryStructure.png)  
相信这个目录结构还是很清晰的。应该不用多讲吧。  

然后我们开始对其进行环境改造。

# 环境改造
## 环境配置文件
由于我们需要在不同环境中使用不同的配置，所以首先先将配置大致定义一下，后面再来完善。  
新建文件夹`static/config`用来存放相关配置。  
建立接口文件`profileConfig.ts`用来描述不同环境下的配置文件的格式。
```ts
//@profileConfig.ts
interface ProfiledConfig {
  profileInfo: ProfileInfo;
  netInfo: NetInfo;
}
interface ProfileInfo {
  profileName: string;
  serial: string;
}
interface NetInfo {
  baseUrl: string;
  version: string;
}
```
然后local、dev、test、product环境下的配置分别放在同目录的`profile-local.ts`、`profile-dev.ts`、`profile-testing.ts`、`profile-production.ts`文件中。以local环境为例：
```ts
import ProfiledConfig from './profiledConfig'
const profile: ProfiledConfig = {
  profileInfo: {
    profileName: 'local',
    serial: '0.0.1'
  },
  netInfo: {
    baseUrl: 'http://localhost:8082',
    version: ''
  }
}
export default profile
```
## 载入配置文件
由于在某个环境下，只有一个配置文件是有效的，其他都是没有用的，所以我们需要有选择地载入配置文件。为此，在`utils`目录下新建`global.ts`作为全局配置文件载入工具。  
```ts
import ProfiledConfig from '@/static/config/profiledConfig'
class Global {
  env: string
  profiledConfig: ProfiledConfig | undefined
  constructor () {
    this.env = process.env.NODE_ENV ? process.env.NODE_ENV : 'dev'
  }
  public getProfiledConfig (): ProfiledConfig {
    return this.profiledConfig!
  }
  public async init () {
    console.log('in init')
    import('../static/config/' + `profile-${this.env}`).then(module => {
      this.profiledConfig = module.default
    })
  }
}
export default new Global()
```
然后在`main.ts`中使用`init()`函数即可。
```ts
import { createApp } from 'vue'
import global from '@/utils/global'
import appVue from './App.vue'
const app = createApp(appVue);
(async () => {
  await global.init()
  const router = (await import('./router')).default
  const store = (await import('./store')).default
  app.use(router)
    .use(store)
    .mount('#app')
})()
```
这里需要注意，由于`router`中会引用各个component，而各component中必然会存在可能会使用或间接使用profile的模块（比如网络模块需要使用profile中的`baseUrl`），所以必须保证`global.init()`被首先执行完成，然后再加载各个component。因此，`router`等模块也只能在`init()`之后通过`import()`来异步加载。

## CI时环境可选
那么问题来了，怎么切换环境呢？`java`环境通过`maven`去build或package的话，可以通过`-P`指令去指定profile，而在`node`环境中呢？  
`node`中有一个约定的环境变量`NODE_ENV`，在程序中可通过`process.env.NODE_ENV`去访问。那么这么一来，只需要在启动时传入环境变量NODE_ENV就可以了。为此，我们改造`package.json`中的`scripts`：  
```json
{
  "scripts": {
    "serve": "export NODE_ENV=local && vue-cli-service serve ",
    "build": "export NODE_ENV=production && vue-cli-service build",
    "lint": "vue-cli-service lint",
    "build:dev": "export NODE_ENV=dev && vue-cli-service build",
    "build:local": "export NODE_ENV=local && vue-cli-service build",
    "build:product": "export NODE_ENV=production && vue-cli-service build",
    "build:test": "export NODE_ENV=testing && vue-cli-service build",
    "serve:build": "export NODE_ENV=local && vue-cli-service serve ",
    "serve:dev": "export NODE_ENV=dev && vue-cli-service serve ",
    "serve:product": "export NODE_ENV=production && vue-cli-service serve ",
    "serve:test": "export NODE_ENV=testing && vue-cli-service serve "
  },
}
```
其中`serve`命令默认为`local`环境，`build`命令默认为`production环境`。这里有两点需要说明一下。  

* 生产环境`export NODE_ENV=production`而不是`product`是为了与`vue`或者说`node`统一。因为`node`依赖于`process.env.NODE_ENV`来判断当前环境。而`vue`在发现当前环境为一字不差的`production`时，才会进行生产环境的编译打包工作（比如为js和css文件名加上hash等，当然这个也是可配置的），否则只会进行`development`编译打包，同时会在console中输出当前位开发环境的字样。  
* 测试环境`export NODE_ENV=testing`而不是`test`这个是因为一些设置屏蔽了`*test.ts`之类文件的打包，如果选择test环境同时使用`profile-test.ts`作为该环境的配置文件的话，会在加载时提示找不到该文件（因为没有被webpack进来）。为此，将`profile-test.ts`改名为`profile-testing.ts`。由于在`global.ts`的`init()`函数中是直接将`profile-`字符串与`process.env.NODE_ENV`拼接得到配置文件名的，所以`export NODE_ENV`时也修改了这个环境变量为`testing`。  

# 添加UI框架
常用的UI框架有Ant Designer、Element UI等，目前这些UI框架也都开始对Vue3进行适配了。由于我之前使用过ElementUI，所以这里就还是使用同系列的专门为Vue3开发的[Element Plus](https://github.com/element-plus/element-plus)。  
使用`npm i -S element-plus`就可以开始使用了。  

## 添加全局函数
在`main.ts`中添加import：
```ts
import { createApp } from 'vue'
// import following 2 items
import ElementPlus from 'element-plus'
import 'element-plus/lib/theme-chalk/index.css'

import global from '@/utils/global'
import appVue from './App.vue'

const app = createApp(appVue)
// add plugin to app
app.use(ElementPlus);

(async () => {
  await global.init()
  const router = (await import('./router')).default
  const store = (await import('./store')).default
  app.use(router)
    .use(store)
    .mount('#app')
})()
```
这样，在`vue`文件中，就可以使用`this.$message`、`this.$msgbox`、`this.$alert`、`this.$confirm`、`this.$prompt`、`this.$notify`来弹出相关的消息窗口了。

## 修复Element-Plus（alpha.14）的2个小问题
目前的Element-Plus版本（1.0.1-alpha.14）还有2个小问题：

* 第一个，由于Vue 3.0中不再有Vue对象，所以原本向Vue的原型链中追加`$message`等方法的办法无法使用了，只能通过`app.config.globalProperties.$message = Message`这样的方式向`this`中添加`$message`方法。但这样一来，由于是动态添加的方法，对于大多数IDE或者`Vue`的插件（我用的是`Vetur`），就无法进行代码提示了。而且在typescript编译时，可能也会提示该方法不在`this`对象中。
* 第二个，`Message`的ts声明与实现不一致。对于上一个问题，我们还能够在`vue`文件中使用`import { Message } from 'element-plus`后，直接使用`Message(text:string)`来弹出消息提示。这个是ok的。但是对于Message.success等函数，写的时候可以写，但是在运行时会提示不存在这个函数。  
![SuccessNotFunction](SuccessNotFunction.png)  

如果第一个问题还可以用`// eslint-disable-next-line`和`// @ts-ignore`的组合来压制的话，第二个问题就无法解决了。第二个问题我在该项目的仓库中提了个issue，见[这里](https://github.com/element-plus/element-plus/issues/592)，作者说可以通过`import { Message } from 'element-plus/lib/message`而不是通过`import { Message } from 'element-plus`引入`Message`，这样就可以`Message.success`了。但即使通过`// @ts-ignore`跳过编译的错误提示后，运行时依然会提示找不到`Message`的`success`函数。截止到本文发布，我使用最新的`element-plus@1.0.1-alpha.15`版本，该问题依然没有解决。不过原作者也说了，目前的第一重要的工作是migration，所以在发布后再来逐步纠正这些声明和细节问题。

为此，我写了一个扩展模块来辅助完成这个工作。  
这个扩展模块详见[这里](https://github.com/discko/TodoList-frontend/blob/base/src/utils/ElementPlusExtension.ts)。我放在了`utils/ElementPlusExtension.ts`，是前文`global.ts`的邻居。
然后最后使用时，直接import进来就可以了。

```ts
// in SomeView.vue
<script lang='ts'>
import { defineComponent, onMounted } from 'vue'
import ElementPlus, { epMessage, epMsgBox, epNotify } from '@/utils/ElementPlusExtension'

export default defineComponent({
  setup () {
    onMounted(() => {
      // use module's default
      ElementPlus.message.success('show message A')
      // use module's default with 'this'
      this.ElementPlus.msgbox({
        title: 'message box',
        message: 'message from this.ElementPlus'
      })
      // use export component in module
      this.epNotify.warning('notification from this')
    })
    return {
      ElementPlus, // append module's default onto 'this'
      epMessage,   // append export components onto 'this'
      epMsgBox,
      epNotify
    }
  }
})
</script>
```
如果在setup中导出这些对象的话，就可以在`this`中引用它们了。  

# 一些其他的工作
到上面为止，整个环境工作就准备的差不多了。但是除此之外，我还准备了网络api请求相关的东西，是简单封装了`axios`库的一些应用，就不一一列举了，而这一部分会在后面增加对不同状态码的统一管理、对权限与认证相关的操作等等。最终的代码都可以参见我的[GitHub仓库`TodoList-frontend`的`base`tag](https://github.com/discko/TodoList-frontend/tree/base)。

# 最终的效果
将程序发布到服务器之后，最终的master的运行效果如下：
![DemoFinalView](DemoFinalView.png)