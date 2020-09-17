---
title: LC-0232-用栈实现队列
tags:
  - LeetCode
  - Stack
  - Queue
categories:
  - LeetCode
mathjax: true
date: 2020-09-16 17:41:28
---


# 题干
使用栈实现队列的下列操作：
<!--more-->
* push(x) -- 将一个元素放入队列的尾部。  
* pop() -- 从队列首部移除元素。  
* peek() -- 返回队列首部的元素。  
* empty() -- 返回队列是否为空。  
 
示例:   
> MyQueue queue = new MyQueue();  
> queue.push(1);  
> queue.push(2);    
> queue.peek();  // 返回 1   
> queue.pop();   // 返回 1  
> queue.empty(); // 返回 false  

# 分析
栈Stack是一个FILO的数据存储工具，而队列Queue是一个FIFO的数据存储工具。如果要使用栈来模拟队列，当我们需要取“队列”中的首个元素时，我们需要将栈里的所有元素都倒出来，这样才能取到第一个元素，这样就必然需要第二个栈用来存储倒出来的这些元素（并利用这个栈记录他们的顺序）。那这时候我们有两种方案。

## 方案一
使用一个临时的栈，在倒出元素时，将这些元素装起来。当取到最开始的那个元素（First In）后，再将这个临时的栈中的元素还原回去。
以push和pop为例，push时直接将元素放到Stack栈中。当需要pop时，创建一个临时栈StackTmp，将元素从Stack中弹出并压入StackTmp中，直到获得FirstIn的元素。然后再讲StackTmp栈中的元素弹出，并压入Stack栈中，还原顺序。如下图所示。   
![方案一：使用临时栈](LC-232-ImplementQueueusingStacks/UsingTempStack.png?raw=true)    
这种方法简单明了，编码也比较轻松。但是我们设想这样一种情况，如果连续pop或者peek的话，就会不断从Stack中将元素倒入StackTmp中再倒回来。而如果有先见之明，能够预测到下一次仍然需要pop或者peek的话，直接从StackTmp中获取Last In的元素就可以了。由此，我们进入方案二。

## 方案二
我们使用两个栈，Stack1和Stack2，Stack1用于顺序存放（相对于真实队列而言）元素，Stack2用于倒序存放元素。我们再定义一个变量StackCur，用于指代当前存放元素的栈（StackCur只是一个引用，用于标记Stack1或Stack2），以及一个标记order用来表示当前的次序是顺序的（true）或倒序的（false）。   
这样的话，当需要push时，如果现在是顺序的（order==true），则可以直接push到StackCur中，否则需要先倒一下，再push。而需要peek或者pop时，如果现在是倒序的（order==false），则可以直接pop或者peek，否则需要将倒序的正过来，也即再倒一下。
如下图所示。
![方案二：使用两个栈](LC-232-ImplementQueueusingStacks/UsingTwoStack.png?raw=true)    
途中使用StackCur和Stack来标记两个栈，这样，所有的push、pop都可以直接通过StackCur来进行。

## 方案三
那还能不能再快一点呢。其实是可以的。在方案二中，我们发现，当入栈时，如果当前序列是倒序的，则需要将元素再倒回顺序的。但是如果我们先pop再push再pop，其实需要出栈的，还只是第一次pop时的栈顶元素。这一次倒回，并没有什么意义。而相反的，如果我们先pop，在push时，不倒回，而是直接将元素push到Stack1中，其实并没有什么影响。   
这样，我们将两个栈再升个级，Stack1更名为StackPush，专门负责接收push；Stack2更名为StackPop，专门负责进行pop和peek。当需要pop或者peek但StackPop为空时，将StackPush中的元素弹出并压入StackPop中，这样，一个更省时间的数据结构就造好了。我们看下面的这样一个例子：
```
push(1) //=> null
push(2) //=> null
push(3) //=> null
pop()   //=> 1
push(4) //=> null
pop()   //=> 2
pop()   //=> 3
pop()   //=> 4
```
其结果与真实的队列的结果是一致的。
如下图：
![方案三：使用两个专用栈](LC-232-ImplementQueueusingStacks/UsingTwoStack2.png?raw=true)  

