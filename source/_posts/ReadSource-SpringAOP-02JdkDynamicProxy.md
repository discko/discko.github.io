---
title: 阅读源码-SpringAOP-02JdkDynamicProxy
tags:
  - 源码
  - Spring
  - AOP
categories:
  - 阅读源码
mathjax: false
date: 2020-12-12 10:28:59
---

上一篇文章，简单介绍了一下AOP的用法，分析了一下新版AOP与旧版本AOP在执行流程上的变化。这篇文章将看看AOP的实现原理之JdkDynamicProxy。
<!--more-->
# 自己实现一个Proxy
## 实现代码
首先根据自己设想的原理来自己实现一个Proxy。
比如我们有这样一个接口和对应的实现：
```java
//space.wudi.readsourceaop.myproxy.UserServiceImpl
package space.wudi.readsourceaop.myproxy;
import space.wudi.readsourceaop.bean.User;
public interface UserService {
    User login(String username) throws Throwable;
}
//space.wudi.readsourceaop.myproxy.UserServiceImpl
package space.wudi.readsourceaop.myproxy;
import space.wudi.readsourceaop.bean.User;
public class UserServiceImpl implements UserService{
    @Override
    public User login(String username) throws Throwable{
        System.out.println("now logging in...");
        return new User(username, "email");
    }
}
```
然后实现代理类：
```java
package space.wudi.readsourceaop.myproxy.proxy;
import space.wudi.readsourceaop.bean.User;
import space.wudi.readsourceaop.myproxy.UserService;
import java.util.Arrays;
public class ProxyUserService implements UserService {
    private UserService targetObject;
    public ProxyUserService(UserService targetObject){
        this.targetObject = targetObject;
    }
    @Override
    public User login(String username) throws Throwable {
        before(username);
        try{
            User rtVal = targetObject.login(username);
            afterReturning(rtVal, username);
            return rtVal;
        }catch(Throwable throwable){
            afterThrow(throwable, username);
        }finally {
            after(username);
        }
        return null;
    }
    private void after(Object...args){
        System.out.println("in After with args: "+Arrays.toString(args));
    }
    private void afterReturning(Object rtVal, Object...args){
        System.out.println("in AfterThrowing with args: " + Arrays.toString(args)+" and rtVal: "+rtVal);
        ((User)rtVal).setEmail("modified by ProxyUserService");
    }
    private void afterThrow(Throwable throwable, String...args) throws Throwable{
        System.out.println("in AfterThrowing with args: " + Arrays.toString(args)+" and exception: "+throwable);
        throw new RuntimeException("meet a exception: "+ throwable.getMessage());
    }
    private void before(Object...args){
        System.out.println("in Before with args: "+ Arrays.toString(args));
    }
}
```
接下来实现入口：
```java
package space.wudi.readsourceaop.myproxy;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import space.wudi.readsourceaop.bean.User;
import space.wudi.readsourceaop.myproxy.proxy.ProxyUserService;
import javax.annotation.PostConstruct;
@RestController
public class UseMyProxyController {
    private UserService userService;
    private UserService userServiceProxy;
    @PostConstruct
    void postConstruct(){
        userService = new UserServiceImpl();
        userServiceProxy = new ProxyUserService(userService);
    }
    @GetMapping("/loginWithoutProxy")
    public User loginWithoutProxy(String username) throws Throwable{
        return userService.login(username);
    }
    @GetMapping("/loginWithProxy")
    public User UserLoginWithProxy(String username) throws Throwable{
        return userServiceProxy.login(username);
    }
}
```
然后我们就可以通过接口调用了。
## 测试
首先调用没有使用代理的`/loginWithoutProxy?username=WuDi`：  
![WithoutMyProxy](MyProxy-without.png)
对应的控制台输出：  
> now logging in...

而利用代理的`/loginWithProxy?username=WuDi`：  
![WithMyProxy](MyProxy-with.png)
对应的控制台输出：  
> in Before with args: [WuDi]  
> now logging in...  
> in AfterReturning with args: [WuDi] and rtVal: space.wudi.readsourceaop.bean.User@4c14b089  
> in After with args: [WuDi]  

