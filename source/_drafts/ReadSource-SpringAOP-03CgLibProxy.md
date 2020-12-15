---
title: 阅读源码-SpringAOP-03CgLibProxy
date: 2020-12-14 09:28:32
tags: [源码, Spring, AOP]
categories: [阅读源码]
mathjax: false
---
[前一篇文章](/2020/12/12/ReadSource-SpringAOP-02JdkDynamicProxy/)主要分析了一下JdkDynamicProxy的调用方法和生成过程。本文将切换到CG Lib的动态代理，来看看有没有什么不一样的地方。
<!--more-->
# 自己写一个代理（通过继承）
前一篇文章使用Jdk Dynamic Proxy，其核心是获取目标对象的接口，然后根据这些接口，实现所有接口中的方法，并在这些方法中调用目标对象的同名方法，并在调用前后做一些处理。由于使用了InvocationHandler，所以其核心是通过反射来执行原被代理的目标对象的方法。代理对象和目标对象两者是平级的，都是某个或某些接口的实现。  
在较早版本的java中，运行时的反射效率比较低，而且JdkDynamicProxy只能代理接口中的方法，所以CgLib换成了另外一个思路。  
除了使用接口来获得某个对象的方法外，还可以使用继承。CgLib就是这样，创建一个新的类，并继承自目标对象。然后覆盖目标方法，在其中调用父对象（也就是目标对象类）的同名方法，并在前后增加一些切面处理。大概就是下面这样：
```java
// 目标类
class Target{
    void method(){System.out.println("in target method");}
}
// 代理类
class Proxy extends Target{
    @Override
    void method(){
        System.out.println("in proxy method");
        super.method();
    }
}
// 测试类
class Main{
    public static void main(String[] args){
        Target target = new Prox();
        target.method();
    }
}
```
这样就完成了代理。
最终输出结果如下：
> 
# 使用CgLib生成代理并调用
这次为了简单，使用了public static void main去调用CgLib直接生成代理并调用，来看看其执行过程是什么样子的。
## 编写代码并执行
创建一个目标对象`TargetObject`，为其增加2个方法：
```java
public class TargetObject {
    void sayHi(String to){
        System.out.println("Hi, "+to+"!");
    }
    String whoAreYou(String from){
        return String.format("Hi %s, it's WuDi", from);
    }
}
```
创建一个方法拦截器，继承自`MethodInterceptor`：
```java
package space.wudi.readsourceaop.gclibproxy.proxy;
import org.springframework.cglib.proxy.MethodInterceptor;
import org.springframework.cglib.proxy.MethodProxy;
import java.lang.reflect.Method;
public class MyMethodInterceptor implements MethodInterceptor {
    private final String id;
    MyMethodInterceptor(String id){
        this.id = id;
    }
    @Override
    public Object intercept(Object sub, Method method, Object[] args, MethodProxy methodProxy) throws Throwable {
        System.out.println("before from "+id);
        Object rtVal = methodProxy.invokeSuper(sub, args);
        System.out.println("after from "+id+" with rtVal: "+rtVal);
        return rtVal;
    }
}
```
创建代理对象：
```java
package space.wudi.readsourceaop.gclibproxy.proxy;
import org.springframework.cglib.core.DebuggingClassWriter;
import org.springframework.cglib.proxy.Callback;
import org.springframework.cglib.proxy.Enhancer;
import space.wudi.readsourceaop.gclibproxy.TargetObject;
public class ProxyCreator {
    final static String SAVE_PATH = "/Users/wudi/program/javaworkspace/readsource/readsource-aop/target";
    public static TargetObject createByNormalInterceptor(){
        System.setProperty(DebuggingClassWriter.DEBUG_LOCATION_PROPERTY, SAVE_PATH);
        Enhancer enhancer = new Enhancer();
        enhancer.setSuperclass(TargetObject.class);
        enhancer.setCallbacks(new Callback[]{new MyMethodInterceptor("a"), new MyMethodInterceptor("b")});
        //如果method名字包含"say"则使用callbacks[0]否则使用callbacks[1]
        enhancer.setCallbackFilter(method -> method.getName().contains("say") ? 0 : 1);
        return (TargetObject)enhancer.create();
    }
}
```
调用：
```java
package space.wudi.readsourceaop.gclibproxy;
import space.wudi.readsourceaop.gclibproxy.proxy.ProxyCreator;
public class TestCgLib {
    public static void main(String[] args) {
        TargetObject to = ProxyCreator.createByNormalInterceptor();
        to.sayHi("WuDi");
        String response = to.whoAreYou("stranger");
        System.out.println(response);
    }
}
```
最终在控制台可以看到如下输入：  

> before from a  
> Hi, WuDi!  
> after from a with rtVal: null  
> before from b  
> after from b with rtVal: Hi stranger, it's WuDi  
> Hi stranger, it's WuDi   

