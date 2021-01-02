---
title: 多线程与高并发-AQS原理
date: 2020-12-26 11:24:08
tags: 
  - 多线程
  - AQS
  - 源码
categories: 多线程与高并发
mathjax: false
---

前文中主要线程的原理、进程内线程同步的原理、以及JUC中常用或常问的工具类的用法和特点进行介绍。本文将对JUC中各个工具类的基础——AQS——进行源码级细致分析。
<!--more-->
前文JUC中的工具类中，不使用`synchronized`，是如何实现阻塞和阻塞队列的呢？答案就是，这些类中都存在一个（大部分都命名为`Sync`）继承自`java.util.concurrent.locks.AbstractQueuedSynchronizer`（也就是AQS）的内部类，通过其实例化生成的对象（通常命名为`sync`）进行上锁、阻塞、排队、解锁的过程。  

AQS其实有两个，一个叫`java.util.concurrent.locks.AbstractQueuedSynchronizer`，一个叫`java.util.concurrent.locks.AbstractQueuedLongSynchronizer`。名字上后一个比前一个多了一个Long。通过注释可以看到，后者的state属性是long类型的，而前者的state属性是int类型的，其他都是一样的。后面我们会知道，state其实就是用于标记可分享的锁的数量（对于共享锁而言）或者重入的次数（对于独占锁而言）的，在特殊条件下，int不够用，就会使用long的。两者在逻辑上是一致的，因此在下面的分析过程中，还是会以`AbstractQueuedSynchronizer`进行。


# AQS的基本构造
## 结构
AQS是由一个双向链表构成的，其结点是`java.util.concurrent.locks.AbstractQueuedSynchronizer.Node`。`Node`中有一些属性，来一个个看一下：
```java
// java.util.concurrent.locks.AbstractQueuedSynchronizer.Node
volatile int waitStatus;
volatile Node prev;
volatile Node next;
volatile Thread thread;
Node nextWaiter;
```
* `waitStatus`：当前结点的等待状态。初始化为0，表示是普通的一个同步线程结点；初始化为`CONDITION`(值为`-2`)，表示这个结点是通过`condition.await()`进行阻塞的。总的而言，大部分情况下不需要去判断这些特定的值，只需要根据符号就可以了，正值就表示已经被取消了，负值则表示正处于等待状态。
* `prev`：前驱结点。只有在入队的时候才会被赋值，在出队的时候才会被设为null。
* `next`：后继结点。只有在入队的时候才会被赋值，当某结点被取消（`CACELLED`）的时候会被修改（修改为指向自己以示标记，也为了能更好地GC），在出队的时候才会被设为null。从这种意义上来说，next为null不能表示这个结点就在队尾。
* `thread`：用于记录这个结点表示的thread。在入队的时候赋值，当当被取消或者被设为头结点（开始使用这个线程）时，设为null
* `nextWaiter`：专门用于`Condition`的等待队列，因为`Condition`是独占的，所以只需要一个单向链表就可以了。当`Condition`被唤醒，结点将重新被加入上面的双向链表等待队列去重新获取锁。

waitStatus可选的值及含义如下：   

* `CANCELLED`：值为`1`。表示该线程获取锁的过程（因为timeout超时或interrupt中断或者发生了什么异常）已经被取消了，不在尝试进入临界区。  
* `SIGNAL`：值为`-1`。表示当前结点的后继结点目前已经（或即将）被阻塞了，而且在本结点被唤醒或被取消之后，应该唤醒其后继结点。通常是由那个“即将被阻塞”的结点，修改其前驱结点为`SIGNAL`。    
* `CONDITION`：值为`-2`。表示当前结点正在一个Condition等待队列（`Condition Wait Queue`）中。这个值不会被用于阻塞队列，当从等待队列中结束等待，被转移到阻塞队列中时，会被改设为0。
* `PROPAGATE`：值为`-3`。表示在释放共享锁时，应当将释放过程传播给其他结点。这个值只有头结点才可以在`doReleaseShared`方法中设置。
* 值`0`：用来标记非以上所有状态。


然后，在AQS中，有声明为该Node类型的属性，记录该双向队列的头尾结点。
```java
// java.util.concurrent.locks.AbstractQueuedSynchronizer
private transient volatile Node head;
private transient volatile Node tail;
private volatile int state;
```

* `head`：等待队列的头。因为头结点是当前正在使用的结点，所以`head.waitStatus`绝对不会是`CANCELLED`
* `tail`：等待队列的尾。只能通过入队方法（`enq(Node)`）修改，来添加一个结点
* `state`：同步的状态。对于`ReentrantLock`而言，就是重入的次数，初始化时为0，在同一线程中每lock一次就+1，每unlock一次就-1，当回到0时，就说明这个锁可以释放了。

这个阻塞队列参考自一个名为`CHL`的数据结构（由三个姓氏首字母分别为C、H、L的人发明）。该队列有这样的性质：  

* 这个阻塞队列的头表示目前已经被激活（甚至已经结束）的线程。这也就意味着，参与竞争的是除了队首之外的元素。
* 这是一个准双向链表，通过next和prev指针连接。逆序（prev）保证是连通的，但是正序（next）可能会在某些非队尾结点提前中断（为null或者指向自己），这是为了能够快速标记无效的结点。

## 方法
AQS中有如下比较重要的方法：
```java
// 1. 可供外部调用的获取锁的过程
public final void acquire(int arg); // 获取独占锁
public final void acquireInterruptibly(int arg);// 获取可中断的独占锁
public final void acquireShared(int arg);   // 获取共享锁
public final void acquireSharedInterruptibly(int arg);  // 获取可中断的独占锁
// 2. 可供外部调用的释放锁的过程
public final boolean release(int arg);  // 释放独占锁
public final boolean releaseShared(int arg); // 释放共享锁

// 3. 查询锁的状态，并尝试获取锁，由AQS的派生类具体实现
protected boolean tryAcquire(int arg);  // 尝试获取独占锁
protected int tryAcquireShared(int arg);// 尝试获取共享所
// 4. 查询缩短状态，并尝试释放锁，由AQS的派生类具体实现
protected boolean tryRelease(int arg);  // 尝试释放独占锁
protected boolean tryReleaseShared(int arg);// 尝试释放共享锁

// 4. 用于 Lock.tryLock(long timeout, TimeUnit unit)
public final boolean tryAcquireNanos(int arg, long nanosTimeout);   // 尝试一定时间去获取独占锁，内部会调用tryAcquire 和 doAcquireNanos
public final boolean tryAcquireSharedNanos(int arg, long nanosTimeout); // 尝试一定时间去获取共享锁，内部会调用tryAcquireShared和doAcquireSharedNanos

// 5. 内部对阻塞队列操作的过程
final boolean acquireQueued(final Node node, int arg);  // 对独占锁阻塞队列的操作
private void doAcquireInterruptibly(int arg);   // 对可中断独占锁阻塞队列的操作
private boolean doAcquireNanos(int arg, long nanosTimeout); // 在一定时间内对独占锁阻塞队列的操作
private void doAcquireShared(int arg);  // 对共享锁阻塞队列的操作
private void doAcquireSharedInterruptibly(int arg); // 对可中断共享锁阻塞队列的操作
private boolean doAcquireSharedNanos(int arg, long nanosTimeout);   // 在一定时间内对共享锁阻塞队列的操作

// 6. 内部唤醒被阻塞线程的方法
private void unparkSuccessor(Node node);
private void doReleaseShared();

// 7. 因意外，取消本次获取锁过程
private void cancelAcquire(Node node);
```
方法稍微分一下组：

1. 暴露给各个类型的锁的实现类，可直接调用的用于加锁的方法。根据类型可分为独占锁和共享锁，如果这个锁是可以被打断的（应用用于`Lock.lockInterruptibly()`则可以使用带有Interruptibly的方法。
2. 暴露给各个类型的锁的实现类，可直接调用的用于解锁的方法。比如各个`Lock.unlock()`、`CountDownLatch.countdown()`之类的都会调用本组的方法。
3. 查询锁状态，尝试获取锁的过程。这2个方法由各AQS的派生类去实现，直接调用AQS中这2个方法会抛出`UnsupportOperation`异常。其参数`arg`通常是指想要获取或释放的锁的次数。而返回的是获取的结果，对于`tryAcquireShared`而言返回值是本次获取后剩余的共享锁的数量，也就是说负数表示获取失败、0表示获取成功但是后续就***可能***无法获取了，整数表示后续***可能***仍然能获取成功（所谓***可能***，就是说后续在再次上锁的时候，还是需要再判断一下）；而对于`tryAcquire`而言，就表示此次获取是true成功的或者false失败的。
4. 查询锁状态，尝试释放锁的过程。这2个方法由各AQS的派生类去实现，直接调用AQS中这2个方法会抛出`UnsupportOperation`异常。其参数`arg`通常是指想要获取或释放的锁的次数。而返回的是获取的结果，true成功的或者false失败的。
5. 这两个是专门用于`Lock.tryLock(long time, TimeUnit unit)`这种类型的方法，在其内部还是会调用`tryAcquireShared`和`doAcquireSharedNanos`这两个方法。
6. 对于第3组方法调用后返回尝试获取锁失败的情况，会先将本线程加入阻塞队列，然后调用本组方法，对阻塞队列进行操作，对需要阻塞的，会在本组方法中阻塞。
6. 在调用第2组的方法后，会首先调用第4组进行尝试获取锁，若果成功了，则通过本组方法，对阻塞的线程进行唤醒。
7. 当在获取锁的过程中（已经进入阻塞队列，或者被从阻塞状态唤醒后但还没来得及修改状态的时候）发生意外时，通过该方法兜底。

## 方法执行顺序
用流程图解释一下可以获得锁和无法获得锁的过程。  
![CallStackOfAQS](CallStackOfAQS.png)  

