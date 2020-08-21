---
title: LC-0005-最长回文子串
tags:
  - LeetCode
  - DynamicProgramming
categories: LeetCode
mathjax: true
date: 2020-08-12 09:14:03
---

# 题干
给定一个字符串 s，找到 s 中最长的回文子串。你可以假设 s 的最大长度为 1000。  
<!--more-->
示例1：

>输入: "babad"  
>输出: "bab"  
>注意: "aba" 也是一个有效答案。  

示例2：  

>输入: "cbbd"  
>输出: "bb"

# 分析
我们可以知道：

* 如果字符串只有1个字符，那它一定是回文串。
* 如果字符串只有2个字符，且这两个字符是相同的，那它是回文串；否则不是回文串。
* 如果字符串的首尾2个字符相同，那么这个字符串是否是回文的，只取决于该字符串去掉首尾字符后，是否是回文的。（比如字符串abcba，去掉首尾那2个相同的字符后~~a~~bcb~~a~~，如果里面剩下的是回文串，那么abcba就是回文串）。  

这样一来，动态规划的两个重要阶段就准备好了，也就是初始化和状态转移。不过我们先不急着写初始化表达式和状态转移方程，我们先来模拟一下。  
我们有下面这样一个表格：

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|\\| | | | | | | |
|a| |\\| | | | |$\checkmark$| |
|b| | |\\| | | | | |
|c| | | |\\| | | | |
|c| | | | |\\|×| | |
|b| | | | | |\\| | |
|a| | | | | | |\\| |
|d| | | | | | | |\\|

该表格中我们仅使用右上角的这半个表格。每一个格子表示从该行的”\“处开始到这个格子构成的字符串是不是一个回文串。比如”$\checkmark$“处，就表示"abccba"是一个回文串；“×”处就表示"cb"不是一个回文串。  
换句话说，这个格子的行字符就表示这个子串的起始字符（首字符），列字符就表示这个子串的结尾字符（尾字符）。  
接下来我们先根据上面3条对这个表格进行初始化：  

* 首先，如果字符串只有1个字符，那它一定是回文串。只有一个字符的时候，也就是起始和终点在一起的，也就是表格对角线上的字符串。

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|$\checkmark$| | | | | | | |
|a| |$\checkmark$| | | | | | |
|b| | |$\checkmark$| | | | | |
|c| | | |$\checkmark$| | | | |
|c| | | | |$\checkmark$| | | |
|b| | | | | |$\checkmark$| | |
|a| | | | | | |$\checkmark$| |
|d| | | | | | | |$\checkmark$|

* 其次，如果字符串只有2个字符，且这两个字符是相同的，那它是回文串；否则不是回文串。那么复杂的我们先不考虑，先考虑简单的，也就是对角线右侧一格的（至于为什么先只考虑这个，我们待会儿再说），只要行字母和纵字母一致，就打钩，否则打叉。

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|$\checkmark$|$\checkmark$| | | | | | |
|a| |$\checkmark$|×| | | | | |
|b| | |$\checkmark$|×| | | | |
|c| | | |$\checkmark$|$\checkmark$| | | |
|c| | | | |$\checkmark$|×| | |
|b| | | | | |$\checkmark$|×| |
|a| | | | | | |$\checkmark$|×|
|d| | | | | | | |$\checkmark$|

* 最后，如果字符串的首尾2个字符相同，那么这个字符串是否是回文的，只取决于该字符串去掉首尾字符后，是否是回文的。那我们不妨从右下角开始判断。  
首先是下表中红色位置处，为什么是×呢，很简单，因为首尾两个字母是不相同的（行字符/首字符是b，而列字符/尾字符是d）

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|$\checkmark$|$\checkmark$| | | | | | |
|a| |$\checkmark$|×| | | | | |
|b| | |$\checkmark$|×| | | | |
|c| | | |$\checkmark$|$\checkmark$| | | |
|c| | | | |$\checkmark$|×| | |
|b| | | | | |$\checkmark$|×|<font color=red>×</font>|
|a| | | | | | |$\checkmark$|×|
|d| | | | | | | |$\checkmark$|

依次类推，我们可以一直按从左往右，从下往上的顺序填到这里：

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|$\checkmark$|$\checkmark$| | | | | | |
|a| |$\checkmark$|×| | | | | |
|b| | |$\checkmark$|×|<font color=red>×</font>| | | |
|c| | | |$\checkmark$|<font color=blue>$\checkmark$</font>|<font color=red>×</font>|<font color=red>×</font>|<font color=red>×</font>|
|c| | | | |$\checkmark$|×|<font color=red>×</font>|<font color=red>×</font>|
|b| | | | | |$\checkmark$|×|<font color=red>×</font>|
|a| | | | | | |$\checkmark$|×|
|d| | | | | | | |$\checkmark$|

