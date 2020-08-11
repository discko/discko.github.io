---
title: LC-0003-无重复字符的最长子串
date: 2020-07-31 15:15:35
tags: [LeetCode, Sliding Window, Two Pointer]
categories: LeetCode
mathjax: true
---
# 题干
给定一个字符串，请你找出其中不含有重复字符的 最长子串 的长度。
<!--more-->
示例 1:
> 输入: "abcabcbb"  
> 输出: 3   
> 解释: 因为无重复字符的最长子串是 "abc"，所以其长度为 3。 

示例 2:
> 输入: "bbbbb"  
> 输出: 1  
> 解释: 因为无重复字符的最长子串是 "b"，所以其长度为 1。  

示例 3:
> 输入: "pwwkew"  
> 输出: 3  
> 解释: 因为无重复字符的最长子串是 "wke"，所以其长度为 3。
> 请注意，你的答案必须是 子串 的长度，"pwke" 是一个子序列，不是子串。
     
# 分析
此题所需要的，是寻找一个子串，判断其是否含有重复字符。如果含有重复字符，则换下一个子串；否则判断当前子串的长度是否超过目前已经找到的满足题意的子串的长度。所以，我们需要确定的，是如何去取子串，并快速判断该子串中知否存在重复字符。  
取字符串时，采用滑动窗口的方式。窗口有两个参数，一个是位置，一个是大小，也即窗宽和窗位。我们使用`start`和`end`两个指针来代表这个滑动窗口即可。  
快速判断是否存在重复字符简单，利用Hash Table，key记录字符，value记录最后一次出现该字符的位置。只要`str[end]`最后一次出现的位置在start之前，就说明在`str[start,end]`之间出现了重复的字符。

比如一个带判断的字符串$abcdcefg$，我们选择一个子串$\boxed{a}bcdcefg$，其中是没有重复字符的，那么就向右多选择一个字符。  

得到$\boxed{ab}cdcefg$，仍然没有重复字符，此时最大无重复字符子串长度为2。则再向右多选则一个。  

得到$\boxed{abc}dcefg$，仍然没有重复字符，此时最大无重复字符子串长度为3。则再向右多选择一个。 

得到$\boxed{abcd}cefg$，仍然没有重复字符，此时最大无重复字符子串长度为4。则再向右多选择一个。  

得到$\boxed{abcdc}efg$，此时有了重复字符。那么接下来有两种选择子串的方式：
* 方法一：回头重新选择：
选择$a\boxed{bc}dcefg$。此种选择方法其实之前在判断$\boxed{abc}dcefg$时已经判断过了，一定是没有重复字符的。所以这种方法比较浪费时间。这样的时间复杂度为$O(n^2)$
* 方法二：仅移动左边界：
选择$a\boxed{bcd}cefg$。没有重复的，然后右边界移动，得到$a\boxed{bcdc}efg$。有重复的，左边界再移动，$ab\boxed{cdc}efg$。有重复的，左边界再移动，$abc\boxed{dc}efg$。没有重复的了。以此类推，这样的时间复杂度最坏为$O(2n)=O(n)$，也即最坏情况下（如$aaaaa$）右边界移动一下，左边界移动一下。
* 方法三：双边界都移动：
因为如果需要判断$\boxed{abcdc}efg$，则在此之前其无重复字符的子串的最大长度一定至少是4了。只需要判断长度为5或更大的即可。因此将整个框子向右移动一次：$a\boxed{bcdce}fg$。发现其中有重复字符。那如果左边界直接跳过重复字符呢？  
由于刚刚的重复字符是c，前一个重复字符位于2处，所以左边界直接跳至3，同时右边界移动1个位置，得到：$abc\boxed{dce}fg$。然后右边界逐步向右。  
注意，右侧只能一步一步往前走，如果右边界向右跳的话，就无法往Hash Table中添加字符信息了。另外，如果在Hash Table中存储字符所在位置的后一个位置的话，左边界在跳跃时，就不需要再+1了。


# 解题
```java
class Solution {
    public int lengthOfLongestSubstring(String s) {
        if(s.isEmpty()){
            return 0;
        }
        //minimum answer is 1 letter as a substring.
        int ans=1;
        int start=0, end=0;
        int sLen=s.length();
        //store last character's position. key: character, value: position
        HashMap<Character, Integer> map=new HashMap<>();
        while(end<sLen){
            char cEnd=s.charAt(end);
            if(map.containsKey(cEnd)){
                //when find duplicate character, start jump to the position
                //if the position > start
                //or the duplicate character appears before the start (and 
                //it means the character str[end] is not duplicated in
                //str[start, end])
                start=Integer.max(start, map.get(cEnd));
            }
            //increase end first, and then put(cEnd, end), store
            // the position 1 behind the character
            end++;
            map.put(cEnd, end);
            ans=Integer.max(end-start, ans);
        }
        return ans;
    }
}
```
# 复杂度分析
时间上，由于end一直在向右移动，未曾停歇，所以一共执行了n次。而每一次中，移动start、插入Hash Table、查询Hash Table、计算ans都是$O(1)$的，因此时间复杂度为$O(n)$。  

空间上，由于使用了Hash Table，并且每一个不同的字符都会存储在Hash Table中，所以空间复杂度为$O(n)$。

