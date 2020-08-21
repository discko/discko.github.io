---
title: LC-0004-寻找两个正序数组的中位数
date: 2020-08-04 14:36:43
tags: [LeetCode, BinarySearch, Array]
categories: LeetCode
mathjax: true
---
# 题干  
给定两个大小为 m 和 n 的正序（从小到大）数组 nums1 和 nums2。  
请你找出这两个正序数组的中位数，并且要求算法的时间复杂度为 O(log(m + n))。  
<!--more-->
你可以假设 nums1 和 nums2 不会同时为空。
示例1

  > nums1 = [1, 3]  
  > nums2 = [2]  
  > 则中位数是 2.0

示例2

  > nums1 = [1, 2]  
  > nums2 = [3, 4]  
  > 则中位数是 (2 + 3)/2 = 2.5

# 分析  
为了表述方便，我们设`len1=nums1.length`,`len2=nums2.length`。
第一反应是归并，一边归并一边计数，当归并到达总数的一半$(len1+len2)/2$时，即可认为到达中位数了。但这种方法的时间复杂度为$O(len1+len2)$，所以不符合题目要求。  
看到时间复杂度为$log(x)$则很容易想到使用二分法。那么最主要的就是，怎么分。  
## 基础概念
回归最原始的想法。对于奇数长度的数组，如果我们有一个中位数，则中位数将这个有序数组的长度分为了左右两个部分，左边与右边长度应该是相等的，独留中位数一个数：  
$$\boxed{1\quad2\quad3}\quad\boxed{4}\quad\boxed{5\quad6\quad7}$$
同理，对于偶数长度的数组，如果已知中位数的话，也是一样的：  
$$\boxed{1\quad2\quad3}\quad\boxed{4\quad5}\quad\boxed{6\quad7\quad8}$$
为了统一一下，我们将方框改为分割线，将数组划分为左右两个部分，使两部分的长度严格保证左侧的长度不小于右侧的长度：
$$1\quad2\quad3\quad4\quad|\quad5\quad6\quad7$$
以及  
$$1\quad2\quad3\quad4\quad|\quad5\quad6\quad7\quad8$$
如此一来，对于一个数组，我们只要能够找到这条分割线，那么中位数就是分割线左边的那个元素（如果数组长度是奇数），或者是分割线左右两侧各1个数的平均值（如果数组长度是偶数）。

