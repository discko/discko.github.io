---
title: LC-0300-最长上升子序列
tags:
  - LeetCode
  - DynamicProgramming
  - Greedy
  - BinarySearch
categories: LeetCode
mathjax: true
date: 2020-09-18 16:35:24
---

# 题干
给定一个无序的整数数组，找到其中最长上升子序列的长度。
<!--more-->
示例:    

> 输入: [10,9,2,5,3,7,101,18]  
> 输出: 4   
> 解释: 最长的上升子序列是 [2,3,7,101]，它的长度是 4。  

说明:  
可能会有多种最长上升子序列的组合，你只需要输出对应的长度即可。  
你算法的时间复杂度应该为$O(n^2)$ 。  


进阶: 你能将算法的时间复杂度降低到 $O(n \log n)$ 吗？  


# 方法一：动态规划
## 分析
第一眼看上去是一道动态规划的题。如果要做动态规划的话，首先需要确定这个问题能不能拆分成若干个子阶段，每个阶段是否存在一定的最优化解法，以及若干个子阶段是如何发生关系的。换句话说，就是如何定义这个最优（状态定义）、各阶段的最优如何转换（状态转移方程），当然了，总归需要一个起始（状态初始化）。以上三个就是动态规划的三要素。  
回到这道题中，如果要使用动态规划去求解，那么首先要定义一下状态。如果还是以数组作为dp状态的存储数据结构的话，`dp[i]`的含义是什么？那最简单的，我们就按题目来设好了，即`dp[i]`表示从第0个开始到第`i`个（含）数字中，最长递增子串（Longest Increasing Subsequence, LIS）的长度。那么，必然有`dp[0]=1`，也就是如果数组中只有1个数，那么LIS的长度就是1。然后我们来考虑怎么从`dp[i]`递推到后面的。  
比如我们看`nums=[9,2,5,3,7,101,18]`，这个数组，我们人肉做一前6个，`dp=[1,1,2,2,3,4,?]`。

|   nums|   9   |   2   |   5   |   3   |   7   |   101 |   18  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   dp  |   1   |   1   |   2   |   2   |   3   |   4   |   ?   |
|   LIS |   9   |   2   |   2,5 |   2,3 |  2,3,7|2,3,7,101| ？  |

那么如何求`dp[6]`呢。首先`nums[6]`是18，如果我们要生成LIS的话，前面的数一定要都小于18，换句话说，上一个数一定要小于18，而且已经生成的LIS要尽可能的长。那么有哪些数小于18呢，`9,2,5,3,7`这几个都小于18。那么我们选哪一个呢，当然是`nums[4]=7`这个咯，因为`dp[4]`是前面这几个`dp`里最大的那个。

这样一来，我们不但连“状态定义”和“状态初值”都准备好了，状态转移方程也呼之欲出：
$$
    \text{dp}[i]= 1+ \max(\text{dp}[j]\quad|\quad 0\le j\le i\quad\&\&\quad \text{nums}[i]>\text{nums}[j])
$$
也即，如果要求`dp[i]`，首先要筛选出`nums`中前面的比`nums[i]`小的，然后找他们对应的`dp`中最大的那个，再+1。

那么，最终`dp`中最大的那个，就是我们要求的LIS的最大值。

## 解题
```java
class Solution {
    public int lengthOfLIS(int[] nums) {
        //if nums.length is empty, return 0
        if(nums.length<2){
            return nums.length;
        }
        int[] dp=new int[nums.length];
        //init
        dp[0]=1;
        //remember the max dp
        int maxDp=1;
        for(int i=1;i<nums.length;i++){
            //find the max before
            int max=0;
            for(int j=0;j<i;j++){
                if(nums[j]<nums[i] && dp[j]>max){
                    max=dp[j];
                }
            }
            //assign the dp[i]
            dp[i]=max+1;
            //update the max dp
            if(dp[i]>maxDp){
                maxDp=dp[i];
            }
        }
        return maxDp;
    }
}
```
## 复杂度
这个DP的复杂度还是比较明确的。  
空间上，使用了一个额外的一维数组`dp`，长度为`n`，所以，空间复杂度是$O(n)$。  