## 调用过程
那么调用过程是怎样的呢？  
### CG代理对象中的调用
可以想见，实际调用的并非`TargetObject`，而应该是其代理对象。将生成的代理类的class文件反编译后，可以看到它继承自`TargetObject`：
```java
public class TargetObject$$EnhancerByCGLIB$$4b9713b2 extends TargetObject implements Factory 
```
然后是继承的两个方法，由于一个有返回值，一个没有返回值，所以后半部分不太一样
```java
// 调用父类sayHi方法
final void CGLIB$sayHi$0(String var1) {
    super.sayHi(var1);
}
// 代理父类sayHi方法
final void sayHi(String var1) {
    MethodInterceptor var10000 = this.CGLIB$CALLBACK_0;
    if (this.CGLIB$CALLBACK_0 == null) {
        CGLIB$BIND_CALLBACKS(this);
        var10000 = this.CGLIB$CALLBACK_0;
    }
    if (var10000 != null) {
        var10000.intercept(this, CGLIB$sayHi$0$Method, new Object[]{var1}, CGLIB$sayHi$0$Proxy);
    } else {
        super.sayHi(var1);
    }
}
//调用父类whoAreYou方法
final String CGLIB$whoAreYou$1(String var1) {
    return super.whoAreYou(var1);
}
//代理父类whoAreYou方法
final String whoAreYou(String var1) {
    MethodInterceptor var10000 = this.CGLIB$CALLBACK_1;
    if (this.CGLIB$CALLBACK_1 == null) {
        CGLIB$BIND_CALLBACKS(this);
        var10000 = this.CGLIB$CALLBACK_1;
    }
    return var10000 != null ? (String)var10000.intercept(this, CGLIB$whoAreYou$1$Method, new Object[]{var1}, CGLIB$whoAreYou$1$Proxy) : super.whoAreYou(var1);
}
```
两个方法的前半部分都是获取本方法需要使用的方法拦截器，如果获取失败了，就通过懒加载，将callbacks列表绑定到`this.CGLIB$CALLBACK_n`上 ，然后调用方法拦截器的`intercept()`方法就可以了。而这个方法，就是我们在`MyMethodInterceptor`中实现的那个方法：
```java
public Object intercept(Object sub, Method method, Object[] args, MethodProxy methodProxy) throws Throwable {
    System.out.println("before from "+id);
    Object rtVal = methodProxy.invokeSuper(sub, args);
    System.out.println("after from "+id+" with rtVal: "+rtVal);
    return rtVal;
}
```
### 回到方法拦截器
这个方法的4个参数先了解一下。  

* Object sub：增强后的对象（也即代理对象）
* Method method：需要调用的目标对象中的方法
* Object[] args：调用方法的参数
* MethodProxy methodProxy：一个方法代理器

前三个应该问题不大，我们先看看`MethodProxy`是如何生成的。  
全局有一个static方法块，里面调用了`CGLIB$STATICHOOK1()`，而这个函数里面对对这个代理对象中的所有奇怪属性进行了初始化。对于两个MethodProxy分别如下：
```java
// TargetObject$$EnhancerByCGLIB$$4b9713b2.class
static void CGLIB$STATICHOOK1() {
    // var0是代理对象的class
    Class var0 = Class.forName("space.wudi.readsourceaop.gclibproxy.TargetObject$$EnhancerByCGLIB$$4b9713b2");
    // 按道理var1是目标对象的class，但不清楚这里为什么没有任何定义，运行来看var1确实在MethodProxy处是有值的。
    Class var1;
    CGLIB$sayHi$0$Proxy = MethodProxy.create(var1, var0, "(Ljava/lang/String;)V", "sayHi", "CGLIB$sayHi$0");
    CGLIB$whoAreYou$1$Proxy = MethodProxy.create(var1, var0, "(Ljava/lang/String;)Ljava/lang/String;", "whoAreYou", "CGLIB$whoAreYou$1");
}
```
这个`MethodProxy.create()`以及MethodProxy中的一个内部类CreateInfo在这里：
```java
// org.springframework.cglib.proxy.MethodProxy
public static MethodProxy create(Class c1, Class c2, String desc, String name1, String name2) {
    MethodProxy proxy = new MethodProxy();
    proxy.sig1 = new Signature(name1, desc);
    proxy.sig2 = new Signature(name2, desc);
    proxy.createInfo = new CreateInfo(c1, c2);
    return proxy;
}
private static class CreateInfo {
    Class c1;
    Class c2;
    NamingPolicy namingPolicy;
    GeneratorStrategy strategy;
    boolean attemptLoad;
    public CreateInfo(Class c1, Class c2) {
        this.c1 = c1;
        this.c2 = c2;
        AbstractClassGenerator fromEnhancer = AbstractClassGenerator.getCurrent();
        if (fromEnhancer != null) {
            namingPolicy = fromEnhancer.getNamingPolicy();
            strategy = fromEnhancer.getStrategy();
            attemptLoad = fromEnhancer.getAttemptLoad();
        }
    }
}
```
所以全局变量createInfo中的c1就是目标对象的class，c2就是代理对象的class。而MethodProxy的sig1分别就是继承父类后重写的用来代理的方法（的方法名），sig2就是实际可以调用父类目标方法（的方法名）。

来看看方法代理器MethodProxy是如何工作的。
```java
// org.springframework.cglib.proxy.MethodProxy
public Object invokeSuper(Object obj, Object[] args) throws Throwable {
    try {
        init();
        FastClassInfo fci = fastClassInfo;
        return fci.f2.invoke(fci.i2, obj, args);
    }
    catch (InvocationTargetException e) {
        throw e.getTargetException();
    }
}
```
其中`init()`中初始化了全局变量`fastClassInfo`。然后返回`fci.f2.invoke(fci.i2, obj, args)`的返回值。这句话怎么理解呢？`fci`在`init()`中，通过全局变量`createInfo`创建，