## 具体源码分析
看完大致流程，接下来到源码中仔细看一下，AQS是怎么做锁实现无关部分的控制的。
### 上锁入口
```java
// AbstractQueuedSynchronizer#acquire
public final void acquire(int arg) {
    if (!tryAcquire(arg) && acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
// AbstractQueuedSynchronizer#acquireInterruptibly
public final void acquireInterruptibly(int arg) throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (!tryAcquire(arg))
        doAcquireInterruptibly(arg);
}
// AbstractQueuedSynchronizer#acquireShared
public final void acquireShared(int arg) {
    if (tryAcquireShared(arg) < 0)
        doAcquireShared(arg);
}
// AbstractQueuedSynchronizer#acquireSharedInterruptibly
public final void acquireSharedInterruptibly(int arg) throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)
        doAcquireSharedInterruptibly(arg);
}
```
大致都是差不多的，在进入上锁入口后，调用对应的`tryAcquireXXX`方法（`tryAcquire`、`tryAcquireShared`），如果失败，则进入相应的`doAcquireXXX`方法（`acquireQueued`、`doAcquireInterruptibly`、`doAcquireShared`、`doAcquireSharedInterruptibly`）。这里`tryAcquireXXX`失败，根据锁的形式会有一些区别，共享锁的话因为返回的是尝试获取后还剩余的锁的数量，所以`<0`表示获取失败；而独占锁直接返回成功或失败。  
这里不太一样的地方在于，由于`acquireQueued`方法会返回在阻塞过程中是否发生了中断（不需要反馈中断的，即使发生了中断也视为没有中断过），所以把`acquireQueued`放在了`if`的条件中，为真则触发`selfInterrupt`也就是：
```java
// AbstractQueuedSynchronizer#selfInterrupt
static void selfInterrupt() {
    Thread.currentThread().interrupt();
}
```

### 尝试获取锁失败后 
入口还是比较简单的，由于`tryAcquireXXX`是由各个派生类自己实现的，而且如果try acquire成功后，就直接结束lock过程了，所以接下来看看try acquire失败后，如何对阻塞队列进行处理。  

查看各个方法，都需要执行的是addWaiter方法。独占的两个传入的第一个参数是`Node.EXCLUSIVE = null`，共享的两个传入的是`NODE.SHARED = new Node()`。
```java
private Node addWaiter(Node mode) {
    Node node = new Node(Thread.currentThread(), mode);
    Node pred = tail;
    if (pred != null) {
        node.prev = pred;
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    enq(node);
    return node;
}
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        if (t == null) {    // 队列为空，则懒初始化
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            node.prev = t;  // 将node加入队尾
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
Node(Thread thread, Node mode) {
    this.nextWaiter = mode;
    this.thread = thread;
}
```
`addWaiter`还是比较好理解的，就是通过CAS操作，将本线程对应的结点放到同步队列的队尾。如果CAS操作失败了，就通过`for(;;)`进行无限循环（也就是自旋），直到成功为止。特别的，如果队列为空，则在此时再进行初始化（懒初始化）。
可是为什么要将锁的模式放到`nextWaiter`字段呢？前面说过了，`nextWaiter`是用来存放Condition的等待队列的。这是因为Condition只能用于独占锁中，而`Node.EXCLUSIVE = null`、`NODE.SHARED = new Node()`，所以通过`nextWaiter == null`就可以判断这个锁是独占的还是共享的。

接下来分锁类型看看加入队列之后，具体都干了些什么。
#### 独占锁尝试获取失败后
首先是独占锁的`acquireQueue`。
```java
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {  // 自旋
            final Node p = node.predecessor();  // 获取node的前驱结点
            if (p == head && tryAcquire(arg)) {
                // 如果前驱是头结点，且本线程尝试获取锁成功
                setHead(node); // 本结点升级为头结点
                p.next = null; // 头结点释放
                failed = false;
                return interrupted;
            }
            if (shouldParkAfterFailedAcquire(p, node)   // 在尝试失败后，需要park
            && parkAndCheckInterrupt()) //执行park
                // park时发生了中断，记录下来
                interrupted = true;
        }
    } finally {
        if (failed)
            // 发生了错误，取消获取锁
            cancelAcquire(node);
    }
}
```
还是利用`for(;;)`自旋。然后获取node的前驱结点。因为队首元素是正在被执行的线程（甚至已经执行结束了），所以如果node的前驱是对手元素的话，那么node就是队列中最优先可以去获取的结点了。接下来我们跳过`if (p == head && tryAcquire(arg))`，先看一下下面的，因为这是在一个自旋之中，下面执行完了，还是会执行到这边。  
下面是一个if语句，包含两个判断条件，如果第一个是false的话，就短路第二个以及if块中的代码。第一个条件是`shouldParkAfterFailedAcquire(p, node)`。
```java
// AbstractQueuedSynchronizer#shouldParkAfterFailedAcquire
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    int ws = pred.waitStatus;
    if (ws == Node.SIGNAL)
        return true;
    if (ws > 0) {
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    } else {
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}
```
所谓应不应该park，是要确认前面的结点的状态是否已经设置好了。只有当前一个结点的`waitStatus`被设置为`SIGNAL`，那么本结点在前一个结点的锁释放之后，本结点才能被通知唤醒。所以`ws == Node.SIGNAL`表示前一个结点已经设置好了，本结点可以安心地去睡了；`ws>0`表示前面的结点已经被取消了，那么就循环向前寻找本结点真正有效（`waitStatus<0`)的前驱结点（然后等下一次自旋再来判断是否已经设置好了）;`else`的话，就表示前驱结点还是有效的，那么就通过CAS将其状态改为SIGNAL，至于成功了还是失败了，不能在这里浪费时间，等下一次自旋的时候再去判断。

接下来就可以进行park了。
```java
private final boolean parkAndCheckInterrupt() {
    LockSupport.park(this);
    return Thread.interrupted();
}
```
调用`LockSupport.park()`来阻塞线程。当某处唤醒本线程后，返回阻塞或称中是否发生了中断。  

接下来再到上面的`if`那边：
```java
// AbstractQueuedSynchronizer#acquireQueued
final Node p = node.predecessor();  // 获取node的前驱结点
if (p == head && tryAcquire(arg)) {
    // 如果前驱是头结点，且本线程尝试获取锁成功
    setHead(node); // 本结点升级为头结点
    p.next = null; // 头结点释放
    failed = false;
    return interrupted;
}
// AbstractQueuedSynchronizer#setHead
private void setHead(Node node) {
    head = node;
    node.thread = null;
    node.prev = null;
}
```
当被唤醒后，通过自旋，再次来到这边，如果node已经排到优先级最高处（其前驱结点为头结点），则再次tryAcquire。  
这里为什么要再次tryAcquire而不是直接占用锁呢？这是为了兼容公平与非公平两种锁。前一篇文章已经说了，ReentrantLock可以在构造时设置该可重入锁是公平的还是非公平的。所谓公平与非公平的区别，就是正好执行到类似于`lock.lock()`语句处的线程，是先进入阻塞队列（那么对于已经进入阻塞队列的线程就是公平的，大家一起排队），还是先不管三七二十一尝试占有一下锁（那么对于已经进入阻塞队列的线程就是非公平的，后来的可能会先执行）。那么对于后一种情况（非公平的），这里就只能通过tryAcquire去竞争一下。如果竞争失败了，只能再次park，等待下一次被唤醒；如果竞争成功了，则自己成为阻塞队列的头结点，然后一路退出调用栈，直到回到`lock.lock()`处，就可以继续执行后面的代码了。  



#### 共享锁获取失败后
对于共享锁而言，当`tryAcquireShared()`之后，直接调用`doAcquireShared(arg)`。
```java
// AbstractQueuedSynchronizer#doAcquireShared
private void doAcquireShared(int arg) {
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            final Node p = node.predecessor();
            if (p == head) {
                int r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    if (interrupted)
                        selfInterrupt();
                    failed = false;
                    return;
                }
            }
            if (shouldParkAfterFailedAcquire(p, node) && parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```
可以看到，除了把`addWaiter(Node.SHARED)`搬到了里面之外，基本上是一样的。  
后半段也是`shouldParkAfterFailedAcquire`和` parkAndCheckInterrupt`。在被唤醒之后，尝试获取共享锁`tryAcquireShared(arg)`，获取成功的话则将自己设为设置阻塞队列的头结点，并传播，然后一路返回到自己在业务代码中被阻塞的位置，继续执行。  
这里需要注意的是这个函数`setHeadAndPropagate(node, r)`。`node`就是当前结点，`r`就是本结点获取锁之后，可能还剩的可占用锁的数量。设为头结点这个可以理解，但为什么要propagate呢。propagate是繁殖、传播的意思，因为共享锁是允许被多个线程持有的，一旦有一个线程被唤醒，只要剩余的共享锁的数量足够，就可以将其他的线程唤醒，所以要通过这个函数将队列中的其他线程唤醒，让他们也来尝试获取这个共享锁（毕竟`r`是不准确的，所以这些线程还是要经历“竞争”这个过程）。
```java
// AbstractQueuedSynchronizer#setHeadAndPropagate
private void setHeadAndPropagate(Node node, int propagate) {
    Node h = head; // 记录当前头结点，也就是本结点的前驱结点
    setHead(node); // 将本结点设为头结点
    if (propagate > 0 || h == null || h.waitStatus < 0 || (h = head) == null || h.waitStatus < 0) {
        // 如果传入的可获取共享锁数量是足够的
        // 或者而且原来的头结点是有效的
        // 或者现在的头结点是有效的
        // 则
        Node s = node.next;
        if (s == null || s.isShared())
            // 若有后继结点且后继结点是共享锁，则继续释放共享锁
            doReleaseShared();
    }
}
// AbstractQueuedSynchronizer#doReleaseShared
private void doReleaseShared() {
    for (;;) {  // 不断循环
        Node h = head;  // 获得当前的头结点（可能会变化）
        if (h != null && h != tail) {
            // 队列中存在被阻塞的结点（不算头结点）
            int ws = h.waitStatus;
            if (ws == Node.SIGNAL) {
                // 如果需要唤醒后继结点
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    // 将其状态改为0，表示正在释放后继结点，失败了就自旋
                    continue;
                // 状态修改好了，释放后继结点
                unparkSuccessor(h);
            }
            else if (ws == 0 && !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                // 释放完毕后，尝试将状态修改为需要传播
                continue;                
        }
        if (h == head)
            // 如果头结点没变，则结束循环
            break;
    }
}
```