## 回到原题
那么对于本题中，如果输入的是两个数组的话，我们需要将两个数组中的所有元素合起来，并分为两个部分。也即两个数组中各划一个分隔符。将分隔符以左的所有数，严格小于分隔符以右的所有数。  
对于奇数总长的：
$$
\begin{align*}
&1\quad2\quad4\quad|\quad6 \\
&1\quad3\quad|\quad4\quad5\quad9
\end{align*}
$$
这里的分隔符将两个数组分割为了左右两个部分，且左侧元素个数为5，右侧元素个数为4，即左侧元素个数不少于右侧元素个数。由于左侧的`1 1 2 3 4`严格小于右侧的`4 5 6 9`，所以，中位数的位置非常明显，将是左侧这5个数里的最大值。也就是`4`。  
同理，对于偶数总长的： 
$$ 
\begin{align*}
&1\quad2\quad4\quad|\quad6 \\
&1\quad3\quad|\quad4\quad5\quad9\quad10
\end{align*}
$$
这里的分隔符将两个数组分割为了左右两个部分，且左右侧元素个数都为5。由于左侧的`1 1 2 3 4`严格小于右侧的`4 5 6 9 10`，所以，中位数，将是左侧这5个数里的最大值和右侧5个数里的最小值的均值。也就是`(4+4)/2=4`。 
我们不妨设：
```
nums1a=nums1中分割线左侧的数
nums1b=nums1中分割线右侧的数
nums2a=nums2中分割线左侧的数
nums2b=nums2中分割线右侧的数
```
所以，总的来说，只要找到了这条分割线，那么中位数就是
$$
\begin{equation*}
median=\left\{
\begin{aligned}
& \max(nums1a,\,nums2a), & &(len1+len2)\in odd \\
& \frac{\max(nums1a,\,nums2a)+\min(nums1b,\,nums2b)}{2}, & &(len1+len2)\in even \\
\end{aligned}
\right.
\end{equation*}
$$

## 找分割线
那么接下来，剩下的就是如何找分割线了。  
根据上面的分析，我们知道，分割线一定会将两个数组分割为左右两个区域，且左右两个区域中数字的个数一定是相等的（当总长度为偶数时）或左边比右边多1个（当总长度为奇数时）。因此，如果设`i`为nums1中分割线左侧的元素数量，`j`为nums2中分割线左侧元素的数量。  

***这里可以引申一下，对于`nums1[i]`就表示取nums1数组中分割线右侧的那个元素，`nums1[i-1]`就表示取分割线左侧的元素；`nums2[j]`和`nums2[j-1]`同理，表示取nums2中分割线右侧和左侧的元素。***  

则一定有：  
$$ i+j=(len1+len2+1)/2 $$
其中等式右侧的`/`为整除，被除数中`+1`是为了统一总长度为奇数与偶数的两种情况。

接下来，分割线的另一个性质是：分割线左侧的所有数一定不大于右侧所有数。也即：
$$\max(leftNumbers)<=\min(rightNumbers)$$
而对于`i`而言，如果`nums1[i-1]`>`nums2[j]`，也即如下图中所示的$c$>$d$，则说明该分割线取的不对，应当将`i`向左移动。  
$$ 
\begin{align*}
&a\quad b\quad c\quad|\quad d \\
&e\quad|\quad f\quad g\quad h\quad i\quad j
\end{align*}
$$
反之，如果`nums1[i-1]`$\le$`nums2[j]`，则说明`i`可能还可以往右移动。  

那么怎么移动呢？当然是通过二分查找来寻找最佳的移动目的地了。
我们将上面的例子稍微写长一点，这样看着更清楚。对于下面的两个数组：
$$ 
\begin{align*}
&\boxed{1\quad 3\quad 5\quad 7\quad 9\quad 11\quad 13}\\
&\;2\quad 4\quad 10\quad 11\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align*}
$$
我们来考虑`i`的位置。那么`i`首先可以选择的区间应该是$[0,len1]$的闭区间。然后进行二分查找，得到`i=4`，由此`j=(len1+len2+1)/2-i=4`，所以分割线如下：
$$ 
\begin{align}
&1\quad 3\quad 5\quad 7\quad|\quad 9\quad 11\quad 13\\
&2\quad 4\quad 10\quad 11\quad|\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align}
$$
此时`nums1[i-1]`$\le$`nums2[j]`是满足的（$7<12$)，因此，`i`可以继续往右移动。所以可移动的区间是：  
$$ 
\begin{align*}
&1\quad 3\quad 5\quad 7\quad\boxed{ 9\quad 11\quad 13}\\
&2\quad 4\quad 10\quad 11\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align*}
$$
再次二分查找，跳跃到这里：  
$$ 
\begin{align*}
&1\quad 3\quad 5\quad 7\quad 9\quad 11\quad|\quad 13\\
&2\quad 4\quad|\quad 10\quad 11\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align*}
$$
也即`i=6`而`j=2`。此时`nums1[i-1]`$\le$`nums2[j]`是不满足的（$11>10$)，因此需要将`i`向左调整，可调整的区间为：
$$ 
\begin{align*}
&1\quad 3\quad 5\quad 7\quad\boxed{ 9\quad 11}\quad 13\\
&2\quad 4\quad 10\quad 11\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align*}
$$
第3次二分查找，跳跃到这里：  
$$ 
\begin{align*}
&1\quad 3\quad 5\quad 7\quad 9\quad|\quad 11\quad 13\\
&2\quad 4\quad 10\quad|\quad 11\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align*}
$$
也即`i=5`而`j=3`，此时`nums1[i-1]` $\le$ `nums2[j]`是满足的（$9<11$)，因此，`i`可以继续往右移动。所以可移动的区间是：  
$$ 
\begin{align*}
&1\quad 3\quad 5\quad 7\quad 9\quad \boxed{11}\quad 13\\
&2\quad 4\quad 10\quad 11\quad 12\quad 13\quad 14\quad 16\quad 18
\end{align*}
$$
我们发现，此时的`i`可移动区间里，只有11这一个元素了。所以此时二分查找可以认为已经结束了。因此，最后一次的分割线就是最终的分割线。  
所以中位数在这个例子中是：
$$median=\frac{\max(0,10)+\min(11,11)}{2}=\frac{10+11}{2}=10.5.$$

# 解题
## 准备
首先先对数据进行处理，由于`i`和`j`知道一个就可以计算出另外一个，而我们始终只对其中一个数组进行二分查找，所以不妨始终只对短的那个进行。
```java
  if(nums1.length>nums2.length){
    int[] t=nums1;
    nums1=nums2;
    nums2=t;
  }
```
然后取若干变量, `len1`和`len2`是两个数组的长度的别名，`left`和`right`是`i`的位置（也就是`nums1`数组中分割线位置）可供二分查找的范围，`totalLeft`是两个数组中分割线左侧所有元素的个数，届时`j=totalLeft-i`：
```java
  //short for array's length
  int len1=nums1.length;
  int len2=nums2.length;
  //i's left and right boundary
  int left=0, right=len1;
  //count of all numbers on the left side of split line 
  int totalLeft=(len1+len2+1)/2;
```
## 二分查找
接下来就开始二分查找了：
```java
  while(left<right){
    int i=left+(right-left+1)/2;
    int j=totalLeft-i;
    if(nums1[i-1]>nums2[j]){
      right=i-1;
    }else{
      left=i;
    }
  }
```
这里需要注意一下，原本的写法应该是`int i=left+(right-left)/2;`，由于`left`$<$`right`在循环体内恒成立，所以`(right-left)/2`的最小值为0。则当`left=0`时，`i`可能为0，则`nums[i-1]`可能会数组越界，则此时还需要去进行数组下表越界判断，太麻烦了。同时，一个更大的隐患是可能会出现死循环。我们用下面这样一个例子：