同样的，如果不传入username，就会触发NullPointerException，我们来试一下：
没有代理的`/loginWithoutProxy`：
> now logging in...  
> 2020-12-12 12:32:55.794 ERROR 11313 --- [nio-8080-exec-7] o.a.c.c.C.[.[.[/].[dispatcherServlet]    : Servlet.service() for servlet [dispatcherServlet] in context with path [] threw exception [Request processing failed; nested exception is java.lang.NullPointerException: username cannot be null] with root cause
> java.lang.NullPointerException: username cannot be null
> ...TraceStack

有代理的`/loginWithProxy`：
> in Before with args: [null]  
> now logging in...  
> in AfterThrowing with args: [null] and exception: java.lang.NullPointerException: username cannot be null
in After with args: [null]  
> 2020-12-12 12:30:56.431 ERROR 11313 --- [nio-8080-exec-3] o.a.c.c.C.[.[.[/].[dispatcherServlet]    : Servlet.service() for servlet [dispatcherServlet] in context with path [] threw exception [Request processing failed; nested exception is java.lang.RuntimeException: meet a exception: username cannot be null] with root cause  
> java.lang.RuntimeException: meet a exception: username cannot be null
> ...TraceStack

可以看到即使抛出了异常，也依然访问了After方法。

## 加入Around和自动注入
由于篇幅，这个我就放在git上了，需要的可以通过[传送门](https://github.com/discko/ReadSource/tree/master/readsource-aop)自行查看。
分别执行接口`/loginAutowired?username=WuDi`、`/loginAutowired` ，可以得到无异常的输出日志：
> in Around before process
> in Before
> now logging in...
> in AfterReturning with rtVal: space.wudi.readsourceaop.bean.User@7abb7e21
> in After
> in Around after process

和有异常的输出日志：  
> in Around before process
> in Before
> now logging in...
> in AfterThrowing with rtVal: java.lang.reflect.InvocationTargetException
> in After
> in Around after process

在AfterReturning的lambda中下一个断点，在调用栈中也可以进行观察：  
![MyProxyAutowired](MyProxy-AutowiredCallStack.png)  
此时仍然在`processAfter()`方法中，但并未执行`adviseAfter()`。

解释一下各个类的作用：
`space.wudi.readsourceaop.myproxy.proxy.ProxyAroundUserService`这个类就是代理类，我将几个Advice过程通过Functional接口都留在了这个代理类中了，并通过`AspectProcessor`子类中的`process()`方法去执行流程。  
而在`space.wudi.readsourceaop.myproxy.MyAspect`类中，创建了这个代理类的bean，通过lambda表达式实现了各个Advice阶段。  
最后在`space.wudi.readsourceaop.myproxy.UseMyProxyAutowiredController`类中利用`@Autowired`将代理类注入到`UserService userService`这个引用中。  


# SpringAOP中代理Proxy的实现方式

Spring AOP 中代理有两种实现方式，分别是利用Jdk中自带的Dynamic Proxy和利用CgLib第三方库。从哪儿看出来的呢，可以搜索aop proxy相关的类，很容易就找到一个叫做AopProxy的接口，查看其实现，分别是`JdkDynamicAopProxy`、`CglibAopProxy`、`ObjenesisAopProxy`。后两个师出同源，就都认为是CGLib的了。
![ImplementationsOfAopProxy](ImplementationsOfAopProxy.png)。

当然，翻看`DefaultAopProxyFactory`的源码或者文档，也能发现Spring AOP是通过上述两种方式实现的。

# JDK Dynamic Proxy
## 代理对象的生成
我们从`JdkDynamicAopProxy`类出发，里面很容易就看到了两个`getProxy`方法：
```java
    public Object getProxy() {
		return getProxy(ClassUtils.getDefaultClassLoader());
	}
	public Object getProxy(@Nullable ClassLoader classLoader) {
		if (logger.isTraceEnabled()) {
			logger.trace("Creating JDK dynamic proxy: " + this.advised.getTargetSource());
		}
		return Proxy.newProxyInstance(classLoader, this.proxiedInterfaces, this);
	}
```
可以看到，最终调用的都是`java.lang.reflection.Proxy`类的`newProxyInstance`方法。需要传入一个`ClassLoader`、一个需要代理的接口列表（也就是目标对象的接口列表），以及`this`指针（`JdkDynamicAopProxy`同时也实现了`InvocationHandler`接口，所以它自己本身可以调用`this.invoke()`方法来调用目标方法。  
继续跟踪`newProxyInstance()`方法，大致经过这样3步：确认参数合法性→创建代理对象→实例化代理对象。前后都比较简单，“创建代理对象”这部只有一个动作，`Class<?> cl = getProxyClass0(loader, intfs);`，那么继续跟踪，里面也就一句有用的话：
```java
 private static Class<?> getProxyClass0(ClassLoader loader, Class<?>... interfaces) {
    if (interfaces.length > 65535) {
        throw new IllegalArgumentException("interface limit exceeded");
    }
    // If the proxy class defined by the given loader implementing
    // the given interfaces exists, this will simply return the cached copy;
    // otherwise, it will create the proxy class via the ProxyClassFactory
    return proxyClassCache.get(loader, interfaces);
}
```
也就是在`proxyClassCache`中寻找使用相同类加载器`loader`加载的，而且有相同`interfaces`接口列表的代理类。如果没有的话，会利用proxyClassCache去创建。  
看上去很接近了，看看`proxyClassCache`的初始化，就在最上面：
```java
 private static final WeakCache<ClassLoader, Class<?>[], Class<?>>
        proxyClassCache = new WeakCache<>(new KeyFactory(), new ProxyClassFactory());
```
那么看来就是`ProxyClassFactory`了。  
```java
private static final class ProxyClassFactory implements BiFunction<ClassLoader, Class<?>[], Class<?>>{
        // 代理类的类名的前缀
        private static final String proxyClassNamePrefix = "$Proxy";
        // 为了防止类名重复，使用一个自增器，在类名前缀后面拼接
        private static final AtomicLong nextUniqueNumber = new AtomicLong();
        @Override
        public Class<?> apply(ClassLoader loader, Class<?>[] interfaces) {
            //存放目标对象的合法接口，把Map当Set用
            Map<Class<?>, Boolean> interfaceSet = new IdentityHashMap<>(interfaces.length);
            for (Class<?> intf : interfaces) {
                //利用传入的类加载器loader尝试加载接口类，如果加载失败就抛出异常。失败的可能比如类不可达、不在此类加载器中等。
                Class<?> interfaceClass = null;
                try {
                    interfaceClass = Class.forName(intf.getName(), false, loader);
                } catch (ClassNotFoundException e) {
                }
                if (interfaceClass != intf) {
                    throw new IllegalArgumentException(
                        intf + " is not visible from class loader");
                }
                // 确认这是一个interface
                if (!interfaceClass.isInterface()) {
                    throw new IllegalArgumentException(
                        interfaceClass.getName() + " is not an interface");
                }
                // 确认没有重复添加
                if (interfaceSet.put(interfaceClass, Boolean.TRUE) != null) {
                    throw new IllegalArgumentException(
                        "repeated interface: " + interfaceClass.getName());
                }
            }
            // 为代理类确定所在包
            String proxyPkg = null;     
            int accessFlags = Modifier.PUBLIC | Modifier.FINAL;

            // 遍历所有的接口，如果发现某个接口是非public的，那么后面就要将代理对象放到这个接口所在的包里。如果发现更多的非public接口，而且存放在不同的包里，那么就要抛出异常，因为后面创建的Proxy对象无法同时实现这些接口。
            for (Class<?> intf : interfaces) {
                int flags = intf.getModifiers();
                if (!Modifier.isPublic(flags)) {
                    accessFlags = Modifier.FINAL;
                    String name = intf.getName();
                    int n = name.lastIndexOf('.');
                    String pkg = ((n == -1) ? "" : name.substring(0, n + 1));
                    if (proxyPkg == null) {
                        proxyPkg = pkg;
                    } else if (!pkg.equals(proxyPkg)) {
                        throw new IllegalArgumentException(
                            "non-public interfaces from different packages");
                    }
                }
            }
            //如果proxyPkg是null，也就是说上面遍历的所有的接口都不是非public的，那么就使用默认的包名（com.sun.proxy)
            if (proxyPkg == null) {
                proxyPkg = ReflectUtil.PROXY_PACKAGE + ".";
            }
            //通过$Proxy和计数器拼接，得到代理类的类名。
            long num = nextUniqueNumber.getAndIncrement();
            String proxyName = proxyPkg + proxyClassNamePrefix + num;

            //生成代理类的class文件（在内存中，以byte数组表示）
            byte[] proxyClassFile = ProxyGenerator.generateProxyClass(
                proxyName, interfaces, accessFlags);
            try {
                //加载这个代理类到类加载器
                return defineClass0(loader, proxyName,
                                    proxyClassFile, 0, proxyClassFile.length);
            } catch (ClassFormatError e) {
                throw new IllegalArgumentException(e.toString());
            }
        }
    }
```
这样，大致的流程就清楚了。上面的`byte[] proxyClassFile = ProxyGenerator.generateProxyClass(proxyName, interfaces, accessFlags)`这一行里面就纯粹是在内存中根据class文件的格式创建class文件。唯一值得一提的就是，在其中有这样3行，如果让我写的话，我估计一定会忘记：
```java
this.addProxyMethod(hashCodeMethod, Object.class);
this.addProxyMethod(equalsMethod, Object.class);
this.addProxyMethod(toStringMethod, Object.class);
```
从这个角度来说的话，代理类中至少存在这三个函数的实现的。 

在`ProxyGenerator.generateProxyClass`还有一行值得注意，那就是`if (saveGeneratedFiles) {Files.write(xxx)}`，也就是说如果`saveGeneratedFiles`为真，就将class文件输出。网上翻，可以看到这个属性的定义：
```java
private static final boolean saveGeneratedFiles = (Boolean)AccessController.doPrivileged(new GetBooleanAction("sun.misc.ProxyGenerator.saveGeneratedFiles"));
```
所以，在JVM的启动参数上增加`-Dsun.misc.ProxyGenerator.saveGeneratedFiles=true`就可以将class文件输出了。  
尝试了一下，因为`JdkDynamicAopProxy`在构造的时候调用的`AopProxyUtils.completeProxiedInterfaces()`中，会额外引入3个接口，所以有一些额外的接口被注入了：
```java
//org.springframework.aop.framework.AopProxyUtils
static Class<?>[] completeProxiedInterfaces(AdvisedSupport advised, boolean decoratingProxy) {
    Class<?>[] specifiedInterfaces = advised.getProxiedInterfaces();
    //省略
    boolean addSpringProxy = !advised.isInterfaceProxied(SpringProxy.class);
    boolean addAdvised = !advised.isOpaque() && !advised.isInterfaceProxied(Advised.class);
    boolean addDecoratingProxy = (decoratingProxy && !advised.isInterfaceProxied(DecoratingProxy.class));
    int nonUserIfcCount = 0;
    if (addSpringProxy) {
        nonUserIfcCount++;
    }
    if (addAdvised) {
        nonUserIfcCount++;
    }
    if (addDecoratingProxy) {
        nonUserIfcCount++;
    }
    Class<?>[] proxiedInterfaces = new Class<?>[specifiedInterfaces.length + nonUserIfcCount];
    System.arraycopy(specifiedInterfaces, 0, proxiedInterfaces, 0, specifiedInterfaces.length);
    int index = specifiedInterfaces.length;
    if (addSpringProxy) {
        proxiedInterfaces[index] = SpringProxy.class;
        index++;
    }
    if (addAdvised) {
        proxiedInterfaces[index] = Advised.class;
        index++;
    }
    if (addDecoratingProxy) {
        proxiedInterfaces[index] = DecoratingProxy.class;
    }
    return proxiedInterfaces;
}
```
这样一来，除了原本自己写的接口中未实现的方法、3个默认方法（equals()、hashCode()、toString()），还会新增26个方法。下面是一个class文件反编译后得到的java代码，我已经将`SpringProxy`、`Advised`、`DecoratingProxy`中的接口及相关代码删除了：
```java
public final class $Proxy62 extends Proxy implements JdkDynamicService, SpringProxy, Advised, DecoratingProxy {
    private static Method m0;
    private static Method m1;
    private static Method m2;
    private static Method m3;
    //other private static Method mx;
    public $Proxy62(InvocationHandler var1) throws  {
        super(var1);
    }
    public final int hashCode() throws  {
        try {
            return (Integer)super.h.invoke(this, m0, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }
    public final boolean equals(Object var1) throws  {
        try {
            return (Boolean)super.h.invoke(this, m1, new Object[]{var1});
        } catch (RuntimeException | Error var3) {
            throw var3;
        } catch (Throwable var4) {
            throw new UndeclaredThrowableException(var4);
        }
    }
    public final String toString() throws  {
        try {
            return (String)super.h.invoke(this, m2, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }
    public final String useJdkDynamicProxy(String var1) throws  {
        try {
            return (String)super.h.invoke(this, m3, new Object[]{var1});
        } catch (RuntimeException | Error var3) {
            throw var3;
        } catch (Throwable var4) {
            throw new UndeclaredThrowableException(var4);
        }
    }
    //other function delclarations
    static {
        try {
            m0 = Class.forName("java.lang.Object").getMethod("hashCode");
            m1 = Class.forName("java.lang.Object").getMethod("equals", Class.forName("java.lang.Object"));
            m2 = Class.forName("java.lang.Object").getMethod("toString");
            m3 = Class.forName("space.wudi.readsourceaop.service.JdkDynamicService").getMethod("useJdkDynamicProxy", Class.forName("java.lang.String"));
            //other mx = Class.forName().getMethod()
        } catch (NoSuchMethodException var2) {
            throw new NoSuchMethodError(var2.getMessage());
        } catch (ClassNotFoundException var3) {
            throw new NoClassDefFoundError(var3.getMessage());
        }
    }
}
```

## 代理的过程
### 测试代码编写
编写一组代理的目标，具体参见[示例代码](https://github.com/discko/ReadSource/tree/master/readsource-aop)。
还是贴一下代码吧。
首先创建了一个注解，用于标记需要被切入的目标方法：  
```java
package space.wudi.readsourceaop.annotation;
import java.lang.annotation.*;
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface AspectJoinPoint {
    String value() default "";
}
```
然后是切面类，没有什么太多需要讲的，`@Pointcut`处使用了`@annotation`去查找相关的切入点：  
```java
package space.wudi.readsourceaop.aspect;
import org.aspectj.lang.*;
import org.aspectj.lang.annotation.*;
import org.springframework.stereotype.Component;
@Aspect
@Component
public class ServiceAspect {
    @Pointcut("@annotation(space.wudi.readsourceaop.annotation.AspectJoinPoint)")
    public void pointcut(){}
    @Around("pointcut()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable{
        System.out.println("around before");
        Object rtVal = joinPoint.proceed();
        System.out.println("around after");
        return rtVal;
    }
    @Before(value = "pointcut()")
    public void before(JoinPoint joinPoint){
        System.out.println("before");
    }
    @After("pointcut()")
    public void after(JoinPoint joinPoint){
        System.out.println("after");
    }
    @AfterReturning(pointcut = "pointcut()", returning = "rtVal")
    public Object afterReturning(JoinPoint joinPoint, Object rtVal){
        System.out.println("after returning "+rtVal);
        return rtVal;
    }
    @AfterThrowing(pointcut = "pointcut()", throwing = "throwable")
    public void afterThrowing(JoinPoint joinPoint, Throwable throwable) throws Throwable{
        System.out.println("after throwing "+throwable);
        throw throwable;
    }
}
```
接下来是接口和实现：
```java
//interface
package space.wudi.readsourceaop.service;
public interface JdkDynamicService {
    String useJdkDynamicProxy(String id);
}
//implementation
package space.wudi.readsourceaop.service;
import org.springframework.stereotype.Service;
import space.wudi.readsourceaop.annotation.AspectJoinPoint;
@Service
public class JdkDynamicServiceImpl implements JdkDynamicService {
    @Override
    @AspectJoinPoint
    public String useJdkDynamicProxy(String id) {
        System.out.println("in service");
        return "id="+id;
    }
}
```
最后在`MyController`中增加了一个API入口，用于调用测试：
```java
// space.wudi.readsourceaop.controller.MyController
@RestController
public class MyController {
    //省略其他的API接口
    @Autowired
    JdkDynamicService jdkDynamicService;
    @GetMapping("/testJdkDynamicProxy")
    public String testJdkDynamicProxy(String id){
        System.out.println("in controller");
        return jdkDynamicService.useJdkDynamicProxy(id);
    }
}
```

说明一下几个类：  
* `space.wudi.reassourceaop.service.JdkDynamicProxyService`是一个即将被代理的接口。里面就只有一个未实现的方法`useJdkDynamicProxy`。  
* `space.wudi.reassourceaop.service.JdkDynamicProxyServiceImpl`是上述接口的实现，其实例也就是被代理的目标对象。
* `space.wudi.reassourceaop.annotation.AspectJoinPoint`是一个注解，用来标注需要被代理的切入点Pointcut。
* `space.wudi.reassourceaop.aspect.ServiceAspect`就是这个切面的描述。声明了`@Arount`、`@Before`、`@After`、`@AfterReturning`、`@AfterThrowing`这5个Advice。
* `space.wudi.reassourceaop.controller.MyController`中新增了一个`String testJdkDynamicProxy(String)`函数，用来测试该代理，并且添加了代理对象的注入点`@Autowired JdkDynamicService jdkDynamicService`。  

### 观察主要逻辑
在启动后，我们在`MyController.testJdkDynamicProxy()`中下一个断点，并跟着断点进行调试。可以看到，在原本应该进入`JdkDynamicProxyServiceImpl.useJdkDynamicProxy()`，实际上却进入了`org.springframework.aop.framework.JdkDynamicAopProxy.invoke()`之中。
```java
// org.springframework.aop.framework.JdkDynamicAopProxy
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    Object oldProxy = null;
    boolean setProxyContext = false;
    // 获取一个持有目标对象的对象
    TargetSource targetSource = this.advised.targetSource;
    Object target = null;
    try {
        if (!this.equalsDefined && AopUtils.isEqualsMethod(method)) {
            // 如果代理中没有定义equals()方法，且现在准备调用equals()方法，下同
            return equals(args[0]);
        }
        else if (!this.hashCodeDefined && AopUtils.isHashCodeMethod(method)) {
            return hashCode();
        }
        else if (method.getDeclaringClass() == DecoratingProxy.class) {
            return AopProxyUtils.ultimateTargetClass(this.advised);
        }
        else if (!this.advised.opaque && method.getDeclaringClass().isInterface() && method.getDeclaringClass().isAssignableFrom(Advised.class)) {
            return AopUtils.invokeJoinpointUsingReflection(this.advised, method, args);
        }
        Object retVal;
        if (this.advised.exposeProxy) {
            oldProxy = AopContext.setCurrentProxy(proxy);
            setProxyContext = true;
        }
        // 尽量晚地获取目标对象
        target = targetSource.getTarget();
        Class<?> targetClass = (target != null ? target.getClass() : null);
        // 获取advice的责任链
        List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);
        if (chain.isEmpty()) {
            // 如果advice责任链是空的，就直接调用目标对象的目标方法
            Object[] argsToUse = AopProxyUtils.adaptArgumentsIfNecessary(method, args);
            retVal = AopUtils.invokeJoinpointUsingReflection(target, method, argsToUse);
        }
        else {
            // 利用责任链，创建代理对象的MethodInvocation
            MethodInvocation invocation =
                    new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
            // 调用责任链，获取返回值
            retVal = invocation.proceed();
        }
        // 对返回值进行处理
        Class<?> returnType = method.getReturnType();
        if (retVal != null && retVal == target &&
                returnType != Object.class && returnType.isInstance(proxy) &&
                !RawTargetAccess.class.isAssignableFrom(method.getDeclaringClass())) {
            // 特殊情况，如果目标对象被代理的方法返回了this，则将this替换为代理对象
            retVal = proxy;
        }
        else if (retVal == null && returnType != Void.TYPE && returnType.isPrimitive()) {
            // 如果返回了null，但目标方法应当返回基础类型，则抛出异常
            throw new AopInvocationException(
                    "Null return value from advice does not match primitive return type for: " + method);
        }
        // 返回
        return retVal;
    }
    finally {
        if (target != null && !targetSource.isStatic()) {
            targetSource.releaseTarget(target);
        }
        if (setProxyContext) {
            AopContext.setCurrentProxy(oldProxy);
        }
    }
}
```
从源码来看，主要分成这样几个步骤：判断调用方法（特殊方法特殊处理）→获取目标对象（尽量晚）→调用advice责任链获取返回值→对返回值进行处理（如果需要）→收尾和返回。  
这样，比较重要的就是责任链如何调用了。  
先不说为什么，只说是什么，现在的责任链中有哪些节点呢？断点内看得很清楚：  
![JdkDynamicProxyChainList](JdkDynamicProxyChain.png)  
可以看到第一个是`ExposeInvocationInterceptor`，然后就是`Around`、`Before`、`After`、`AfterReturning`、`AfterThrowing`这几个Advice了。

### 责任链调用
上面代码中利用责任链和代理对象生成了一个`ReflectiveMethodInvocation`对象，并调用了它的`proceed()`函数
```java
MethodInvocation invocation = new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
retVal = invocation.proceed();
```
然后在`proceed()`中：
```java
// org.springframework.aop.framework.ReflectiveMethodInvocation
public Object proceed() throws Throwable {
    // 如果已经到达责任链末尾，则调用目标方法
    if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
        return invokeJoinpoint();
    }
    // 获取责任链中的当前节点
    Object interceptorOrInterceptionAdvice =
            this.interceptorsAndDynamicMethodMatchers.get(++this.currentInterceptorIndex);
    if (interceptorOrInterceptionAdvice instanceof InterceptorAndDynamicMethodMatcher) {
        // 如果当前节点是一个InterceptorAndDynamicMethodMatcher，则执行这里。先省略
    }
    else {
        // 如果是个MethodInterceptor就invoke
        return ((MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);
    }
}
```
#### ExposeInvocationInterceptor
上面说到了，责任链中的首个元素是一个`ExposeInvocationInterceptor`，它不是`InterceptorAndDynamicMethodMatcher`，所以进入else分支，执行`ExposeInvocationInterceptor.invoke()`：  
```java
// org.springframework.aop.interceptor.ExposeInvocationInterceptor
public Object invoke(MethodInvocation mi) throws Throwable {
    MethodInvocation oldInvocation = invocation.get();
    invocation.set(mi);
    try {
        return mi.proceed();
    }
    finally {
        invocation.set(oldInvocation);
    }
}
```
这里的`invocation`是一个ThreadLocal，这里的oldInvocation是`MyController`的代理对象中的`testJdkDynamicProxy()`（因为我是在这个函数里下的断点，而这个方法也会被`LogAspect`的切面代理。所以从这里的逻辑可以看出，每进入一个新的切面Aspect，就会在ThreadLocal中记录当前切面的`ReflectiveMethodInvocation`，这样当需要的时候，就可以从中取出必要的信息；而退出一层后，又会恢复上一层Aspect的`ReflectiveMethodInvocation`。  
这时候，再执行`mi.proceed()`，而`mi`就是上面`ReflectiveMethodInvocation`传入的`this`，所以就又回到了责任链调用。这一次，我们会取出下一个元素，里面会包含`AspectJAroundAdvice`和`MethodMatcher`两个，所以会执行上面省略的那一部分代码：
```java
// org.springframework.aop.framework.ReflectiveMethodInvocation
if (interceptorOrInterceptionAdvice instanceof InterceptorAndDynamicMethodMatcher) {
    InterceptorAndDynamicMethodMatcher dm =
            (InterceptorAndDynamicMethodMatcher) interceptorOrInterceptionAdvice;
    // 获取目标对象的class
    Class<?> targetClass = (this.targetClass != null ? this.targetClass : this.method.getDeclaringClass());
    if (dm.methodMatcher.matches(this.method, targetClass, this.arguments)) {
        //如果目标对象和目标方法与代理匹配，则调用拦截器中的方法（也就是advice方法）
        return dm.interceptor.invoke(this);
    }
    else {
        // 如果目标对象和目标方法与代理不匹配，则直接递归调用下一个责任链节点
        return proceed();
    }
}
```
#### AspectJAroundAdvice
这样，通过`dm.interceptor.invoke`就进入了`Around` advice。  
```java
// org.springframework.aop.aspectj.AspectJAroundAdvice
public Object invoke(MethodInvocation mi) throws Throwable {
    if (!(mi instanceof ProxyMethodInvocation)) {
        throw new IllegalStateException("MethodInvocation is not a Spring ProxyMethodInvocation: " + mi);
    }
    ProxyMethodInvocation pmi = (ProxyMethodInvocation) mi;
    // 生成可执行process()方法的JoinPoint对象，以作为@Around修饰的方法的入参（之一）
    ProceedingJoinPoint pjp = lazyGetProceedingJoinPoint(pmi);
    JoinPointMatch jpm = getJoinPointMatch(pmi);
    return invokeAdviceMethod(pjp, jpm, null, null);
}
```
这里很简单，创建了一个`ProceedingJoinPoint`对象（这也就是我们在切面中`@Around`中使用的那个可以调用`process()`的`JoinPoint`对象。  
继续往`invokeAdviceMethod()`方法中走，经过`argBinding()`函数将参数整理成`@Around`需要的数量和顺序，然后就可以调用
```java
protected Object invokeAdviceMethodWithGivenArgs(Object[] args) throws Throwable {
    Object[] actualArgs = args;
    if (this.aspectJAdviceMethod.getParameterCount() == 0) {
        actualArgs = null;
    }
    try {
        ReflectionUtils.makeAccessible(this.aspectJAdviceMethod);
        // 这里就是调用的核心，直接调用@Around修饰的方法
        return this.aspectJAdviceMethod.invoke(this.aspectInstanceFactory.getAspectInstance(), actualArgs);
    } catch (IllegalArgumentException ex) {
        throw new AopInvocationException(/* blabla */, ex);
    } catch (InvocationTargetException ex) {
        throw ex.getTargetException();
    }
}
```
这里很简单，this.aspectJAdviceMethod就是@Around修饰的那个`around`方法`public Object around(ProceedingJoinPoint joinPoint) throws Throwable`，invoke的第一个参数就是`ServiceAspect`的实例，第二个就是`around`方法的入参列表。这样就进入了`ServiceAspect.around()`函数里。直接跟踪进入`MethodInvocationProceedingJoinPoint.process()`方法中
```java
// org.springframework.aop.aspectj.MethodInvocationProceedingJoinPoint
public Object proceed() throws Throwable {
    return this.methodInvocation.invocableClone().proceed();
}
```
这里的invocableClone主要做了两件事情，首先会将参数列表进行浅拷贝，然后将methodInvocation进行浅拷贝（包括其中的chain）。上面的注解中明确了浅拷贝的目的，那就是既能使用原有的引用和chain，同时又能保证值的独立性。下图中左边的是克隆后的对象，右边蓝色边框中的是原对象，可以看出对象id发生了变化（原来是@5872，现在是@6646）；另外，argument数组对象也发生了变化（原来是@5860，现在是@6617）。但其他的都是直接引用的（包括argument中的元素也没有进行复制）。  
![JdkDynamicProxy-MethodInvocationShallowClone](JdkDynamicProxy-MethodInvocationShallowClone.png)  

接下来，又回到了`ReflectiveMethodInvocation.proceed()`，这次按照顺序，会从责任链中取出`MethodBeforeAdviceInterceptor`。

#### MethodBeforeAdviceInterceptor
进入`MethodBeforeAdviceInterceptor.invoke()`，很简单，就2行：
```java
public Object invoke(MethodInvocation mi) throws Throwable {
    this.advice.before(mi.getMethod(), mi.getArguments(), mi.getThis());
    return mi.proceed();
}
```
这里`mi`是`ReflectiveMethodInvocation`，所以`mi.getMethod()`仍然是controller中的那个函数，经过跟踪，发现在`this.advice.before`中根本没有使用这个参数-，-。  
不管了，继续往里面，为了执行before advice，还需要先执行`getJoinPointMatch()`，这个是干什么的呢？主要是用来进行参数（advice入参）绑定的。我们知道，在@Pointcut上面以及各个诸如@Around、@Before上，都可以增加一个argNames字段，这样在编译后如果抹掉了参数名称导致无法绑定的话，就需要利用argNames字段进行辅助。但是这些被存在了`ReflectiveMethodInvocation`的`userAttribute`中，这是一个`Map`，key是`@Pointcut`修饰的函数名，value就是一个`JoinPointMatch`对象，里面描述了参数的绑定关系。
说起来很复杂，其实就是在进行传参时，需要通过`ReflectiveMethodInvocation`的`userAttribute`拿到参数绑定信息。但信息在这么深的地方是访问不到的，这时候，责任链的首个元素就发挥作用了，看下面：
```java
protected JoinPointMatch getJoinPointMatch() {
    MethodInvocation mi = ExposeInvocationInterceptor.currentInvocation();
    if (!(mi instanceof ProxyMethodInvocation)) {
        throw new IllegalStateException("MethodInvocation is not a Spring ProxyMethodInvocation: " + mi);
    }
    return getJoinPointMatch((ProxyMethodInvocation) mi);
}
```
这段代码第一行，就是通过`ExposeInvocationInterceptor`的静态方法`currentInvocation()`，利用ThreadLocal获取到了此线程中的当前的MethodInvocation，这玩意儿就是在责任链首个元素处理过程中添加到`invocations`中的。[点此跳转到那段代码](####ExposeInvocationInterceptor)这样一来，ExposeInvocation的作用就很清楚了。  

接下来就和Around一样，就可以执行到`ServiceAspect.before()`中了。  
至于为什么Around不需要通过`ExposeInvocationInterceptor.currentInvocation()`来获取`JoinPointMatch`，是因为在`AspectJAroundAdvice.invoke(MethodInvocation mi)`中，直接通过入参`mi`就拿到了`JoinPointMatch`；而Before中竟然传了一些垃圾进去，却没有把这么重要的`mi`传进去。不知道设计者是怎么想的，可能还有什么更精妙的设计在其中，只不过我还没有悟透。

这样，总算把Before执行完了，一路return回到`MethodBeforeAdviceInterceptor`的这里：
```java
public Object invoke(MethodInvocation mi) throws Throwable {
    this.advice.before(mi.getMethod(), mi.getArguments(), mi.getThis());
    return mi.proceed();
}
```
这时候，我们就可以执行`return mi.proceed()`了。回到`ReflectiveMethodInvocation.proceed()`，继续在责任链中取出节点。这次取出的是`AspectJAfterAdvice`。

#### AspectJAfterAdvice
进入`AspectJAfterAdvice.invoke()`，它是这样的：
```java
public Object invoke(MethodInvocation mi) throws Throwable {
    try {
        return mi.proceed();
    }
    finally {
        invokeAdviceMethod(getJoinPointMatch(), null, null);
    }
}
```
很明显能看出来会先继续从责任链中取advice，最后在调用After的advice方法。 
那么就继续取吧。接下来取出的是`AfterReturningAdviceInterceptor`。

#### AfterReturningAdviceInterceptor
进入`AfterReturningAdviceInterceptor.invoke()`，看上去也很简单。
```java
public Object invoke(MethodInvocation mi) throws Throwable {
    Object retVal = mi.proceed();
    this.advice.afterReturning(retVal, mi.getMethod(), mi.getArguments(), mi.getThis());
    return retVal;
}
```
继续从责任链里取，似乎已经取到最后一个了，这次取出的是`AspectJAfterThrowingAdvice`。

#### AspectJAfterThrowingAdvice
进入`AspectJAfterThrowingAdvice.invoke()`，原本以为要结束了，结果还有一层：
```java
public Object invoke(MethodInvocation mi) throws Throwable {
    try {
        return mi.proceed();
    }
    catch (Throwable ex) {
        if (shouldInvokeOnThrowing(ex)) {
            invokeAdviceMethod(getJoinPointMatch(), null, ex);
        }
        throw ex;
    }
}
```
再次调用`ReflectiveMethodInvocation.proceed()`，这次终于是最后一次了，因为在方法的开始，就因为责任链已经取完了，直接调用目标函数，并返回即可。
```java
//调用链已经取完了
if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
    //直接调用目标函数
    return invokeJoinpoint();
}
```
这样，就终于进入了心心念念的`JdkDynamicServiceImpl.useJdkDynamicProxy()`方法之中。看看调用栈：  
![JdkDynamicProxyCallStack](JdkDynamicProxyCallStack.png)  

从下往上栈逐渐变深。
* 最下面是`MyController`中的API接口函数（当然这个`MyController`实际上是`CGLib`根据`LogAspect`生成的代理），
* 下面数第2个，是`ServiceAspect`生成的`JdkDynamicServiceImpl`的代理。
* 下面数第3个，就是`Around`的Advice对象。
* 再往上，就是`ServiceAspect`中的`around()`函数。
* 再往上的4个分别就是`Before`、`After`、`AfterReturning`、`AfterThrowing`的advice对象。
* 最上方的，就是目标对象的目标函数，也就是`JdkDynamicServiceImpl.useJdkDynamicProxy()`了。  

在目标函数中，如果发生了异常，就会被`AspectJAfterThrowingAdvice`中的catch截获，交由`ServiceAspect`中的`@AfterThrowing`处理。没有问题就会一层一层往上抛，并依次执行`@AfterReturning`、`@After`。直到回到`@Around`之中。再继续返回直到回到`MyController`之中。这样，整个调用过程就终于结束了。

## 初始化切面、构造责任链
上面生成代理对象、调用代理对象的过程基本上已经清楚了，那么如何初始化切面以及责任链呢？还是跟着源码来看一看。
### 初始化切面
Spring AOP在BeanFactory中注册了`AnnotationAwareAspectJAutoProxyCreator`（名字贼长），在调用其`findCandidateAdvisors()`时，通过`BeanFactoryAspectJAdvicorsBuilder.buildAspectJAdvicors()`遍历`beanFactory`中的所有bean，找出所有`isAspect()`的bean。
```java
// org.springframework.aop.aspectj.annotation.AbstractAspectJAdvisorFactory
public boolean isAspect(Class<?> clazz) {
    return (hasAspectAnnotation(clazz) && !compiledByAjc(clazz));
}
```
接下来对每一个Aspect类型的bean进行分析。对当前Aspect的Bean，调用`ReflectiveAspectJAdvisorFactory.getAdvisors()`来获取Advisor列表。
```java
// org.springframework.aop.aspectj.annotation.ReflectiveAspectJAdvisorFactory
public List<Advisor> getAdvisors(MetadataAwareAspectInstanceFactory aspectInstanceFactory) {
    Class<?> aspectClass = aspectInstanceFactory.getAspectMetadata().getAspectClass();
    String aspectName = aspectInstanceFactory.getAspectMetadata().getAspectName();
    validate(aspectClass);
    //这个装饰器可以防止MetadataAwareAspectInstanceFactory被重复实例化
    MetadataAwareAspectInstanceFactory lazySingletonAspectInstanceFactory =
            new LazySingletonAspectInstanceFactoryDecorator(aspectInstanceFactory);

    List<Advisor> advisors = new ArrayList<>();
    // 注意这个getAdvisorMethod()
    for (Method method : getAdvisorMethods(aspectClass)) {
        Advisor advisor = getAdvisor(method, lazySingletonAspectInstanceFactory, 0, aspectName);
        if (advisor != null) {
            advisors.add(advisor);
        }
    }
    //省略下面的非单例aspect和introduction的advisor的添加
    return advisors;
}
```
在这个方法中，会通过`getAdvisorMethods(aspectClass)`来获取有所Advice方法。这个需要注意：
```java
private List<Method> getAdvisorMethods(Class<?> aspectClass) {
    final List<Method> methods = new ArrayList<>();
    ReflectionUtils.doWithMethods(aspectClass, method -> {
        // 将所有不带@Pointcut的method都加进来，并使用ReflectionUtils.USER_DECLARED_METHODS过滤器先筛一遍
        // 这个过滤器只保留用户定义的方法，过滤掉桥接方法等编译器生成的方法
        if (AnnotationUtils.getAnnotation(method, Pointcut.class) == null) {
            methods.add(method);
        }
    }, ReflectionUtils.USER_DECLARED_METHODS);
    if (methods.size() > 1) {
        // 然后对方法进行排序
        methods.sort(METHOD_COMPARATOR);
    }
    return methods;
}
```
而这个排序方法，奠定了后续责任链中的顺序：
```java
static {
    // 按照下面列出的顺序排序
    Comparator<Method> adviceKindComparator = new ConvertingComparator<>(
            new InstanceComparator<>(
                    Around.class, Before.class, After.class, AfterReturning.class, AfterThrowing.class),
            (Converter<Method, Annotation>) method -> {
                AspectJAnnotation<?> ann = AbstractAspectJAdvisorFactory.findAspectJAnnotationOnMethod(method);
                return (ann != null ? ann.getAnnotation() : null);
            });
    Comparator<Method> methodNameComparator = new ConvertingComparator<>(Method::getName);
    // 如果出现多个相同的注解的方法，将方法的名字作为次关键字进行二次排序
    METHOD_COMPARATOR = adviceKindComparator.thenComparing(methodNameComparator);
}
```
从这里，就能知道各Advice的排序依据了。  

### 构造Advisor元素
最后，对排好序的每一个非@Pointcut修饰的方法调用`getAdvisor(Method candidateAdviceMethod, MetadataAwareAspectInstanceFactory aspectInstanceFactory, int declarationOrderInAspect, String aspectName)`，如果是一个合法的advisor，就会在advisor的实例化过程中根据`@Around`或`@Before`之类的分别创建不同的Advice实例并持有，然后这个advisor就被被加入到advisors列表中了。

```java
// org.springframework.aop.aspectj.annotation.ReflectiveAspectJAdvisorFactory
public Advice getAdvice(Method candidateAdviceMethod, AspectJExpressionPointcut expressionPointcut,  MetadataAwareAspectInstanceFactory aspectInstanceFactory, int declarationOrder, String aspectName) {
    // 验证Aspect类的合法性
    Class<?> candidateAspectClass = aspectInstanceFactory.getAspectMetadata().getAspectClass();
    validate(candidateAspectClass);
    // 确认其存在@Around、@Before之类的注解
    AspectJAnnotation<?> aspectJAnnotation =
            AbstractAspectJAdvisorFactory.findAspectJAnnotationOnMethod(candidateAdviceMethod);
    if (aspectJAnnotation == null) {
        return null;
    }

    if (!isAspect(candidateAspectClass)) {
        throw new AopConfigException("Advice must be declared inside an aspect type: " +
                "Offending method '" + candidateAdviceMethod + "' in class [" +
                candidateAspectClass.getName() + "]");
    }

    if (logger.isDebugEnabled()) {
        logger.debug("Found AspectJ method: " + candidateAdviceMethod);
    }
    // 用来存放根据这个method生成的advice
    AbstractAspectJAdvice springAdvice;
    switch (aspectJAnnotation.getAnnotationType()) {
        case AtPointcut:
            // 如果不小心混入了@Pointcut，那么就跳过
            if (logger.isDebugEnabled()) {
                logger.debug("Processing pointcut '" + candidateAdviceMethod.getName() + "'");
            }
            return null;
        case AtAround:
            springAdvice = new AspectJAroundAdvice(candidateAdviceMethod, expressionPointcut, aspectInstanceFactory);
            break;
        case AtBefore:
            springAdvice = new AspectJMethodBeforeAdvice(
                    candidateAdviceMethod, expressionPointcut, aspectInstanceFactory);
            break;
        case AtAfter:
            springAdvice = new AspectJAfterAdvice(
                    candidateAdviceMethod, expressionPointcut, aspectInstanceFactory);
            break;
        case AtAfterReturning:
            springAdvice = new AspectJAfterReturningAdvice(
                    candidateAdviceMethod, expressionPointcut, aspectInstanceFactory);
            AfterReturning afterReturningAnnotation = (AfterReturning) aspectJAnnotation.getAnnotation();
            // 如果@AfterReturning存在returning字段，也就是给返回值命名了，需要将这个参数名保留下来
            if (StringUtils.hasText(afterReturningAnnotation.returning())) {
                springAdvice.setReturningName(afterReturningAnnotation.returning());
            }
            break;
        case AtAfterThrowing:
            springAdvice = new AspectJAfterThrowingAdvice(
                    candidateAdviceMethod, expressionPointcut, aspectInstanceFactory);
            AfterThrowing afterThrowingAnnotation = (AfterThrowing) aspectJAnnotation.getAnnotation();
            // 如果@AfterThrowing存在throwable字段，也就是给异常值命名了，需要将这个参数名保留下来
            if (StringUtils.hasText(afterThrowingAnnotation.throwing())) {
                springAdvice.setThrowingName(afterThrowingAnnotation.throwing());
            }
            break;
        default:
            throw new UnsupportedOperationException("Unsupported advice type on method: " + candidateAdviceMethod);
    }
    springAdvice.setAspectName(aspectName);
    springAdvice.setDeclarationOrder(declarationOrder);
    String[] argNames = this.parameterNameDiscoverer.getParameterNames(candidateAdviceMethod);
    if (argNames != null) {
        springAdvice.setArgumentNamesFromStringArray(argNames);
    }
    springAdvice.calculateArgumentBindings();
    return springAdvice;
}
```

当对所有Aspect都分析完成后，将所有的Advisor都合并在一个列表中。这样准备工作就完成了。

### 为代理对象装入Advisor chain  

在创建Proxy的过程中，由于首先要实例化目标对象，所以AOP在`postProcessAfterInitialization`中加入了创建Proxy的动作。  
在`AbstractAutoProxyCreator`中的`wrapIfNessesary`，
```java
// org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator
protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
    if (StringUtils.hasLength(beanName) && this.targetSourcedBeans.contains(beanName)) {
        return bean;
    }
    if (Boolean.FALSE.equals(this.advisedBeans.get(cacheKey))) {
        return bean;
    }
    if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
        this.advisedBeans.put(cacheKey, Boolean.FALSE);
        return bean;
    }
    // 如果已经advice了，那么就创建拦截器责任链
    Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);
    if (specificInterceptors != DO_NOT_PROXY) {
        this.advisedBeans.put(cacheKey, Boolean.TRUE);
        Object proxy = createProxy(
                bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));
        this.proxyTypes.put(cacheKey, proxy.getClass());
        return proxy;
    }
    this.advisedBeans.put(cacheKey, Boolean.FALSE);
    return bean;
}
```
而这里的`getAdvicesAndAdvisorsForBean`会调用`AbstractAdvisorAutoProxyCreator.findEligibleAdvisors()`，来获取符合当前Proxy的目标对象的advisors。
```java
// org.springframework.aop.framework.autoproxy.AbstractAdvisorAutoProxyCreator
protected List<Advisor> findEligibleAdvisors(Class<?> beanClass, String beanName) {
    // 首先找到候选的Advisors，也就是所有Aspect中的Advisor
    List<Advisor> candidateAdvisors = findCandidateAdvisors();
    // 然后根据目标对象的名字和类型，筛选合适的Aspect中的所有Advisor
    List<Advisor> eligibleAdvisors = findAdvisorsThatCanApply(candidateAdvisors, beanClass, beanName);
    extendAdvisors(eligibleAdvisors);
    if (!eligibleAdvisors.isEmpty()) {
        eligibleAdvisors = sortAdvisors(eligibleAdvisors);
    }
    return eligibleAdvisors;
}
```
这里会分两步进行，首先调用`findCandidateAdvisors()`将所有的Aspect中的Advisor筛选出来作为候选的（candidate）Advisor，然后根据bean的类型和名字，将这些候选的Advisor中合适的保留下来，并按照`@Order`进行排序。  
这里用于排序的是`org.springframework.core.annotation.AnnotationAwareOrderComparator`，它继承自`org.springframework.core.OrderComparator`，是专门用于有order的排序器。  
```java
// org.springframework.aop.framework.autoproxy.AbstractAdvisorAutoProxyCreator
protected List<Advisor> sortAdvisors(List<Advisor> advisors) {
    AnnotationAwareOrderComparator.sort(advisors);
    return advisors;
}
```
当然，在排序之前，还有非常重要的一步，那就是`extendAdvisors(eligibleAdvisors)`。这一步是干什么呢，就是把责任链中的首个元素（`ExposeInvocationInterceptor`装进去）。
```java
// org.springframework.aop.aspectj.AspectJProxyUtils
public static boolean makeAdvisorChainAspectJCapableIfNecessary(List<Advisor> advisors) {
    // 如果列表是空的，就不要加入ExposeInvocationInterceptor了
    if (!advisors.isEmpty()) {
        boolean foundAspectJAdvice = false;
        for (Advisor advisor : advisors) {
            // Be careful not to get the Advice without a guard, as this might eagerly
            // instantiate a non-singleton AspectJ aspect...
            if (isAspectJAdvice(advisor)) {
                foundAspectJAdvice = true;
                break;
            }
        }
        // 如果列表中存在AspectJ的Advice且还没有添加过ExposeInvocationInterceptor，那么就添加一个到列表头
        if (foundAspectJAdvice && !advisors.contains(ExposeInvocationInterceptor.ADVISOR)) {
            advisors.add(0, ExposeInvocationInterceptor.ADVISOR);
            return true;
        }
    }
    return false;
}
```
至于为什么要从所有的Aspect中选择，那是因为一个代理可能会同时符合多个Aspect中的Advisor。

然后将advisors回传，完成`AbstractAutoProxyCreator.wrapIfNessesary()`中的`Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);`。接下来，就可以调用`createProxy()`了。  
在`createProxy()`中，跟着逻辑一步一步，就走到了梦寐以求的位置：
```java
// org.springframework.aop.framework.DefaultAopProxyFactory
public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
    if (!IN_NATIVE_IMAGE && (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config))) {
        Class<?> targetClass = config.getTargetClass();
        if (targetClass == null) {
            throw new AopConfigException("TargetSource cannot determine target class: Either an interface or a target is required for proxy creation.");
        }
        if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
            return new JdkDynamicAopProxy(config);
        }
        return new ObjenesisCglibAopProxy(config);
    }
    else {
        return new JdkDynamicAopProxy(config);
    }
}
```
这样，就执行到创建代理对象处了。
终于回来了。