### 释放锁入口
```java
// AbstractQueuedSynchronizer#release
public final boolean release(int arg) {
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
// AbstractQueuedSynchronizer#releaseShared
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
```
不管要不要考虑中断，锁释放的过程都是一致的，所以只有独占锁和共享锁的2种释放方式。  
首先都是`tryRelease`或者`tryReleaseShared`。它们的主要作用就是修改`state`的值。  
然后在try成功之后根据独占或共享锁，分别执行`unparkSuccessor()`或`doReleaseShared()`具体执行所释放的阻塞队列操作。  

#### 独占锁释放时的操作
独占锁执行`unparkSuccessor(Node head)`。由于锁是独占的，所以传入的head在此过程中不会发生变化。  
```java
private void unparkSuccessor(Node node) {
    int ws = node.waitStatus;
    if (ws < 0)
        // 如果头结点的waitStatus是有效的，则将其先置为0
        // 不过就算失败了也没有关系
        compareAndSetWaitStatus(node, ws, 0);
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        // 获取头结点的后继结点，如果是null或者是无效的，那么就倒序寻找离头结点最近的有效结点
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)
        // 如果找到了，就unpark
        LockSupport.unpark(s.thread);
    }
```
首先将waitStatus置为0，失败了也没有关系。这里`waitStatus`只要`<0`，那么只要其他地方的程序写的没有问题，就必然是`SIGNAL`。因为几个负值，`CONDITION`只能用于condition等待队列中，`PROPAGATE`只能用于共享锁。  
然后获取头结点的后继结点（因为根据`SIGNAL`的要求，应当唤醒后继结点）。如果获取的后继结点是无效的，或者next指针指向了null，那么就从tail开始倒序查找（前面也说了，next可能是不连通的，但prev是可靠的连通的）。  
最后，如果找到了的话，就将这个结点对应的线程唤醒。  

这时，就回到了`acquireQueue()`方法中的自旋循环中：
```java
// AbstractQueuedSynchronizor#acquireQueue
for (;;) {  // 自旋
    final Node p = node.predecessor();  // 获取node的前驱结点
    if (p == head && tryAcquire(arg)) {
        // 如果前驱是头结点，且本线程尝试获取锁成功
        setHead(node); // 本结点升级为头结点
        p.next = null; // 头结点释放
        failed = false;
        return interrupted;
    }
    if (shouldParkAfterFailedAcquire(p, node)
    && parkAndCheckInterrupt())     // 从这里被唤醒
        // 因为parkAndCheckInterrupt()返回了true
        // 所以在park时发生了中断，记录下来
        interrupted = true;
}
// AbstractQueuedSynchronizer#setHead
private void setHead(Node node) {
    head = node;
    node.thread = null;
    node.prev = null;
}
```
这个线程从`parkAndCheckInterrupt()`中被唤醒。重新自旋回到上面，获取这个被唤醒的结点的前驱结点（因为是被头结点唤醒的，头结点只会唤醒其后继结点，而且线程是阻塞的，只有一个被唤醒，这就意味着此时`head`属性不会发生变化，`node`的前驱结点`p`必然是`head`。所以直接进行`tryAcquire`。  
这里需要解释一下，为什么还需要进行`tryAcquire`而不能让`node`直接占有锁呢？这就要考虑到前一篇中的公平锁与非公平锁了。在线程阻塞排队时，公平锁根据FIFO的原则按照先进先出的顺序被阻塞和唤醒；而非公平锁，则除了FIFO之外，还需要与刚进入临界区，还没有进入FIFO队列的线程进行竞争。  
如果`tryAcquire`失败了，那么就需要重新park，等待下一次唤醒。如果成功了，就执行`if`中的3行，也就是将本结点设为头结点，释放头结点（从交给GC），然后结束`acquireQueue`方法，并逐层返回至业务代码（调用类似`lock.lock()`处，结束阻塞，继续向下。直到这个线程也执行到`lock.unlock()`释放队列中的下一个线程的阻塞。  

#### 共享锁释放时的操作  
共享锁的`doReleaseShared()`是这样写的：
```java
// AbstractQueuedSynchronizer#doReleaseShared
private void doReleaseShared() {
    for (;;) { // 不断循环
        Node h = head;
        if (h != null && h != tail) {
            int ws = h.waitStatus;
            if (ws == Node.SIGNAL) {
                // 如果头结点的waitStatus是SIGNAL的话
                // 就将其置为0，并唤醒1个后继结点
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    // 如果将h的waitStatus从SIGNAL置为0失败，就不断自旋直到成功
                    continue;
                // h的waitStatus从SIGNAL置为0成功
                // 释放1个后继结点
                unparkSuccessor(h);
            }
            else if (ws == 0 &&
                        !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                // 如果头结点waitStatus是0
                // 则尝试将其置为PROPAGATE
                // 失败的话就自旋
                continue; 
        }
        if (h == head)
            // 在此过程中，如果头结点没有发生变化，就结束
            break;
    }
}
```
这里有3个状态的判断。  
首先判断当前的头结点的`waitStatus`是否是`SIGNAL`。因为`SIGNAL`状态要求在自己释放或者`unpark`后，要唤醒后继结点。为了防止重复唤醒，所以先将`waitStatus`置为`0`，成功后再`unparkSuccessor`。  
如果不是`SIGNAL`而是`0`的话，则该结点可能是刚初始化的结点，将其设为`PROPAGATE`，失败则自旋。  
在前两个都执行完后，如果头结点发生了变化，那么再次自旋，本线程承担新头结点的唤醒工作。直到头结点不再发生变化，结束`doReleaseShared`，这时，层层返回，直到业务层代码，继续执行。  
而后继结点被unpark之后，就会开始在它的`doAcquireShared`中继续执行。在其自旋循环中：
```java
// AbstractQueuedSynchronizer#doAcquireShared
for (;;) {
    final Node p = node.predecessor();
    if (p == head) {
        int r = tryAcquireShared(arg);
        if (r >= 0) {
            setHeadAndPropagate(node, r);
            p.next = null; 
            if (interrupted)
                selfInterrupt();
            failed = false;
            return;
        }
    }
    if (shouldParkAfterFailedAcquire(p, node) && parkAndCheckInterrupt())
        interrupted = true;
}
// AbstractQueuedSynchronizer#setHeadAndPropagate
private void setHeadAndPropagate(Node node, int propagate) {
    Node h = head; 
    setHead(node);
    if (propagate > 0 || h == null || h.waitStatus < 0 || (h = head) == null || h.waitStatus < 0) {
        Node s = node.next;
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
```
结束park后从`parkAndCheckInterrupt`返回，然后掉头回到上面。获得当前结点`node`的前驱结点，如果它不是是头结点，那么重新去park。如果是头结点，那么就将本结点设为头结点并传播（setHeadAndPropagate）、该抛中断异常就抛中断异常（selfInterrupt)，然后返回调用栈直到业务代码（比如`lock.lock()`）并结束阻塞，继续向下执行到`lock.unlock`释放本线程的共享锁。  
这里还有最后一个方法`setHeadAndPropagate(Node node, int propagate)`。一起来看一下。
入参`node`就是当前结点，`int`参数`propagate`就是传入的r，也就是`node`在获取锁之后，可能还剩余的共享锁的数量。然后再来看代码。  
`setHead(node)`没什么好说的，主要就是这个`if`语句，一个一个来分析一下。  

* `propagate > 0`：进入条件是`r>=0`，所以这里是有可能`propagate == 0`从而不满足的。如果可能已经没有剩余的共享锁供阻塞队列中的其他线程去竞争，就不要去唤醒它们了。等其他占有锁的线程释放之后，依然有机会释放它们。  
* `h == null || h.waitStatus < 0`：这两个可以一起看，`h`存在且其`waitStatus`指示它是有效的。`h`是上面获取的头结点。但是明明在`doReleaseShared`中，调用`unparkSuccessor`前已经通过CAS将`waitStatus`设为0了呀，这里怎么会`<0`呢？这只能说明，就在此时（在原线程中将原来的头结点`waitStatus`设为0之后，在本线程中执行`setHead(node)`之前），有其他的线程释放了共享锁，这样就进入了`doReleaseShared`的`if (ws == 0 &&!compareAndSetWaitStatus(h, 0, Node.PROPAGATE))`语句，成功将原头结点的`waitStatus`设为了`PROPAGATE(-3)`。  
* `(h = head) == null || h.waitStatus < 0`：前一个`h.waitStatus<0`是常态，因为上面这种情况发生的概率比较小。那么在`propagate == 0`时大部分情况都会落到这一个判断中。这里的`head`很有可能就是入参`node`，也就是当前线程结点，因为才刚被设为头结点，所以`waitStatus`应当还是`SIGNAL`。  

对于后两个情况，既然`propagate == 0`已经是0了，为什么还要去唤醒阻塞队列中后面的线程呢？这个在源码的注释中也提到了。其实被唤醒也没有关系，如果此时共享锁不足，会在`doReleaseShared`里的自旋之后继续`park`。

