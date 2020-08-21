---
title: LC-0001-两数之和
date: 2020-07-31 10:24:18
tags: [LeetCode, HashTable]
categories: LeetCode
mathjax: true
---
# 题干  
给定一个整数数组 nums 和一个目标值 target，请你在该数组中找出和为目标值的那 两个 整数，并返回他们的数组下标。  
你可以假设每种输入只会对应一个答案。但是，数组中同一个元素不能使用两遍。 
<!--more--> 
示例：  
> 输入： nums = [2, 7, 11, 15], target = 9  
> 输出： [0, 1]

# 分析  
难易程度： ☆  
这题就算是个热身题了，听说有的人把 「两数之和」 作为刷题或者说算法的入门题，说编程就是「Hellow World」，说刷题就是「两数之和」。  


回到这道题目，对于已知的一个和，我们知道「加数1+加数2=和」，当我们遍历数组的时候，每一次会取到一个加数1，那么加数2=和-加数1。这时候，我们唯一要做的事情就是判断加数2是否存在于这个数组中。而要快速判断元素的存在性，使用$O(1)$时间的Set即可解决。也即将nums数组添加到Set中，然后遍历数组时，判断「和-该数」是否在Set中。  


但此时可能会遇到一个问题，因为题干中没有表述数组中是否会存在重复的数。比如`nums=[2,2,3], target=4`这样的例子，如果使用Set去处理，最终的Set中将仅有`{2,3}`两个元素，显然是无法解决问题的。因此换用哈希表（Hash Table）进行处理。  

让Hash Table的key记录数组的值，让value记录数组值出现的位置。这样第一次遍历，对于`nums=[2,2,3], target=4`，即使Hash Table中`{key=2, value=0}`被`{key=2, value=1}`覆盖，但从头开始遍历时，通过`nums[0]=2`从Hash Table中取出的`{key=2, value=1}`，不是当前的这个2，因此可以可以得到`num[0],num[1]`这样一组答案。

此处，我们将「加数1」称为lhs，也即left hand side，「加数2」称为rhs，也即right hand side

# 解题
```java
import java.util.HashMap;
class Solution {
    public int[] twoSum(int[] nums, int target) {
        HashMap<Integer, Integer> map=new HashMap<>();
        //store num and (target-num) as key-value
        for(int i=0;i<nums.length;++i){
            map.put(nums[i], i);
        }
        //start matching
        for(int lhsIndex=0;lhsIndex<nums.length;++lhsIndex){
            Integer rhsIndex=map.getOrDefault(target-nums[lhsIndex], null);
            if(rhsIndex==null||rhsIndex.equals(lhsIndex)){
                continue;
            }
            return new int[]{lhsIndex, rhsIndex};
        }
        return new int[2];
    }
}
```
虽然该解法已经是$O(1)$的解法了，但仍然还有可以优化的空间。上面的代码最坏将会遍历数组2次，遍历过程中其实本来就可能发现结果而提前结束。因此，可以一边遍历，一边初始化Hash Table。
```java
//optimized
import java.util.HashMap;
class Solution {
    public int[] twoSum(int[] nums, int target) {
        HashMap<Integer, Integer> map=new HashMap<>();
        for(int lhsIndex=0;lhsIndex<nums.length;++lhsIndex){
            Integer rhsIndex=map.getOrDefault(target-nums[lhsIndex], null);
            if(rhsIndex==null){
                map.put(nums[lhsIndex], lhsIndex);
            }else{
                return new int[]{lhsIndex, rhsIndex};
            }
        }
        return new int[2];
    }
}
```
# 复杂度分析
时间上，最坏情况是到最后一个才找到能够匹配的两个加数。
空间上，无额外空间。
因此：
时间复杂度：$O(n)$  

空间复杂度：$O(1)$  