这时候，要判断最上面红色<font color=red>×</font>的右侧那个格子（也就是子字符串"bccb"）。由于行字符（首字符）和列字符（尾字符）都是b，所以这个子串可能是回文的。  
然后就要判断去掉首尾字符之后剩余的子串是否是回文的，这个子串是"cc"。那么"cc"是不是呢，因为在初始化的时候已经判断过了（就是那个蓝色的<font color=blue>$\checkmark$</font>)，是回文的。所以"bccb"也是回文的，这个格子可以打钩了。然后继续从左往右从下往上依次逐格判断。  

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|$\checkmark$|$\checkmark$| | | | | | |
|a| |$\checkmark$|×|<font color=red>×</font>|<font color=red>×</font>|<font color=red>×</font>| | |
|b| | |$\checkmark$|×|×|<font color=blue>$\checkmark$</font>|<font color=red>×</font>|<font color=red>×</font>|
|c| | | |$\checkmark$|$\checkmark$|×|×|×|
|c| | | | |$\checkmark$|×|×|×|
|b| | | | | |$\checkmark$|×|×|
|a| | | | | | |$\checkmark$|×|
|d| | | | | | | |$\checkmark$|

这时候，就到了判断子串"abccba"是不是回文的了。首先，首尾字符都是'a'，所以可能是回文的；然后砍掉首尾字符之后，剩下的子串是"bccb"，这不就是我们刚刚判断过的么（也就是哪个蓝色的<font color=blue>$\checkmark$</font>），所以"abccba"也是回文的。那么根据这个规律一直填完所有的格子。  

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|$\checkmark$|$\checkmark$|×|×|×|×|×|×|
|a| |$\checkmark$|×|×|×|×|<font color="gold">$\checkmark$</font>|×|
|b| | |$\checkmark$|×|×|$\checkmark$|×|×|
|c| | | |$\checkmark$|$\checkmark$|×|×|×|
|c| | | | |$\checkmark$|×|×|×|
|b| | | | | |$\checkmark$|×|×|
|a| | | | | | |$\checkmark$|×|
|d| | | | | | | |$\checkmark$|


这样，填完之后，所有打$\checkmark$处代表的子串都是回文子串。目测一下，就能发现，黄色<font color="gold">$\checkmark$</font>处的子串是所有回文子串中最长的一个。  
在这个过程中，我们可以发现，去掉首尾字符后的子串，其实就是当前子串左下角相邻的那个子串。这也就解释了为什么我们只需要初始化对角线和对角线右侧一格的值，因为获得↙方向子串是否是回文串的话，就需要一张↘方向的网进行兜底（以防向↙移动的过程中无法触及初始化的值），而如果仅初始化对角线的话，会形成网眼，可能会漏掉部分↙移动的判断，比如下面这个情况：  

| |a|a|b|c|c|b|a|d|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|a|\\| | | | | | | |
|a| |\\| | | | | | |
|b| | |\\| | | | | |
|c| | | |\\| | | | |
|c| | | | |\\|↙| | |
|b| | | | |○|\\| | |
|a| | | | | | |\\| |
|d| | | | | | | |\\|

就会从“↙”标志处越过初始化的对角线，到达“○”处。  

# 解题
```java
class Solution{
    public String longestPalindrome(String str) {
        //longest palindrome's left pos and right pos
        //contains left pos and right pos
        int left=0, right=0;
        int len=str.length();
        if(len<2){
            return str;
        }else if(len==2){
            return str.charAt(0)==str.charAt(1)?str:(str.charAt(0)+"");
        }
        //2-dim dp
        //dp[i][j]=true means s[i:j] IS palindrome 
        //init:
        //  dp[i][i]=true, dp[i][i+1]=s[i]==s[i+1]
        //transfer equations:
        //  dp[i][j]=false,         when s[i]!=s[j]
        //  dp[i][j]=dp[i+1][j-1],  else
        //return:
        //  any pair (i,j) that dp[i][j]==true and j-i is maximum

        boolean[][] dp=new boolean[len][len];
        char[] s=str.toCharArray();
        //init
        for(int i=0;i<len-1;i++){
            dp[i][i]=true;
            if(s[i]==s[i+1]){
                dp[i][i+1]=true;
                left=i;
                right=i+1;
            }
        }
        dp[len-1][len-1]=true;
        //dp
        for(int i=len-3;i>=0;i--){
            for(int j=i+2;j<len;j++){
                if(s[i]!=s[j]){
                    //if first char not equals to last char
                    //it means substring s[i:j] is not palindrome
                    dp[i][j]=false;
                }else{
                    //if first char equals to last char
                    //it means substring s[i:j] is same as s[i+1:j-1]
                    dp[i][j]=dp[i+1][j-1];
                }
                //if s[i:j] is palindrome, update return value
                if(dp[i][j] && j-i>right-left){
                    right=j;
                    left=i;
                }
            }
        }
        //right pos is contained
        return str.substring(left, right+1);
    }
}
```