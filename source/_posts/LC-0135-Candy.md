---
title: LC-0135-分发糖果
tags:
  - LeetCode
  - Greedy
categories:
  - LeetCode
mathjax: true
date: 2020-09-16 16:39:31
---


# 题干
老师想给孩子们分发糖果，有 N 个孩子站成了一条直线，老师会根据每个孩子的表现，预先给他们评分。

你需要按照以下要求，帮助老师给这些孩子分发糖果：

每个孩子至少分配到 1 个糖果。
相邻的孩子中，评分高的孩子必须获得更多的糖果。
那么这样下来，老师至少需要准备多少颗糖果呢？
<!--more-->

示例1：  
> 输入: [1,0,2]   
> 输出: 5   
> 解释: 你可以分别给这三个孩子分发 2、1、2 颗糖果。   

示例2：   
> 输入: [1,2,2]   
> 输出: 4   
> 解释: 你可以分别给这三个孩子分发 1、2、1 颗糖果。   
>     第三个孩子只得到 1 颗糖果，这已满足上述两个条件。   

# 分析
我们可以将这个问题分解一下。对于某一个孩子，需要满足的应该有两点：   
* 观察他的左边，如果他左边的小孩的评分比他低，那么他获得的糖果应该比左边的小孩的糖果多1个。   
* 观察他的右边，如果他右边的小孩的评分比他低，那么他获得的糖果应该比右边的小孩的糖果多1个。   

总结而言，这个小孩应该得到的糖果数量应该是根据左侧看获得的糖果数量和根据右侧获得的糖果数量中较大的。因为只有这样，才能够同事满足左边和右边两个条件。

也即：
```java
  if(rating[i-1] < rating[i]){
      candyLeft[i] = candyLeft[i-1] + 1;
  }else{
      candyLeft[i] = 1;
  }

  if(rating[i] > rating[i+1]){
      candyRight[i] = candyRight[i+1] + 1;
  }else{
      candyRight[i] = 1;
  }

  candy[i] = max(candyLeft[i], candyRight[i]);
```
那么这样一来，只要从左向右遍历一遍得到与左侧相关的糖果数，然后再从右向左遍历一遍，得到与右侧相关的糖果数。最终取两个糖果数较大的那一个作为最终糖果数即可。

# 解题
这里我们让每一个小孩的初始糖果数为0，为了满足题目要求“每一个小孩至少有一个糖果”，最后再给每一个小孩多发一个，这样可以节省一次初始化时的遍历。
```java
class Solution {
    public int candy(int[] ratings) {
        if(ratings.length<2){
            return ratings.length;
        }
        int[] candiesLeft=new int[ratings.length];
        int[] candiesRight=new int[ratings.length];

        for(int i=1;i<ratings.length;i++){
            if(ratings[i-1]<ratings[i]){
                candiesLeft[i]=candiesLeft[i-1]+1;
            }else{
                candiesLeft[i]=0;
            }
        }
        
        for(int i=ratings.length-2;i>=0;i--){
            if(ratings[i]>ratings[i+1]){
                candiesRight[i]=candiesRight[i+1]+1;
            }else{
                candiesRight[i]=0;
            }
        }

        int sum=ratings.length;
        for(int i=0;i<ratings.length;i++){
            sum+=Integer.max(candiesLeft[i], candiesRight[i]);
        }
        return sum;
    }
}
```
当然，时间和内存上仍然还有优化的空间。比如我们先从左向右，记录下左相关的糖果后，再从右向左遍历时，并不需要记录所有右侧的糖果了，在计算得到当前应该获取的右相关的糖果时，这个孩子实际应当获取的糖果数量就已经确定了。因此candiesRight数组是不必要的。最后那一个for循环也是不必要的。最终代码如下：

```java
class Solution {
    public int candy(int[] ratings) {
        if(ratings.length<2){
            return ratings.length;
        }
        int[] candies=new int[ratings.length];
        //from left to right.
        //if(ratings[left]<ratings[right])
        //  candies[left]<candies[right]
        for(int i=1;i<ratings.length;i++){
            if(ratings[i-1]<ratings[i]){
                candies[i]=candies[i-1]+1;
            }else{
                candies[i]=0;
            }
        }
        int sum=candies[ratings.length-1];
        //from right to left.
        //if(ratings[left]>ratings[right])
        //  candies[left]>candies[right]
        for(int i=ratings.length-2;i>=0;i--){
            //let max(left2RightCandy, right2LeftCandy)
            //be the kid's candy
            if(ratings[i]>ratings[i+1]){
                candies[i]=Integer.max(candies[i], candies[i+1]+1);
            }else{
                candies[i]=candies[i];
            }
            sum+=candies[i];
        }
        return sum+ratings.length;
    }
}
```
因为最右侧的孩子，在开始从右向左遍历时，获得的值一定是0，所以最右侧的孩子实际的糖果数一定就是从左向右遍历时得到的糖果数量，（因为`max(candies[ratings.length-1], 0) = candies[ratings.length-1]`）。所以用该值为`sum`变量初始化。  

# 复杂度
时间上，进行了两次线性遍历，所以时间复杂度是$O(2n)=O(n)$   

空间上，利用了一个额外的一维数组，长度与小孩数量一致，所以空间复杂度是$O(n)$  
