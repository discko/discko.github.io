---
title: IO-02-多路复用网络选择器的设计
date: 2021-01-30 20:56:50
tags: [IO, 多路复用, NIO, Selector]
categories:
mathjax:
---

错误的写法：
```java
// Thread-Worker, on loop
while(true){
    int num = selector.select();
    if(num > 0 ){
        Iterator<SelectionKey> iterator = selector.selectedKeys().iterator();
        while(iterator.hasNext()){
            SelectionKey key = iterator.next();
            iterator.remove();
            if(key.isAcceptable()){
                handleAccept(key);
            }else if(key.isReadable() || key.isWritable()){
                handleReadWrite(key);
            }
        }
    }
}
// Thread-Init, on init
new Thread(workerRunnable, "Thread-Worker").start();
ServerSocketChannel server = ServerSocketChannel.open();
server.register(workerRunnable.selector, OP_ACCEPT);    // 阻塞在这里

// Thread-Server, on accept
ServerSocketChannel server = selectionKey.channel();
SocketChannel client = server.accept();
client.register(workerRunnable.selector, OP_READ, handler); // 阻塞在这里
```
这两个线程会因为`selector.select()`的锁，导致`channel.register(select)`被阻塞，无法成功注册。而如果将`Thread-Init`中改成这样：
```java
new Thread(workerRunnable, "Thread-Worker").start();
ServerSocketChannel server = ServerSocketChannel.open();
workRunnable.selector.wakeup()；
server.register(workerRunnable.selector, OP_ACCEPT);
```
则一定概率下仍然会因为锁竞争而阻塞，因为在`Thread-Worker`中，因为num为0而快速loop回到`selector.select()`造成锁无法获得。  

锁竞争的相关代码在这里：
```java
// selector.select()实际调用的是SelectorImpl.lockAndDoSelect()方法
// sun.nio.ch.SelectorImpl#lockAndDoSelect
private int lockAndDoSelect(long var1) throws IOException {
    synchronized(this) {
        if (!this.isOpen()) {
            throw new ClosedSelectorException();
        } else {
            Set var4 = this.publicKeys;
            int var10000;
            synchronized(this.publicKeys) {
                Set var5 = this.publicSelectedKeys;
                synchronized(this.publicSelectedKeys) {
                    var10000 = this.doSelect(var1);
                }
            }
            return var10000;
        }
    }
}
// register实际调用的是SelectorImpl.register()方法
// sun.nio.ch.SelectorImpl#register
protected final SelectionKey register(AbstractSelectableChannel var1, int var2, Object var3) {
    if (!(var1 instanceof SelChImpl)) {
        throw new IllegalSelectorException();
    } else {
        SelectionKeyImpl var4 = new SelectionKeyImpl((SelChImpl)var1, this);
        var4.attach(var3);
        Set var5 = this.publicKeys;
        synchronized(this.publicKeys) {
            this.implRegister(var4);
        }
        var4.interestOps(var2);
        return var4;
    }
}
```
由于`selector.select()`和`selectionKey.register(selector, op)`中的`selector`是同一个对象，而这两个方法的底层调用的都是`SelectorImpl`中的方法，都对`this.publicKeys`进行`synchronized`。所以如果select和register发生在不同的线程，而且select先行执行并阻塞，那么register将等待锁释放而被挂起。而select只有当被register的事件发生时才能释放，register又被挂起了，这样的互相阻塞就就死锁。  
解决方案有2个。  
由于select()方法可以接受一个long类型的参数作为`timeout`。所以可以设置一个合适的时间让其自动释放锁。但这个方法并不太好，因为为了避免这个情况，需要每隔timeout的时间就将线程唤醒造成空转，这显然是不经济的；而且在有客户端连接过来时，每一个新连接，最长都需要等待`timeout`的延时，这显然也是不合理的。  
为此，可以将register事件放到`Thread-Worker`的这个loop中，在其他线程中需要register的时候通过`selector.wakeup()`将`selector.select()`手动唤醒：
