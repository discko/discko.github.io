---
title: LC-0002-两数相加
date: 2020-07-31 13:01:20
tags: [LeetCode, LinkedList]
categories: LeetCode
mathjax: true
---

# 题干

给出两个 非空 的链表用来表示两个非负的整数。其中，它们各自的位数是按照 逆序 的方式存储的，并且它们的每个节点只能存储 一位 数字。  
<!--more--> 
如果，我们将这两个数相加起来，则会返回一个新的链表来表示它们的和。  
您可以假设除了数字 0 之外，这两个数都不会以 0 开头。  
示例：

> 输入：(2 -> 4 -> 3) + (5 -> 6 -> 4)
> 输出：7 -> 0 -> 8
> 原因：342 + 465 = 807  
  
# 分析  
此题说明了数字是按照逆序排列的，所以两个链表中对应位置的数字，在加法中是同一位的，不需要再进行对齐。因此，可直接用模拟法，进行处理。  
在加法过程中，我们通常以「加数1+加数2+进位=和」这种方式来计算。其中「加数1」和「加数2」都已在链表中对齐提供了，进位的值仅可能取$carry\in{0,1}$两个，和（sum）的范围仅可能是在$sum\in{x|x\le19}$。当前位的值应当为sum的个位，进位值应当为sum的十位。  
需要注意的是，有这样一些坑在里面： 

|         | case 1 | case 2 | case 3 |
|:--------|:-------|:-------|:-------|
| addend1 | 3      | 3->4   | 1      |
| addend2 | 1->2   | 7      | 9->9   |
| sum     | 4->2   | 0->5   | 0->0->1|

也就是两个加数的长度可能不一样，且存在加数结束了但仍有进位的问题。为此，不妨在任意时刻，只要加数1链表没有结束、加数2链表没有结束或者进位不为0，这3个条件任意成立1个，就继续计算下一位。当然对于该位已经为0的链表，认为该链表的该位为0即可。 
最终代码如下：

# 解题
```java
class Solution {
    // class ListNode{
    //     ListNode next;
    //     int val;
    //     ListNode(int x){val=x;}
    // }
    public ListNode addTwoNumbers(ListNode l1, ListNode l2) {
        int carry=0;
        //use a dummy node as the head. 
        ListNode head=new ListNode(Integer.MIN_VALUE);
        //p is the iterator
        ListNode p=head;
        while(l1!=null || l2!=null || carry!=0){
            int val=(l1==null?0:l1.val)+(l2==null?0:l2.val)+carry;
            carry=val/10;
            p.next=new ListNode(val%10);
            p=p.next;
            l1=l1==null?null:l1.next;
            l2=l2==null?null:l2.next;
        }
        return head.next;
    }
}
```
# 复杂度分析
时间上，由于最终两个链表从头到尾遍历了一次，因此时间复杂度仅与较长的那个链表相关。
空间上，最终结果存储在一个新的链表中，结果的长度与较长的那个链表相同或多1个节点。
故：
时间复杂度：$O(max(m,n))$

空间复杂度：$O(max(m,n))$   