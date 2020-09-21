---
title: LC-0238-除自身以外数组的乘积
tags:
  - LeetCode
  - Math
  - Array
categories: LeetCode
mathjax: true
date: 2020-09-17 13:07:57
---


# 题干
给你一个长度为 `n` 的整数数组 `nums`，其中 `n > 1`，返回输出数组 `output`，其中 `output[i]` 等于 `nums` 中除 `nums[i]` 之外其余各元素的乘积。
<!--more-->

示例:

> 输入: [1,2,3,4]  
> 输出: [24,12,8,6]  
> 说明：24=2*3*4，12*1*3*4，8=1*2*4，6=1*2*3

提示：题目数据保证数组之中任意元素的全部前缀元素和后缀（甚至是整个数组）的乘积都在 32 位整数范围内。

说明: 请不要使用除法，且在 O(n) 时间复杂度内完成此题。

进阶：
你可以在常数空间复杂度内完成这个题目吗？（ 出于对空间复杂度分析的目的，输出数组不被视为额外空间。）

# 题外话
光看标题，有一种朦胧的感觉。总感觉自己语文没有学好。倒不是说英语比汉语更加精确，而是感觉这题的标题没有翻译好。英语原文是 Product of Array Except Self，我觉得翻译成“数组中除自身以外(的数)的乘积”更明确一点，“的数”两个字无所谓，但“数组”两个字放在前面会更明确一点。而且以“除”字开头，一瞬间，我以为需要对某个乘积做除法。=，=

# 解法一
## 分析
这一题还是蛮有意思的。  
正常的想法，比如上面的示例，做第i个数的时候，就遍历整个数组自乘，并跳过第i个。这样两轮遍历就能得到最终结果。但这是一个$O(n^2)$的算法，不符合题意。  

由于前面做过一道分糖果的题目（[LC-0135-分发糖果](/2020/09/16/LC-0135-Candy/)），其中分配的糖果依赖于两侧的值，与此题有一定的相似性。所以也参考这一题的做法，我们将数组从左往右累乘，再从右往左累乘，将两个累乘的结果再乘起来，就是左边和右边的元素的乘积了。这样就将$O(n^2)$转化为了$O(3n)$。  

在单向乘的时候，我们将乘积结果的初始值设为1。就像下面这样：

|arr| 1 | 2 | 3 | 4 |
|:-:|:-:|:-:|:-:|:-:|
|left|1 | 1 | 2 | 6 |
方向$\rightarrow$
   

|arr| 1 | 2 | 3 | 4 |
|:-:|:-:|:-:|:-:|:-:|
|right|24| 12| 4 | 1 |
方向$\leftarrow$

|arr| 1 | 2 | 3 | 4 |
|:-:|:-:|:-:|:-:|:-:|
|left|1 | 1 | 2 | 6 |
|right|24| 12| 4 | 1 |
|ans| 24 | 12 | 8 | 6 |
方向随意


解释一下。   

令left[0]=1，然后`left[1]=arr[0]*left[0]`，`left[2]=arr[1]*left[1]`，`left[3]=arr[2]*left[2]`。   

令right[3]=1，然后`right[2]=arr[3]*right[3]`，`right[1]=arr[2]*right[2]`，`right[0]=arr[1]*right[1]`  

最后，`ans[0]=left[0]*right[0]`，`ans[1]=left[1]*right[1]`，`ans[2]=left[2]*right[2]`，`ans[3]=left[3]*right[3]`   

## 解题
```java
class Solution {
    public int[] productExceptSelf(int[] nums) {
        //left to right
        int[] left=new int[nums.length];
        left[0]=1;
        for(int i=1;i<nums.length;i++){
            left[i]=left[i-1]*nums[i-1];
        }
        //right to left
        int[] right=new int[nums.length];
        right[nums.length-1]=1;
        for(int i=nums.length-2;i>=0;i--){
            right[i]=right[i+1]*nums[i+1];
        }
        //left*right
        int[] ans=new int[nums.length];
        for(int i=0;i<nums.length;i++){
            ans[i]=left[i]*right[i];
        }
        return ans;
    }
}
```
## 复杂度
时间上，两次全数组遍历求出left和right数组，再加一次全数组遍历求出ans，总共三次全数组遍历，所以时间复杂度$O(3n)=O(n)$。   

空间上，就算不计输出的ans的空间大小，我们仍然创建了两个数组left和right，其尺寸均为$n$。因此空间复杂度为$O(2n)=O(n)$。  

所以我们来尝试缩减空间复杂度

# 解法二
## 分析
与[LC-0135-分发糖果](/2020/09/16/LC-0135-Candy/)相同，在从右向左遍历的时候，其实我们已经不必要记录右侧已经计算过的所有值，只需要记录右侧的累乘结果即可。同时，left数组中的值，其实也仅有在计算ans时需要遍历一次，因此只需要将left数组与ans数组合并即可。这样，两个额外创建的数组，就都变得不再必要。
## 解题
```java
class Solution {
    public int[] productExceptSelf(int[] nums) {
        int[] ans=new int[nums.length];
        
        //left to right 
        ans[0]=1;
        for(int i=1;i<nums.length;i++){
            ans[i]=ans[i-1]*nums[i-1];
        }

        //right to left
        int right=1;
        for(int i=nums.length-2;i>=0;i--){
            //multiply to itself
            right*=nums[i+1];
            //calc left*right
            ans[i]*=right;
        }

        return ans;

    }
}
```
## 复杂度
时间上，1次全数组遍历求出left，再加一次全数组遍历求出ans，总共2次全数组遍历，所以时间复杂度$O(2n)=O(n)$。 

空间上，没有创建额外的数组。因此空间复杂度为$O(1)$。