> nums1 = [1,2,3,4]  
> nums2 = [6,7,8,9,10]  

首先定边界，`left=0, right=2`
$$ 
\begin{align*}
&\boxed{1\quad 2}\\
&\;6\quad 7\quad 8\quad 9\quad 10
\end{align*}
$$
第一轮二分查找，`i=left+(right-left)/2=0+(2-0)/2=1`而` j=totalLeft-i=4-2=3`。也即：
$$ 
\begin{align*}
&1\quad|\quad 2\\
&6\quad 7\quad 8\quad|\quad 9\quad 10
\end{align*}
$$
此时判断`nums1[i-1]>nums2[j]) = false` （即`2>7=false`），走`else`的分支，得到`left=i=1`而`right=2`保持不变：
$$ 
\begin{align*}
&1\quad \boxed{2}\\
&6\quad \;7\quad 8\quad 9\quad 10
\end{align*}
$$
然后进行第二轮二分查找，`i=left+(right-left)/2=1+(2-1)/2=1`而` j=totalLeft-i=4-2=3`。也即：
$$ 
\begin{align*}
&1\quad|\quad 2\\
&6\quad 7\quad 8\quad|\quad 9\quad 10
\end{align*}
$$
发现和第一轮二分查找的结果是一样的，也即进入了死循环。  

解决这个问题的办法就是让`i`强制移动，所以`int i=left+(right-left+1)/2;`，这里由于`right`必定大于`left`，所以`right-left+1`$\ge$`2`，所以`i`一定会发生变化。

## 求值
最终的中位数，一定出现在分割线的两侧。根据前面的公式：
$$
\begin{equation*}
median=\left\{
\begin{aligned}
& \max(nums1a,\,nums2a), & &(len1+len2)\in odd \\
& \frac{\max(nums1a,\,nums2a)+\min(nums1b,\,nums2b)}{2}, & &(len1+len2)\in even \\
\end{aligned}
\right.
\end{equation*}
$$
有：
```java
  int nums1Split=left;
  int nums2Split=totalLeft-left;
  int nums1a=nums1Split>0?nums1[nums1Split-1]:Integer.MIN_VALUE;
  int nums1b=nums1Split<len1?nums1[nums1Split]:Integer.MAX_VALUE;
  int nums2a=nums2Split>0?nums2[nums2Split-1]:Integer.MIN_VALUE;
  int nums2b=nums2Split<len2?nums2[nums2Split]:Integer.MAX_VALUE;

  if((len1+len2)%2==0){
      return (Integer.max(nums1a, nums2a)+Integer.min(nums1b, nums2b))/2.0;
  }else{
      return Integer.max(nums1a, nums2a);
  }
```

## 完整代码
```java
class Solution{
  public double findMedianSortedArrays(int[] nums1, int[] nums2){
        //make nums1.length<=nums2.length
        if(nums1.length>nums2.length){
            int[] t=nums1;
            nums1=nums2;
            nums2=t;
        }
        int len1=nums1.length;
        int len2=nums2.length;
        //(10+9+1)/2 == (10+10)/2 == total count of left numbers
        int totalLeft=(len1+len2+1)/2;

        //range [left, right] is the probable split position in nums1
        //the largest range is [0, len1].
        int left=0; //of nums1
        int right=len1; // of nums1 either

        //assign i as 1st right index of the split line in nums1
        //assign j as 1st right index of the split line in nums2
        //i+j==totalLeft
        //  2   4   6 | 15
        //               i=3
        //  1 | 7   8   10   17
        //      j=1

        //binary search the probable position of i and j
        while(left<right){
            //binary select
            int i=left+(right-left+1)/2; 
            int j=totalLeft-i;
            //if left side of split line in nums1
            //is not strickly less than 
            //right side of split line in nums2
            if(nums1[i-1]>nums2[j]){
                //split position must in range [0, i)
                right=i-1;
            }else{
                //split position must in range [i, len1]
                left=i;
            }
        }

        //loop terminates when left meets right
        //at this time, the median should be 
        //in 4 numbers at the both side of both split line
        int nums1Split=left;
        int nums2Split=totalLeft-left;
        int nums1a=nums1Split>0?nums1[nums1Split-1]:Integer.MIN_VALUE;
        int nums1b=nums1Split<len1?nums1[nums1Split]:Integer.MAX_VALUE;
        int nums2a=nums2Split>0?nums2[nums2Split-1]:Integer.MIN_VALUE;
        int nums2b=nums2Split<len2?nums2[nums2Split]:Integer.MAX_VALUE;

        if((len1+len2)%2==0){
            return (Integer.max(nums1a, nums2a)+Integer.min(nums1b, nums2b))/2.0;
        }else{
            return Integer.max(nums1a, nums2a);
        }
    }
}

```

# 复杂度分析
由于我们始终是在长度较小的那个数组中进行二分查找，所以：  
时间复杂度为$O(\log(\min(n,m))$，其中n和m为两个数组的大小。  

空间复杂度为$O(1)$，因为只额外用了常数的空间，没有使用递归等手法。