# 解题
我们对方案二进行编码：
```java
class MyQueue {
    Deque<Integer> stackCur;
    Deque<Integer> stack;
    boolean order=true;

    /** Initialize your data structure here. */
    public MyQueue() {
        stackCur=new ArrayDeque<Integer>();
        stack=new ArrayDeque<Integer>();
    }
    
    /** Push element x to the back of queue. */
    public void push(int x) {
        if(!order){
            reverse();
        }
        stackCur.push(x);
    }
    
    /** Removes the element from in front of queue and returns that element. */
    public int pop() {
        if(order){
            reverse();
        }
        return stackCur.pop();
    }
    
    /** Get the front element. */
    public int peek() {
        if(order){
            reverse();
        }
        return stackCur.peek();
    }

    private void reverse(){
        while(!stackCur.isEmpty()){
            stack.push(stackCur.pop());
        }
        Deque<Integer> tmp=stack;
        stack=stackCur;
        stackCur=tmp;
        order=!order;
    }
    
    /** Returns whether the queue is empty. */
    public boolean empty() {
        return stackCur.isEmpty();
    }
}
```
而对于方案三，我们这样编码：
```java
class MyQueue {

    Deque<Integer> stackPush;
    Deque<Integer> stackPop;

    /** Initialize your data structure here. */
    public MyQueue() {
        stackPush=new ArrayDeque<Integer>();
        stackPop=new ArrayDeque<Integer>();
    }
    
    /** Push element x to the back of queue. */
    public void push(int x) {
        stackPush.push(x);
    }
    
    /** Removes the element from in front of queue and returns that element. */
    public int pop() {
        peek();
        return stackPop.pop();
    }
    
    /** Get the front element. */
    public int peek() {
        if(stackPop.isEmpty()){
            while(!stackPush.isEmpty()){
                stackPop.push(stackPush.pop());
            }
        }
        return stackPop.peek();
    }
    
    /** Returns whether the queue is empty. */
    public boolean empty() {
        return stackPush.isEmpty()&&stackPop.isEmpty();
    }
}
```

# 复杂度
我们来对每一个方案进行复杂度分析。下面复杂度中的$n$是当前栈中的元素数量。  
* 方案一：    
push：每一次push直接放在栈顶，所以时间复杂度是$O(1)$的算法。   
pop和peek：每一次pop或peek，都需要将所有元素出栈再入栈一次，所以时间复杂度是$O(2n)=O(n)$的。   
empty：$O(1)$的。   
* 方案二：   
push：如果当前是顺序的（`order==true`），其形式与方案一相同，为$O(1)$；如果是倒序的（`order==false`），则需要全部换栈一次，所以时间复杂度是$O(n)$的。   
pop和peek：如果当前是顺序的（`order==true`），需要将元素换栈一次，是$O(n)$；如果是倒序的（`order==false`），则可以直接pop或者peek，是$O(1)$的。由于当前是顺序还是倒序完全取决于push和pop的组合顺序，无法提前预测，所以可以认为，最好的情况下，平均复杂度为$O(1)$（当所有元素都先push入队，然后再pop出队，pop时n个元素仅需换栈1次，平摊到每一个元素上，时间复杂度是$O(1)$，所以是平均复杂度）；最坏的情况下是$O(n)$（当push和pop交替进行的时候，每一个指令都需要换栈）。   
empty：$O(1)$的。   
* 方案三：   
push：由于push总是向StackPush中直接压栈，因此复杂度为$O(1)$。   
pop和peek：我们观察出入站的方式，可以发现所有元素如果要pop或者peek，需且仅需换栈一次。对于所有数据而言，平摊到每一个元素身上的时间复杂度就是$O(1)$的，且不存在最坏或最好的情况。   
empty：$O(1)$的。   

