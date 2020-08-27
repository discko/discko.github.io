---
title: LC-0007-整数反转
tags:
  - LeetCode
  - Math
categories: LeetCode
mathjax: true
date: 2020-08-21 15:54:50
---

# 题干
给出一个 32 位的有符号整数，你需要将这个整数中每位上的数字进行反转。
<!--more-->
示例1：   

> 输入: 123   
> 输出: 321   

示例 2:

> 输入: -123  
> 输出: -321

示例 3:

>  输入: 120  
>  输出: 21

注意:

假设我们的环境只能存储得下 32 位的有符号整数，则其数值范围为 [−231,  231 − 1]。请根据这个假设，如果反转后整数溢出那么就返回 0。


# 分析
常规思路，利用取余运算与取整运算，将整数各位分离，并重新组合。   
唯一需要注意的，也正如题干中提示的，需要小心翻转后的整数溢出int类型的大小。比如`Integer.MAX_VALUE=2147483647`翻转后的`7463846412`，显然已经溢出了`Integer.MAX_VALUE`。   
那么接下来就是如何判断一个数在反转后会不会溢出。   
对于正数，如果一个数×10后超过了`Integer.MAX_VALUE=2147483647`，那么它有可能会溢出；但是如果一个数超过了`Integer.MAX_VALUE/10`，那它一定会溢出。所以使用后一个作为是否会溢出的判据将会更有效。   
对于负数同理，如果一个数后小于`Integer.MIN_VALUE/10`，那它也一定会溢出。

# 解题
```java
class Solution {
    public int reverse(int x) {
        int result=0;
        int maxValue=0;

        if(x<0){
            result=(x%10);
            x=x/10;
            maxValue=Integer.MIN_VALUE;
        }else{
            maxValue=Integer.MAX_VALUE;
        }
        
        while(x!=0){
            if((result>0&&result>maxValue/10)||(result<0&&result<maxValue/10)){
                return 0;
            }
            result=result*10+x%10;
            x/=10;
        }
        return result;
    }
}

```

# 复杂度
时间上仅与输入数字的位数相关，故时间复杂度为：$O(\lg(n))+k_(10)$。   
空间上只有常数个变量存储，且无递归，所以空间复杂度为：$O(1)$