#### PROPAGATE状态的作用
到这里，似乎还没有完全弄懂PROPAGATE这个状态的作用。也确实，这个状态并不是在一开始就存在的，而是在jdk低版本中出现bug之后才增加的。[报告的bug](https://bugs.java.com/bugdatabase/view_bug.do?bug_id=6801020)和[修复的代码](http://gee.cs.oswego.edu/cgi-bin/viewcvs.cgi/jsr166/src/main/java/util/concurrent/locks/AbstractQueuedSynchronizer.java?r1=1.73&r2=1.74)。可以看到这是一个2009年的bug了。那时候我还只是一个用Pascal做NOIP、只会一点点vb写点小玩具的高中生。。。  

假设没有PROPAGATE，我们来设想一种状态。  
有2个线程`t1``和t2`同时向获取共享锁但是由于锁不足被阻塞着。这时，有2个线程`t3`和`t4`同时释放共享锁。  

* 时刻1：`t3`线程`tryReleaseShared`成功，这时`state = 1`。调用`unparkSuccessor`将头结点的`waitStatus`设为`0`，然后唤醒阻塞队列中优先级较高的`t1`。
* 时刻2：`t1`线程调用`tryAcquireShared`成功，`state`回到`0`，并作为`propagate`值传入`setHeadAndPropagate`。
* 时刻3：`t4`线程`tryReleaseShared`成功。但是在`releaseShared`方法中不满足`h.waitStatus != 0`，所以不唤醒`t2`。
* 时刻4：回到`t1`，在`setHeadAndPropagate`中，执行`setHead`将自己升级为头结点。由于此时`propagate = 0`，不满足`propagate > 0`的条件，不执行`unparkSuccessor(node)`。因此`t1`不唤醒`t2`。  
 
所以这样来看，如果`t1`不释放的话，`t2`就永远不会被唤醒了。  
```java
// 原版的releaseShared方法
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
// doAcquireShared方法，新旧版基本没有变化
private void doAcquireShared(int arg) {
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            final Node p = node.predecessor();
            if (p == head) {
                int r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null;
                    if (interrupted)
                        selfInterrupt();
                    failed = false;
                    return;
                }
            }
            if (shouldParkAfterFailedAcquire(p, node) && parkAndCheckInterrupt())
                interrupted = true;
            }
        } finally {
            if (failed)
            cancelAcquire(node);
    }
}
// 原版的setHeadAndPropagate方法
private void setHeadAndPropagate(Node node, int propagate) {
    setHead(node);
    if (propagate > 0 && node.waitStatus != 0) {
        Node s = node.next;
        if (s == null || s.isShared())
            unparkSuccessor(node);
    }
}
// 原版unparkSuccessor
private void unparkSuccessor(Node node) {
    compareAndSetWaitStatus(node, Node.SIGNAL, 0);
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)
        LockSupport.unpark(s.thread);
}
```
这个过程大致如下图：  
![Bug Without PROPAGATE](BugWithoutPROPAGATE.png)
按照预期，应该在`t4`的`releaseShared`或者`t1`的`setHeadAndPropagate`中唤醒`t2`，结果都错过了。

在旧版的代码中，不能将`setHeadAndPropagate`中的条件判断简单修改为`if (propagate > 0 || node.waitStatus < 0)`，因为在上面这种线程切换方式下，这两个条件依然是无法满足的。  
为此，新版的代码中增加了`doReleaseShared`方法和`PROPAGATE`状态。  
我们来看一下在新代码的情况下，如果发生了上述线程切换过程，会怎么样：

* 时刻1：`t3`线程`tryReleaseShared`成功，这是`state = 1`。调用`doReleaseShared`方法。这是由于阻塞队列中存在`t1`和`t2`，所以头结点的状态必然是`SIGNAL`，所以通过CAS将其置为`0`（如果失败的话，那就是`t4`在与`t3`竞争，那把`t4`当做`t3`就好了，也是一样的），然后通过`unparkSuccessor`唤醒`t1`线程。
* 时刻2：`t1`线程被唤醒，恢复在`doAcquireShared`的执行。通过`for(;;)`自旋后，因为node的前驱必然是头结点，所以可以调用`tryAcquireShared`。由于此时`state = 1`，所以有剩余的共享锁，获取之后`state`又回到`0`。接下来在`r >= 0`的条件下，将`r = 0`作为`propagate`传入`setHeadAndPropagate`。
* 时刻3：`t4`开始释放共享锁。`tryReleaseShared`成功之后（这样`state`变成了`1`），现在不需要再进行任何判断，直接进入`doReleaseShared`。由于`t1`还没将自己升级为头结点，所以这是`t4`发现头结点（还是原来的头结点）的状态变成了0，就通过CAS将其设为了`PROPAGATE(-3)`。
* 时刻4：`t1`继续在`setHeadAndPropagate`中执行，将自己设为头结点，然后虽然传入的`propagate`（即过时的`state`）是`0`，但是头结点的状态已经被`t4`修改成了`PROPAGATE(-3)`，满足`waitStatus < 0`，所以可以尝试唤醒后继节点。这样，`t2`就可以被唤醒了。  

当然，如果时刻4和时刻3交换一下，也没有关系，也就是`t1`先`setHead`，然后`t4`再释放，那么`t4`中获得的`head`就是`t1`的结点了，这个结点的状态必然是`SIGNAL`所以，会由`t4`来唤醒`t2`。  

从这个角度来说的话，`t4`线程将头结点的状态设为`PROPAGATE`的目的就是：我知道有个线程刚刚被唤醒并获得了共享锁，但还没来得及将自己设为阻塞队列的头结点（因为此时`t4`查询到的头结点的`waitStatus`是`0`，而且因为自己还在队列中，所以肯定不是队列才刚刚初始化造成`waitStatus = 0`的，那就只可能是被另一个刚刚释放锁的线程置为`0`的了），那么这个还没来得及将自己设为头结点的结点，因为我这里又释放了一个共享搜，你待会儿记得通知一下其他被阻塞的线程，可以去抢我释放的这个共享锁了。  

所以，换句话说，如果没有`t4`插一脚的话，`t1`读取到的`waitStatus < 0`的条件就不满足了，就不会去唤醒其他线程（当然，因为没有`t4`插一脚，就不会有额外的共享锁供准备被唤醒的线程去获取，自然也就不需要唤醒后继的线程了）。  

```java
// 现在的releaseShared方法 jdk1.8.0_161
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
// 现在的doAcquireShared方法，没有发生关键性变化
// 现在的setHeadAndPropagate方法
private void setHeadAndPropagate(Node node, int propagate) {
    Node h = head; 
    setHead(node);
    if (propagate > 0 || h == null || h.waitStatus < 0 || (h = head) == null || h.waitStatus < 0) {
        Node s = node.next;
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
// 新增的doReleaseShared方法
private void doReleaseShared() {
    for (;;) {
        Node h = head;
        if (h != null && h != tail) {
            int ws = h.waitStatus;
            if (ws == Node.SIGNAL) {
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    continue;
                unparkSuccessor(h);
            }
            else if (ws == 0 && !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                continue; 
        }
        if (h == head)
            break;
    }
}

```

### Condition下的等待和通知
前面是共享锁和独占锁的加锁、释放和竞争过程。相对而言Condition就简单多了。  
Condition

#### Condition的基本结构
Condition是一个接口，具体的实现由`AbstractQueuedSynchronizer.ConditionObject`内部类来实现。
```java
private transient Node firstWaiter;
private transient Node lastWaiter;
```
其中有两个成员属性，用来记录首个waiter结点，和末尾waiter结点。再联系到Node中存在nextWaiter属性，可以知道，每一个Condition都对应一个等待队列，这个队列是一个单向链表。结构比阻塞队列要简单的多。  

#### Condition的阻塞
当调用`condition.await()`时，开始阻塞：
```java
// ConditionObject#await()
public final void await() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    // 将节点添加到waiter队列
    Node node = addConditionWaiter();
    // 记录并释放此时的重入次数
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    while (!isOnSyncQueue(node)) {
        // 如果不在阻塞队列中了，在waiter队列中进行park
        LockSupport.park(this);
        // 下面是在waiter队列中被通知唤醒后
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            // 如果是因为中断而被唤醒的，直接break
            break;
    }
    // 在阻塞队列中竞争，竞争成功后，根据需要进行中断或恢复中断标志
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
```
大致流程就是，新建一个结点，并将这个节点加入到等待队列中，然后将本线程的重入次数记录下来，并且释放这些重入次数。接下来通过`LockSupport.park`，使当前线程进入等待状态，每一次被唤醒，就检查本线程是否已经进入阻塞队列，如果不在阻塞队列中，则继续等待。当被唤醒并且本线程已经在阻塞队列中时，说明`condition.signal`系列函数被执行了，需要去争抢锁的占有权，因此进入阻塞队列。争抢成功后，根据需要抛出`InterruptException`异常进行中断，或者调用`Thread.interrupt()`恢复中断标志位。  

先看如何加入等待队列：
```java
private Node addConditionWaiter() {
    // 获取目前的等待队列队尾节点
    Node t = lastWaiter;
    if (t != null && t.waitStatus != Node.CONDITION) {
        // 如果队尾节点是CANCELLED状态，将其从等待队列中清除
        unlinkCancelledWaiters();
        t = lastWaiter;
    }
    // 创建节点，其waitStatus为CONDITION
    Node node = new Node(Thread.currentThread(), Node.CONDITION);
    if (t == null)
        // 如果队伍为空，则将节点作为等待队列队首节点
        firstWaiter = node;
    else
        // 将本节点追加到队尾
        t.nextWaiter = node;
    lastWaiter = node;
    return node;
}
```
整个流程比较简单。唯一需要注意的有这两个地方：

* 为什么通过`t.waitStatus != Node.CONDITION`就可以判断队尾节点的状态？因为`Condition`中的节点，其可选的状态原则上只有`CANCELLED`和`CONDITION`两种。那么如果不是`CONDITION`，就一定是被取消的或者其他非法的状态。  
* 如果倒数第二个结点也是`CANCELLED`怎么办？可以自己看一下`unlinkCancelledWaiters`的源码，这里面从头到尾进行的遍历，把所有的`!= Node.CONDITION`的节点都清除掉了。  

接下来是释放并记录重入次数，这一步很重要。由于进入Condition状态时，本线程被挂起，需要其他阻塞队列中的线程去竞争，如果重入次数不清除，那么后续从阻塞队列中来竞争的线程，会发现剩余的锁不足。而如果不记录重入次数，在本线程结束condition的等待并获得线程原本的锁后，进行释放来清除重入次数时，就会发生错误。  
```java
final int fullyRelease(Node node) {
    boolean failed = true;
    try {
        int savedState = getState();
        // 释放锁
        if (release(savedState)) {
            failed = false;
            // 返回重入次数
            return savedState;
        } else {
            throw new IllegalMonitorStateException();
        }
    } finally {
        if (failed)
            node.waitStatus = Node.CANCELLED;
    }
}
```

判断是否在阻塞队列中的目的，是确保本节点不会被阻塞队列中的前驱结点唤醒；等待队列中被唤醒后，再次判断是否在阻塞队列中，可以确保接下来参与竞争时不会发生错误。  
检查是否在阻塞队列中还是比较简单粗暴的，最坏的情况就是从尾到头遍历一遍阻塞结点。
```java
// AbstractQueuedSynchronizer#isOnSyncQueue
final boolean isOnSyncQueue(Node node) {
    if (node.waitStatus == Node.CONDITION || node.prev == null)
        return false;
    if (node.next != null) 
        return true;
    return findNodeFromTail(node);
}
// AbstractQueuedSynchronizer#findNodeFromTail
private boolean findNodeFromTail(Node node) {
    Node t = tail;
    for (;;) {
        if (t == node)
            return true;
        if (t == null)
            return false;
        t = t.prev;
    }
}
```
这样，进入Condition的等待状态就差不多结束了。

#### Condition的释放
condition通知释放时可通过`condition.signal()`来唤醒等待时间最长的线程（也就是等待队列中的首个），也可以通过`condition.signalAll()`来唤醒所有。通常会使用`signalAll()`。  

在通知前，首先会判断当前模式是不是独占的（因为Condition不支持共享模式）。  
之后调用`doSignalAll()`方法执行具体的通知逻辑。`doSignalAll()`中会从头到尾遍历等待队列，并调用`transferForSignal()`方法将这些节点的状态从`CONDITION`修改为`0`、将他们依次加入阻塞队列。  
```java
// AbstractQueuedSynchronizer.ConditionObject#signalAll
public final void signalAll() {
    // 判断是否是独占模式
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    Node first = firstWaiter;
    if (first != null)
        // 通知等待队列中的所有结点
        doSignalAll(first);
}
// AbstractQueuedSynchronizer.ConditionObject#doSignalAll
private void doSignalAll(Node first) {
    lastWaiter = firstWaiter = null;
    // 从first开始往后遍历等待队列中的所有结点
    do { transfer
        Node next = first.nextWaiter;
        first.nextWaiter = null;
        // 转移每一个结点至阻塞队列
        transferForSignal(first);
        first = next;
    } while (first != null);
}
// AbstractQueuedSynchronizer#transferForSignal
final boolean transferForSignal(Node node) {
    // 修改结点装从CONDITION至0
    if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
        return false;
    // 加入阻塞队列
    Node p = enq(node);
    int ws = p.waitStatus;
    if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
        // 如果Condition被取消，或者修改状态为SIGNAL失败，就直接提前将其唤醒（没有关系，反正还是要通过acquireQueue方法竞争锁）
        LockSupport.unpark(node.thread);
    return true;
}
```
在被强制唤醒、或在阻塞队列中排队结束被唤醒之后，原来在等待状态的线程，就会恢复在`await()`中的执行，继续下面的过程：
```java
// AbstractQueuedSynchronizer.ConditionObject#await()
if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
    interruptMode = REINTERRUPT;
if (node.nextWaiter != null) // clean up if cancelled
    unlinkCancelledWaiters();
if (interruptMode != 0)
    reportInterruptAfterWait(interruptMode);
```
可以看到，这里将之前保存的`savedState`作为参数传入了`qcquireQueue`，这样当该线程争取到锁之后，就会立刻将state恢复为`condition.await()`之前的重入次数。  
在获取锁之后，通过`unlinkCancelledWaiters`清理等待队列，通过`reportInterruptAfterWait`发出`InterruptException`中断异常或用`Thread.interrupt()`恢复中断标记。然后一路清空调用栈，继续`condition.await()`之后的业务代码。

## 结束
至此，AQS内阻塞队列和等待队列的流程就梳理完成了。  
可以看出来，锁的竞争过程本身并不复杂，但是在多线程下，这个问题的复杂度立刻就升上了，特别是在高并发下，两个看似相邻的指令，可能会因为高并发的问题，中间被其他线程插入很多的甚至可能会修改状态的其他指令。  
不得不佩服大牛们设计的算法，也不得不感谢先行的前辈们为我们踩坑。  

# 几个常用AQS实现的具体实现方式
## ReentrantLock 可重入锁
先看一下`ReentrantLock`是如何实现的。

### 公平与非公平
首先看一下加锁。`ReentrantLock.lock()`中只有一句话：`sync.lock()`。而根据`new ReentrantLock(boolean fair)`中`fair=true`或`fair=false`（默认为`false`，sync可能有2种实现：`ReentrantLock.FairSync`和`ReentrantLock.NonfairSync`，也就是公平锁与非公平锁。
```java
// ReentrantLock.FairSync
final void lock() {
    acquire(1);
}
// ReentrantLock.NonfairSync
final void lock() {
    if (compareAndSetState(0, 1))
        // 通过CAS将state从0设为1成功，即说明抢占成功
        // 将锁的独占线程设为当前线程
        setExclusiveOwnerThread(Thread.currentThread());
    else
        // 抢占失败，走正常的上锁逻辑
        acquire(1);
}
```
所以说，公平锁就是走正常的获取锁流程；而非公平锁，则首先抢占式先通过CAS的方式改变一下锁的`state`（将`state`通过CAS设为`1`，如过成功，则将锁的独占线程`thread`变量设为当前线程），失败的话，再走正常的获取锁流程。  

### 尝试获取锁
在公平情况或者非公平但是开门竞争失败的情况下，两者都会调用`acquire`方法。这个方法在[上面](#上锁入口)已经分析过了。会调用`tryAcquire`的方法，在`FairSync`中直接实现了`tryAcquire()`，而`UnfaireSync`的`tryAcquire()`中调用了`nonfairTryAcquire()`方法：
```java
// ReentrantLock.FairSync#tryAcquire
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        // 锁没有被占用
        if (!hasQueuedPredecessors() && compareAndSetState(0, acquires)) {
            // 阻塞队列中没有等待时间更长的结点，且
            // 锁竞争成功，则
            // 将本线程设为该锁的独占线程，并返回尝试获取锁成功
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        // 当前线程本来就是该锁的独占线程，则重入次数增加
        // 并返回尝试获取锁成功
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    // 否则说明现在锁正在被别的线程占有，或者有更优先的结点
    // 返回尝试获取锁失败
    return false;
}
// ReentrantLock.UnfairSync#nonfairTryAcquire
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        // 锁没有被占有
        if (compareAndSetState(0, acquires)) {
            // 不管FIFO，直接竞争锁成功，则
            // 将本线程设为锁的独占线程，并返回尝试获取锁成功
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        // 同上
        int nextc = c + acquires;
        if (nextc < 0) 
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    // 说明现在锁正在被别的线程占有，返回尝试获取锁失败
    return false;
}
```
可以看出来，公平与非公平主要体现在2个地方。第一个是lock的时候，非公平会猜测现在的`state`是`0`，直接去将其改为`1`，搏一搏单车变摩托。第二个就是在`tryAcquire`中，公平锁即使在发现`state == 0`，也会先判断一下`hasQueuedPredecessors`，也就是队列中是否已经排有其他的结点，如果有的话，此时如果本线程再去抢占锁，就不符合FIFO的公平原则，所以会放弃竞争；而非公平锁无所谓，捡着空就上。  
如果竞争失败了，无论公平锁还是非公平锁，都会进入`doAcquireXXX`系列的方法中，就不赘述了。  

### 尝试释放锁
`ReentrantLock.Sync`只有一个`tryRelease`的实现，无论`FairSync`还是`UnFairSync`都直接继承了该方法。  
这个方法主要做了2件事情，一个是削减重入次数，一个是当重入次数为0时将锁的独占线程由自己设为`null`。所以还是比较简单的。
```java
protected final boolean tryRelease(int releases) {
    int c = getState() - releases;
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null);
    }
    setState(c);
    return free;
}
```

## ReentrantReadWriteLock 可重入读写锁
可重入读写锁`ReentrantReadWriteLock`包含了一个`ReadLock`和一个`WriteLock`，并且共享了同一个`Sync`。  
```java
// ReentrantReadWriteLock#ReentrantReadWriteLock
public ReentrantReadWriteLock() {
    this(false);
}
public ReentrantReadWriteLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
    readerLock = new ReadLock(this);
    writerLock = new WriteLock(this);
}
// ReentrantReadWriteLock.ReadLock#ReadLock
protected ReadLock(ReentrantReadWriteLock lock) {
    sync = lock.sync;
}
// ReentrantReadWriteLock.WriteLock#WriteLock 
protected WriteLock(ReentrantReadWriteLock lock) {
    sync = lock.sync;
}
```
我们知道，读锁是共享的，写锁是独占的。当读锁上锁的时候，其他想要获取读锁的线程是允许获取读锁的；但当读锁上锁时，想要获取写锁是不可以的，需要阻塞直到所有读锁都被释放。而当写锁上锁时，其他想要获得锁的（无论是想要获得读锁还是写锁），都会被阻塞，直到这个写锁被释放，然后再竞争。所以，必须要通过这样的设计，让读锁与写锁的状态是互相可见的，才能确保读写锁的正确上锁与释放。  

|   |已经上了读锁|已经上了写锁|
|:--:|:--:|:--:|
|同线程尝试上读锁|成功|成功|
|同线程尝试上写锁|成功|成功|
|异线程尝试上读锁|成功|阻塞|
|异线程尝试上写锁|阻塞|阻塞|

在开始正式分析读写锁分别的上锁和释放锁的过程之前，先来看看`ReentrantReadWriteLock.Sync`中几个比较有意思的常量：  
```java
/*
* Read vs write count extraction constants and functions.
* Lock state is logically divided into two unsigned shorts:
* The lower one representing the exclusive (writer) lock hold count,
* and the upper the shared (reader) hold count.
*/
static final int SHARED_SHIFT   = 16;
static final int SHARED_UNIT    = (1 << SHARED_SHIFT);
static final int MAX_COUNT      = (1 << SHARED_SHIFT) - 1;
static final int EXCLUSIVE_MASK = (1 << SHARED_SHIFT) - 1;
```
根据注释，读写锁的`Sync`，将AQS的state当做了前后两个unsigned short来使用。高2个字节用于存放共享锁（读锁），低2个字节用于存放独占锁（写锁）。这样也就解释了这4个常量的含义。  

* `SHARED_SHIFT`：共享计数要偏移16位。  
* `SHARED_UNIT`：本来获取锁或者释放锁是对state进行+1或-1操作。而在读写锁中，写锁还是保持不变，读锁获取锁或者释放锁，是增加或者减少`SHARED_UNIT`。  
* `MAX_COUNT`：读锁与写锁的加锁上限，超过的的话，就意味着加锁次数溢出了。
* `EXCLUSIVE_MASK`：独占锁重入次数的掩码。可以通过`state & EXCLUSIVE_MASK`快速获取独占锁的次数。

接下来看一下读锁与写锁的上锁与释放锁的过程。

### 上写锁
写锁是支持重入的独占锁。  
```java
// ReentrantReadWriteLock.WriteLock#lock
public void lock() {
    sync.acquire(1);
}
// ReentrantReadWriteLock.Sync#tryAcquire
protected final boolean tryAcquire(int acquires) {
    Thread current = Thread.currentThread();
    int c = getState();
    // 获取写锁重入次数
    int w = exclusiveCount(c);
    if (c != 0) {
        // c!=0 且 w == 0 表示读锁次数不为0
        // 如果存在读锁，或者读写锁被其他线程占有，则此次尝试获取锁失败，返回false
        if (w == 0 || current != getExclusiveOwnerThread())
            return false;
        // 执行到这里，说明是锁重入，是线程安全的
        // 防止溢出
        if (w + exclusiveCount(acquires) > MAX_COUNT)
            throw new Error("Maximum lock count exceeded");
        // 更新重入次数，返回尝试获取锁成功
        setState(c + acquires);
        return true;
    }
    // 执行到这里，说明需要竞争锁
    if (writerShouldBlock() ||
        !compareAndSetState(c, c + acquires))
        // 竞争失败
        return false;
    // 执行到这里，说明竞争成功，将锁的独占线程设为本线程，返回尝试获取锁成功
    setExclusiveOwnerThread(current);
    return true;
}
```
在判断时，`c!=0`表示现在存在写锁或者读锁的占用情况。`w==0`表示写锁为0，那么必然此时存在读锁，不应该获取写锁，所以返回false。   
这里的`writerShouldBlock`根据公平或非公平，有两种不同的实现。如果是非公平的，那么直接进行一次CAS来增加重入次数；而公平锁只有在阻塞队列中本节点的前驱为空时，才能尝试通过CAS增加重入次数。  
```java
// ReentrantReadWriteLock.FairSync#writerShouldBlock
final boolean writerShouldBlock() {
    return hasQueuedPredecessors();
}
// ReentrantReadWriteLock.NonfairSync#writerShouldBlock
final boolean writerShouldBlock() {
    return false; 
}
```
最后更新锁的当前独占线程为本线程。  
至此，读锁的加锁过程完成。中间如果有任何一个位置返回false，则需要在进入AQS的`acquireQueued`中进行阻塞排队。  

### 释放写锁
写锁的释放很简单，在调用AQS的`release`方法后，回到`ReentrantReadWriteLock.Sync`的`tryRelease`。
```java
// ReentrantReadWriteLock.WriteLock#unlock
public void unlock() {
    sync.release(1);
}
// ReentrantReadWriteLock.Sync#tryRelease
protected final boolean tryRelease(int releases) {
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    // 获取释放后的重入次数
    int nextc = getState() - releases;
    boolean free = exclusiveCount(nextc) == 0;
    if (free)
        // 如果重入次数为0，则将锁的独占线程设为null
        setExclusiveOwnerThread(null);
    // 修改重入次数
    setState(nextc);
    return free;
}
```

### 上读锁
读锁是支持重入的共享锁。在调用AQS的`acquireShared`方法后，回到`ReentrantReadWriteLock.Sync`的`tryAcquireShared`。这里的`tryAcquireShared`只是一个为了效率进行的简易版尝试获取共享锁。如果获取失败了，才会通过`fullyTryAcquireShared`进行完整版尝试获取。  
```java
// ReentrantReadWriteLock.ReadLock#lock
public void lock() {
    sync.acquireShared(1);
}
// ReentrantReadWriteLock.Sync#tryAcquireShared
protected final int tryAcquireShared(int unused) {
    Thread current = Thread.currentThread();
    int c = getState();
    if (exclusiveCount(c) != 0 && getExclusiveOwnerThread() != current)
        // 如果写锁存在，且不是本线程占有，返回-1
        return -1;
    // 运行到这里有2种情况
    // 1. 写锁不存在
    // 2. 写锁存在，但写锁由本线程独占
    // 针对第二种情况，如果读锁获取成功，那就是可能会进行锁降级
    int r = sharedCount(c);
    if (!readerShouldBlock() && r < MAX_COUNT && compareAndSetState(c, c + SHARED_UNIT)) {
        // 不会溢出，且竞争成功
        if (r == 0) {
            // 如果是读锁归零后首个获得读锁的线程，则记录到这两个变量中
            firstReader = current;
            firstReaderHoldCount = 1;
        } else if (firstReader == current) {
            // 如果当前线程是读锁归零后首个获得读锁的线程，则更新下面这个变量
            firstReaderHoldCount++;
        } else {
            // 如果不是读锁归零厚度首个线程，将信息记录到ThreadLocalHoldCounter中
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
            rh.count++;
        }
        return 1;
    }
    // 如果需要读阻塞或者获取读锁会溢出或者CAS失败，执行该函数
    return fullTryAcquireShared(current);
}
```
前面的过程比较简单，如果当前已经是被其他线程加上写锁，则此次获取失败，返回-1。  
`readerShouldBlock()`同样有公平与非公平两个实现。所谓`readerShouldBlock`就是说需不需要先进入阻塞队列中。对于公平情况，如果阻塞队列中有前驱结点，那就需要进入阻塞队列中去排队。对于非公平情况，查看一下阻塞队列中，如果第一个有效结点（head的后继节点）是写锁，那么本线程也就去乖乖排队了。
```java
// ReentrantReadWriteLock.FairSync#readerShouldBlock
final boolean readerShouldBlock() {
    return hasQueuedPredecessors();
}
// ReentrantReadWriteLock.NonfairSync#readerShouldBlock
final boolean readerShouldBlock() {
    return apparentlyFirstQueuedIsExclusive();
}
// AbstractQueuedSynchronizer#apparentlyFirstQueuedIsExclusive
final boolean apparentlyFirstQueuedIsExclusive() {
    Node h, s;
    // head的后继s不为空且s是独占的
    return (h = head) != null &&
        (s = h.next)  != null &&
        !s.isShared()         &&
        s.thread != null;
}
```
然后如果不溢出，且CAS成功的话，根据条件更新firstReader和firstReaderHoldCount这两个变量，或者执行下面的代码：
```java
// ReentrantReadWriteLock.Sync#tryAcquireShared
HoldCounter rh = cachedHoldCounter;
if (rh == null || rh.tid != getThreadId(current))
    cachedHoldCounter = rh = readHolds.get();
else if (rh.count == 0)
    readHolds.set(rh);
rh.count++;
```
这里的readHolds是`ReentrantReadWriteLock.Sync`的一个内部类（也就是`ReentrantReadWriteLock`内部类的内部类），是用`HoldCounter`实化的`ThreadLocal`。而`HoldCounter`同样是`ReentrantReadWriteLock.Sync`的一个内部类，里面记录线程ID和一个`count`。
```java
static final class ThreadLocalHoldCounter extends ThreadLocal<HoldCounter> {
    public HoldCounter initialValue() {
        return new HoldCounter();
    }
}
static final class HoldCounter {
    int count = 0;
    // 这里使用Thread.tid这个private属性，而不是这个线程的引用
    // 是为了方式这个HoldCounter组织GC回收这个线程对象。
    final long tid = getThreadId(Thread.currentThread());
}
```
这里的`cachedHoldCounter`用于记录上一个成功获取锁的线程的`HoldCounter`。
如果`rh`也就是`cachedHoldCounter`是`null`或者不属于本线程，则通过`readHolds`这个`ThreadLocal`去获取一个（或者通过`ThreadLocalHoldCounter.initialValue`创造一个专属本线程的`HoldCounter`。然后将count自增。  
这样就在每个线程中记录下了读锁重入的次数。  
而如果上面的操作失败（判断reader需要被阻塞、获取锁后会溢出、CAS失败），则执行`Sync#fullTryAcquireShared`，在进行一次完整版的`tryAcquireShared`。  

所以说这里利用了两个缓存，一个是`firstReader`，对于并发程度不激烈的情况，重入或者申请后立刻释放发生的概率比和其他线程交替获取释放锁的概率要高。第二个是`cachedHoldCounter`，也就是同一个线程连续上锁或释放锁，同样基于并发不严重的情况。在这两个都不满足的情况下，才会利用ThreadLocal去存储各个线程自己的重入次数，从这种程度来说，也是为了集中管理这些次数记录，而不是分散在各个线程之中。  

### 释放读锁
读锁的释放就相对比较简单了。调用AQS的`releaseShared`方法，回到`ReentrantReadWriteLock.Sync`的`tryReleaseShared`。  
```java
// ReentrantReadWriteLock.ReadLock#unlock
public void unlock() {
    sync.releaseShared(1);
}
// ReentrantReadWriteLock.Sync#tryReleaseShared
protected final boolean tryReleaseShared(int unused) {
    Thread current = Thread.currentThread();
    if (firstReader == current) {
        // 当前线程与firstReader相同
        if (firstReaderHoldCount == 1)
            firstReader = null;
        else
            firstReaderHoldCount--;
    } else {
        HoldCounter rh = cachedHoldCounter;
        if (rh == null || rh.tid != getThreadId(current))
            // 如果不是上一个进入的线程，则从ThreadLocal中查询
            rh = readHolds.get();
        int count = rh.count;
        if (count <= 1) {
            // 本次释放后应该会归零，所以从ThreadLocal中删除
            readHolds.remove();
            if (count <= 0)
                throw unmatchedUnlockException();
        }
        --rh.count;
    }
    for (;;) {
        // CAS方式减少一个共享锁的数量，失败的话自旋
        int c = getState();
        int nextc = c - SHARED_UNIT;
        if (compareAndSetState(c, nextc))
            return nextc == 0;
    }
}
```
首先判断是否是第一个获取锁的线程，不是的话，再判断是否是上一个获取锁的线程，还不是的话去`ThreadLocal`中取出`HoldCounter`对象。  
然后利用`CAS`操作，将共享锁的数量减一。如果释放后已共享的锁为`0`，则返回`true`，这时AQS就可以调用`doReleaseShared`去操作阻塞队列唤醒相关线程进行锁竞争了。  

### 读写锁的降级
考虑这样一个场景。在某个线程中，首先需要修改一个可能被其他线程修改或读取的数据，但是在这个线程后期还需要使用这个数据。这时根据其他线程的情况可能发生两种情况，如下图的上面两个。  

![UsageOfDegradeReadWriteLock](UsageOfDegradeReadWriteLock.png)

为了让其他线程能够尽早访问到被修改的`data`，本线程在`modify`之后立刻释放了`writelock`。但这时，有一个线程过来修改了`data`，导致本线程在后续使用`data`时，这个值已经不对了。这就是左上角的流程。  
那为了避免上面这种情况，如果从头到尾将写锁上锁，一直到本线程`use(data)`结束再解写锁呢？这时如果有其他线程来仅仅是读`data`，却也需要被阻塞。这就是右上角的流程。

这时，我们可以利用写锁的降级，将其转换为读锁。也就是“写上锁→修改→读上锁→写释放→使用→读释放”这样的过程。  
这样，由于在写释放前，因为是同一个线程，是可重入的，所以顺利加上了读锁，从而避免其他线程修改`data`的值。而在写释放了之后，该锁现在仅仅是读锁的状态，如果有其他线程想要读，那么是可共享的；如果有其他线程想要写，那么就排队等读锁释放之后才能写，这也就是左下角的流程。而由于AQS是准FIFO的，所以如果其他线程先想获取写，再想获取读，那就要等写完成了，才能获取读，这也就是右下角的流程。

参考这样一段[代码](https://github.com/discko/learnconcurrent/blob/master/basicconcurrent/src/main/java/space/wudi/learnconcurrent/basicconcurrent/test06/Main06.java)：
```java
package space.wudi.learnconcurrent.basicconcurrent.test06;
import java.util.concurrent.locks.*;
public class Main06 {
    private static long startTime = 0;
    public static void main(String[] args) {
        startTime= System.currentTimeMillis();
        ReentrantReadWriteLock rrwl = new ReentrantReadWriteLock();
        new Thread(()->{
            rrwl.writeLock().lock();
            modify();
            rrwl.readLock().lock(); // A
            System.out.println("gained read lock and unlocking write lock" + " time elapsed "+(System.currentTimeMillis() - startTime));
            rrwl.writeLock().unlock();
            try {
                Thread.sleep(5000);
            } catch (InterruptedException ignored) {
            }
            System.out.println("in "+Thread.currentThread().getName() + " time elapsed "+(System.currentTimeMillis() - startTime));
            rrwl.readLock().unlock();   // A
        }, "ReadWriteThread").start();
        new Thread(()->{
            try {
                Thread.sleep(1000);
            } catch (InterruptedException ignored) {
            }
            rrwl.readLock().lock();
            System.out.println("in "+Thread.currentThread().getName() + " time elapsed "+(System.currentTimeMillis() - startTime));
            rrwl.readLock().unlock();
        },"ReadThread1").start();
        new Thread(()->{
            try {
                Thread.sleep(2000);
            } catch (InterruptedException ignored) {
            }
            rrwl.writeLock().lock();
            modify();
            rrwl.writeLock().unlock();
        }, "WriteThread").start();
        new Thread(()->{
            try {
                Thread.sleep(3000);
            } catch (InterruptedException ignored) {
            }
            rrwl.readLock().lock();
            System.out.println("in "+Thread.currentThread().getName() + " time elapsed "+(System.currentTimeMillis() - startTime));
            rrwl.readLock().unlock();
        },"ReadThread2").start();
    }
    private static void modify(){
        System.out.println("Modified in "+Thread.currentThread().getName() + " time elapsed "+(System.currentTimeMillis() - startTime));
    }
}
```
开启了4个线程。  
`ReadWriteThread`线程会先后执行加写锁→加读锁→释放写锁→释放读锁。在释放写锁与释放读锁之间，sleep一段时间以模仿耗时比较长的业务逻辑。  
`ReadThread`有两个，分别表现为两个不同的时机下上读锁读取数据。  
`WriteThread`是通过写锁来修改数据。
下面就是上面代码的输出： 

> Modified data to 1 in ReadWriteThread time elapsed 49  
gained read lock and unlocking write lock time elapsed 49  
read data = 1 in ReadThread1 time elapsed 1050  
read data = 1 in ReadWriteThread time elapsed 5053  
Modified data to 2 in WriteThread time elapsed 5053  
read data = 2 in ReadThread2 time elapsed 5053     

ReadThread1在writeLock释放后很顺利就获得了读锁。而ReadThread2因为WriteThread先来，所以被其阻塞，直到WriteThread在ReadWriteThread释放读锁从而获得写锁并释放写锁之后，才获得了读锁。

总结而言，锁降级，就是为了在本线程又要写又要读的情况下，提升其他线程的性能。

## CountDownLatch
ReentrantLock是独占的，接下来来看一个共享的锁，`CountDownLatch`。
先看一下`CountDownLatch`的初始化：
```java
// CountDownLatch#CountDownLatch
public CountDownLatch(int count) {
    if (count < 0) throw new IllegalArgumentException("count < 0");
    this.sync = new Sync(count);
}
// CountDownLatch.Sync#Sync
Sync(int count) {
    setState(count);
}
// AbstractQueuedSynchronizer#setState
protected final void setState(int newState) {
    state = newState;
}
```
可以看到，CDL直接将输入的`count`作为形参，构造了`sync`对象。而Sync的构造函数中，直接调用AQS中的`setState`将AQS的state设为了`count`。

### CountDownLatch的倒数计数
我们先看一下CountDownLatch是如何倒数计数的。调用`countdownLatch.countDown()`之后，直接调用`sync`的`releaseShared(1)`，也就是释放一把共享锁。
```java
// CountDownLatch#countDown
public void countDown() {
    sync.releaseShared(1);
}
// CountDownLatch.Sync#tryReleaseShared
protected boolean tryReleaseShared(int releases) {
    for (;;) {
        int c = getState();
        if (c == 0)
            return false;
        int nextc = c-1;
        if (compareAndSetState(c, nextc))
            // 只有当剩余的共享锁数量是0时，才认为释放成功
            return nextc == 0;
    }
}
```
那么什么情况下认为尝试释放共享锁成功呢？从`tryReleaseShared`可以看出来，它会自旋尝试将state的数量减1。且只有当剩余的共享锁数量为0时，才认为释放成功。接下来去调用`doReleaseShared()`去唤醒阻塞的线程。  
从前面的分析我们知道`doReleaseShared()`是几乎不会阻塞线程的，所以整个`countdown()`方法也不会阻塞倒数线程。

### CountDownLatch的阻塞等待
CountDownLatch的上锁指令是`await()`，里面调用`sync.acquireSharedInterruptibly(1)`。
```java
// CountDownLatch#await()
public void await() throws InterruptedException {
    sync.acquireSharedInterruptibly(1);
}
// AbstractQueuedSynchronizer#acquireSharedInterruptibly
public final void acquireSharedInterruptibly(int arg) throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)
        doAcquireSharedInterruptibly(arg);
}
```
所以会先落到由·实现的`tryAcquireShared`方法。
```java
// CountDownLatch.Sync#tryAcquireShared
protected int tryAcquireShared(int acquires) {
    return (getState() == 0) ? 1 : -1;
}
```
这个方法异常简单。而且逻辑上也不难理解，什么时候state的数量被减到0了，就表示尝试获取锁成功（甚至都不需要记录谁获取了锁，获取了多少锁），然后再调用`doAcquireSharedInterruptibly`去更新阻塞队列，就ok了。

## CyclicBarrier 
`CyclicBarrier`与`CountDownLatch`有一定的相似性，都有计数和阻塞等待执行的作用。做个不恰当的比喻。
`CountDownLatch`可以认为有2个角色，一个是金库管理员组，一个是要去金库取东西的人，而`CountDownLatch`就是这个金库的门。当要去金库取东西的人到达金库门口后，被阻塞（`cdl.await()`）挡在金库门前。这时，金库管理员一个个先后解开自己管理的一把锁（`cdl.countdown()`）然后就自己做自己的事情去了（倒数时不会阻塞线程）。当金库门达到所需的解锁数量时，金库大门打开，要去金库去东西的人结束阻塞，开始执行后续的动作。而且这个门是不可重复使用的，再也不会响应`await`指令了。  
`CyclicBarrier`更像高铁站安检前控制人流的那个限流员。人流走到这边就被阻塞了（`cb.await()`），直到人数达到`CyclicBarrier`设置的数量，然后放行，并清零计数，进行下一轮阻拦人流和放行。  

`CyclicBarrier`可以接受一个`int`型的参数，也可以再额外接受一个回调函数作为第二个参数。这个`int`参数就是被阻塞的数量。  
```java
public CyclicBarrier(int parties) {
    this(parties, null);
}
public CyclicBarrier(int parties, Runnable barrierAction) {
    if (parties <= 0) throw new IllegalArgumentException();
    this.parties = parties;
    this.count = parties;
    this.barrierCommand = barrierAction;
}
```

### CyclicBarrier中的关键属性
```java
// 一个可重入锁，在进入Condition时会被释放
private final ReentrantLock lock = new ReentrantLock();
// trip是绊住的意思。利用Condition实现阻塞和唤醒所有的功能
private final Condition trip = lock.newCondition();
// 记录需要等待的数量
private final int parties;
// 解除阻塞时的回调
private final Runnable barrierCommand;
// 用于分代，解除阻塞后换代可以继续阻塞
private Generation generation = new Generation();
// 记录当前await的数量
private int count;
```
这里通过`parties`记录需要阻塞的总量，用`count`记录次轮已经到达`await`的数量。  
利用`lock`去生成`trip`这个`Condition`，因为Condition是支持signalAll来唤醒所有被阻塞（等待）的线程的。  
利用`generation`来区分不同的代，每一批一起等待的呗认为是一代，当一起阻塞的呗唤醒后，会切换成下一代。  
```java
private static class Generation {
    boolean broken = false;
}
private void nextGeneration() {
    // 唤醒所有
    trip.signalAll();
    // 恢复等待计数
    count = parties;
    // 切换代别
    generation = new Generation();
}
```

### CyclicBarrier的实现过程
当调用`cb.await()`时，其值执行的是`CyclicBarrier.dowait()`方法。
```java
// java.util.concurrent.CyclicBarrier#await
public int await() throws InterruptedException, BrokenBarrierException {
    try {
        return dowait(false, 0L);   // false 为不需要定时，0L在定时时表示最长await的时长
    } catch (TimeoutException toe) {
        throw new Error(toe); // 非定时情况下，不可能执行到这里
    }
}
public int await(long timeout, TimeUnit unit)  throws InterruptedException, BrokenBarrierException, TimeoutException {
    return dowait(true, unit.toNanos(timeout));
}
// 
private int dowait(boolean timed, long nanos) throws InterruptedException, BrokenBarrierException, TimeoutException {
    final ReentrantLock lock = this.lock;
    lock.lock();    
    // 同一时刻只有一个线程可以执行下面的
    // 比如初始化为5，目前有4个阻塞。这时来了2个线程await
    // 那么只能有一个线程执行下面的程序，并被唤醒
    // 另一个线程将作为下一批中的线程，先阻塞着
    try {
        // 记录当前代别
        final Generation g = generation;
        if (g.broken)
            throw new BrokenBarrierException();
        if (Thread.interrupted()) {
            // 响应中断
            breakBarrier();
            throw new InterruptedException();
        }
        int index = --count;    // count用于记录此代await的数量
        if (index == 0) {  
            // 此代等待数量已满，可以执行回调
            boolean ranAction = false;
            try {
                final Runnable command = barrierCommand;
                if (command != null)
                    command.run();
                ranAction = true;
                // 切换代别，并唤醒所有
                nextGeneration();
                return 0;
            } finally {
                if (!ranAction)
                    breakBarrier();
            }
        }
        for (;;) {  // 循环直到达到终止条件
            try {
                if (!timed)
                    // 针对没有定时的情况
                    trip.await();
                else if (nanos > 0L)
                    // 针对定时的情况，nanos表示此次await后还剩余的时间
                    nanos = trip.awaitNanos(nanos);
            } catch (InterruptedException ie) {
                if (g == generation && ! g.broken) {
                    // 苏醒了，但是发现没有换代，说明是本线程被打断了
                    // 标记barrier为broken，然后唤醒所有同cb的线程
                    breakBarrier();
                    throw ie;
                } else {
                    Thread.currentThread().interrupt();
                }
            }

            if (g.broken)
                throw new BrokenBarrierException();

            if (g != generation)
                // 当trip被唤醒或者定时时间到
                // 如果代别发生了变化，则返回
                return index;

            if (timed && nanos <= 0L) {
                // 定时了，且定时时间到，
                // 则抛出TimeoutException异常
                breakBarrier();
                throw new TimeoutException();
            }
        }
    } finally {
        lock.unlock();
    }
}
```
由于一个线程可以使用多个CyclicBarrier，而任何一个CycliBarrier中的condition.await()都可能被诸如Thread.interrupt()中断而唤醒。如果唤醒后，发现还没有换代的话，那么就会通过breakBarrier方法，唤醒所有的等待线程。  
可以看一下breakBarrier的实现，可以发现，只要有一个线程执行了breakBarrier，那么所有等待线程都会被唤醒：
```java
private void breakBarrier() {
    generation.broken = true;
    count = parties;
    trip.signalAll();
}
```

### CyclicBarrier流程总结

当预定数量的线程执行到await之后，这些线程将直接被一起唤醒，停止阻塞。  
当某个线程被`Thread.interrupt()`打断后，该线程被唤醒，并抛出`InterruptException`，其他阻塞的线程也会被唤醒，并抛出`BrokenBarrierException`。
当某个线程通过`await(time, unit)`进行阻塞，时间结束仍然没有凑满预定数量的线程，则这个线程被唤醒，并抛出`TimeoutException`；其他阻塞的线程也会被唤醒，并抛出`BrokenBarrierException`。  

## Semaphore 信号量
最后来看`Semaphore`信号量。这个就简单很多了。  
`Semaphore`的官方解释是这样的：

> A counting semaphore.  Conceptually, a semaphore maintains a set of permits.  Each {@link #acquire} blocks if necessary until a permit is available, and then takes it.  Each {@link #release} adds a permit, potentially releasing a blocking acquirer. However, no actual permit objects are used; the {@code Semaphore} just keeps a count of the number available and acts accordingly.  

大致翻译一下：

> 这是一个计数信号量。从概念上来说，semaphore维护着一组许可证。每一次acquire都可能阻塞线程直到获得一个许可证；每一次release都会添加一个许可证，并且顺便在需要的情况下释放一个被阻塞的线程。然而，在semaphore中没有真正的许可证对象，semaphore仅仅计数可用许可证的数量。  

所以对于semaphore而言，最主要的就是`acquire`和`release`两个方法。对于`acquireInterruptibly`在流程上是基本相似的，就不去介绍了。  

`acquire`和`release`都有无参和接受一个`int`作为参数的两个版本。这个int参数表示需要获取或者释放（后面会说到，其实`release`翻译为“添加”其实跟合理）的许可证的数量。  

### 获取许可证
`acquire`方法调用`sync.acquireSharedInterruptibly`，进入AQS后，先调用`tryAcquireShared`，如果失败的话则调用`doAcquireShared`将其加入阻塞队列。重新回到`Semaphore`的`Sync`中，`Semaphore.Sync`有两个老生常谈的实现，分别是`FairSync`和`UnfairSync`，所以也就对应着2个`tryAcquireShared`的实现。
```java
// Semaphore.FairSync#tryAcquireShared
protected int tryAcquireShared(int acquires) {
    for (;;) {
        if (hasQueuedPredecessors())
            // 如果阻塞队列中已经存在正在等待的，则返回失败
            // 接下来去调用doAcquireShared方法
            return -1;
        int available = getState();
        int remaining = available - acquires;
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            // 如果本次获取后剩余的许可证小于0，则直接返回
            // 或者剩余许可证数量不少于0，则CAS直到成功
            return remaining;
    }
}
// Semaphore.NonfairSync#tryAcquireShared
protected int tryAcquireShared(int acquires) {
    return nonfairTryAcquireShared(acquires);
}
// Semaphore.Sync#nonfairTryAcquireShared
final int nonfairTryAcquireShared(int acquires) {
    for (;;) {
        // 不需要去判断队列中是否存在，先抢一波
        int available = getState();
        int remaining = available - acquires;
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
```
逻辑上和`ReentrantLock`的公平锁与非公平锁非常相似，甚至比`ReentrantLock`还要简单，因为这个是共享的，不需要去判断独占性。  

### 增加许可证

释放许可证也很简单，`relase`方法调用`sync.releaseShared`，进入AQS后，先调用`tryReleaseShared`，如果成功则继续调用`doReleaseShared`去处理阻塞队列。`tryReleaseShared`的实现也很简单：
```java
// Semaphore.Sync#tryReleaseShared
protected final boolean tryReleaseShared(int releases) {
    for (;;) {
        int current = getState();
        int next = current + releases;
        if (next < current) 
            // 如果释放许可证之后，许可证反而变小了
            // 要么是超过Integer.MAX_VALUE后溢出了
            // 要么releases是负的
            throw new Error("Maximum permit count exceeded");
        if (compareAndSetState(current, next)) // 失败就自旋
            return true;
    }
}
```
从这里来看，`tryReleaseShared`仅仅只做`next<current`这一个判断，用来保证没有溢出（或者释放了负数个许可证），所以释放后的许可证数量是可以超过初始化时许可证的数量的。所以“释放”这个词就不太合适了，使用“增加”更合适一些。  

### 一些其他方法
除了`acquire`和`release`之外，还有一个比较有意思的方法：`drainPermits`：
```java
final int drainPermits() {
    for (;;) {
        int current = getState();
        if (current == 0 || compareAndSetState(current, 0))
            return current;
    }
}
```
从逻辑上来看，将剩余的许可证数量返回，并将剩余许可证数量归零。可能在某些情况下会使用吧。