时间上，明显有两个`for-loop`，外层的`i`从`1`到`n`，内层的`j`从`0`到`i`，所以总的循环次数就是一个一个等差数列的和，即时间复杂度是$O(\frac{n(n+1)}{2})=O(n^2)$。


# 方法二：贪心+二分查找
上面的时间复杂度是$O(n^2)$，而进阶要求时间复杂度是$O(n \log n)$。怎么做呢。看到$\log n$第一反应就是二分查找，但是怎么找呢。而且二分查找一般是在一个顺序数组上进行的，上面的`dp`数组可不一定是顺序的。  
对于这一段的分析，我们先放一下，回顾以上上面那张表，我再放一次：  

|   nums|   9   |   2   |   5   |   3   |   15  |   101 |   6  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   dp  |   1   |   1   |   2   |   2   |   3   |   4   |   ?   |
|   LIS |   9   |   2   |   2,5 |   2,3 | 2,3,15|2,3,15,101| ？  |

`dp`行没有用了，我下面就不放了。最后一行LIS表示的是，可能的最长升序子序列。注意，是可能的，像倒数第二列，可能的LIS有`2,3,7,101`、`2,5,7,101`。但我在写的时候，会尽量在可选的数字里，选择较小的那个，这是一种朴素的贪心思想，为了让后面来的数字尽可能的追加到目前的LIS上。   
没错，贪心思想就来了。  

那么，具体怎么贪呢？我们还是从前向后遍历。核心思想就是，能不增加LIS的长度，就不增加，能让LIS中某一个数变小，就尽量替换成更小的。  

|   nums|   9   |   2   |   5   |   3   |   15   |   101 |   6  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   LIS |   9
初始时，选无可选，所以`nums=9`的LIS只能是`9`。  

|   nums|   9   |   2   |   5   |   3   |   15  |   101 |   6  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   LIS |   9   |   2

到`nums=2`列时，如果把原来的LIS中的`9`替换成`2`，总长度不会增加（也增加不了），但将会留出更大的空间，让后面的数能够进来。  

|   nums|   9   |   2   |   5   |   3   |   15  |   101 |   6  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   LIS |   9   |   2   |   2,5 

你看，到`nums=5`列的时候，很庆幸前一列将LIS的`9`换成了`2`，这样，`5`就能顺利加入LIS了。  

|   nums|   9   |   2   |   5   |   3   |   15  |   101 |   6  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   LIS |   9   |   2   |   2,5 |   2,3

再往后一列，到`nums=3`列的时候，发现虽然不能增加LIS的长度，但可以稍微降低一点LIS中第2个数的大小，所以把LIS中第二个数从`5`换成了`3`。  

|   nums|   9   |   2   |   5   |   3   |   15  |   101 |   6  |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   LIS |   9   |   2   |   2,5 |   2,3 | 2,3,15|2,3,15,101

就这样，一直到`nums=101`列，LIS已经扩充到了4个数。这时候相信已经找到了一些规律，那就是如果`nums[i]`大于LIS中的数的话，就要扩充LIS的大小，并且将`nums[i]`放到LIS的最后。  
接下来，还剩最后一个`nums=6`。虽然`6`无法更新目前最优的LIS，但是还是值得记下来的。为什么呢？我们再往后编几个数：   

|   nums|   9   |   2   |   5   |   3   |   15  |   101 |   6   |    7  |   8   |   9   |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
|   LIS |   9   |   2   |   2,5 |   2,3 | 2,3,15|2,3,15,101|2,3,15,101|2,3,6,7|2,3,6,7,8|2,3,6,7,8,9|

虽然在`nums=6`处还看不见`6`的作用，但是在其之后，却结结实实地展现了`6`的威力。但这是怎么回事呢？因为`6`的出现，在后续的数字过来时，LIS中的第三个数字，不再选择`15`了，而是青睐与更小的`6`。因为`6`的出现，将LIS的第三个数的最小取值刷新成了`6`（而不再是以前的`15`了）。  
为此，我们需要额外记录一个信息，那就是在`nums=6`之后，LIS的第三个数的最小取值为`6`。
我们换个维度来看可能更清楚一点
<table style="text-align:center">
    <tr>
        <td rowspan="2">nums</td><td colspan="10">LIS中各个位置的最小值</td>
    </tr>
    <tr>
        <td>0</td><td>1</td><td>2</td><td>3</td><td>4</td><td>5</td>
    </tr>
    <tr>
        <td>9</td><td>9</td>
    </tr>
    <tr>
        <td>2</td><td bgcolor="lightgray"><font color=red>2</font></td>
    </tr>
    <tr>
        <td>5</td><td>2</td><td bgcolor="lightgray"><font color=red>5</font></td>
    </tr>
    <tr>
        <td>3</td><td>2</td><td bgcolor="lightgray"><font color=red>3</font></td>
    </tr>
    <tr>
        <td>15</td><td>2</td><td>3</td><td bgcolor="lightgray"><font color=red>15</font></td>
    </tr>
    <tr>
        <td>101</td><td>2</td><td>3</td><td>15</td><td bgcolor="lightgray"><font color=red>101</font></td>
    </tr>
    <tr>
        <td>6</td><td>2</td><td>3</td><td bgcolor="lightgray"><font color=red>6</font></td><td>101</td>
    </tr>
    <tr>
        <td>7</td><td>2</td><td>3</td><td>6</td><td bgcolor="lightgray"><font color=red>7</font></td>
    </tr>
    <tr>
        <td>8</td><td>2</td><td>3</td><td>6</td><td>7</td><td bgcolor="lightgray"><font color=red>8</font></td>
    </tr>
    <tr>
        <td>9</td><td>2</td><td>3</td><td>6</td><td>7</td><td>8</td><td bgcolor="lightgray"><font color=red>9</font></td>
    </tr>
</table>

其中LIS中各个位置的最小值，0对应上文表述的第一个数，1对应上文表述的第二个数，请注意区别。  
这时候，开心的事情来了，因为LIS中各个位置的最小值这个数组，一定是升序排列的（不然逻辑上也不对呀）。那么更新这个数组的时候，就可以使用二分查找了。那么，最终的策略就是：  

* 构建一个长度可变的数组，用来存放LIS中各个位置可能的最小值，该数组记为`minLIS`  
* 遍历`nums`数组  
* 如果`nums`数组中的数比`minLIS`中最后一个数还要大，那么就将这个数追加到`minLIS`数组的最后  
* 如果`nums`数组中的数比`minLIS`中最后一个数要小，那么久在`minLIS`中查找一个可以被替代的数，且不影响整个数组的升序顺序   
* 最终LIS的最大长度就是`minLIS`数组的长度。  

写到这里，编码就应该很简单了。

## 解题
```java
为了简便，就不使用`ArrayList`了，直接使用一个定长数组`minLIS`和一个变量`i`表示`minLIS`的长度了。
class Solution {
    public int lengthOfLIS(int[] nums) {
        int[] minLIS=new int[nums.length];
        int i=0;
        for(int num:nums){
            int pos=binarySearch(minLIS, num, 0, i);
            if(pos>=i){
                //if not found, append num behind the minLIS
                minLIS[i++]=num;
            }else{
                //if found, replace
                minLIS[pos]=num;
            }
        }
        return i;
    }

    //recursive binary search
    private int binarySearch(int[] minLIS, int target, int from, int to){
        if(from>=to){
            return from;
        }
        int pos=(from+to)/2;
        if(minLIS[pos]>=target){
            return binarySearch(minLIS, target, from, pos);
        }else{
            return binarySearch(minLIS, target, pos+1, to);
        }
    }
}
```

## 复杂度
空间上，使用了一个数组`minLIS`，其长度为`n`，所以空间复杂度是$O(n)$。  

时间上，一个与`nums`长度相同的`for-loop`嵌套一个范围与`nums`长度一致的二分查找，所以时间复杂度是$O(n\log n)$