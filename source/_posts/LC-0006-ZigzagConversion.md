---
title: LC-0006-Z字形变换
tags:
  - LeetCode
  - Simulate
categories: LeetCode
mathjax: true
date: 2020-08-13 09:55:12
---

# 题干
将一个给定字符串根据给定的行数，以从上往下、从左到右进行 Z 字形排列。

比如输入字符串为 "LEETCODEISHIRING" 行数为 3 时，排列如下：
```
L   C   I   R  
E T O E S I I G  
E   D   H   N  
```

之后，你的输出需要从左往右逐行读取，产生出一个新的字符串，比如："LCIRETOESIIGEDHN"。
<!--more-->
请你实现这个将字符串进行指定行数变换的函数：  
`string convert(string s, int numRows); `   
示例 1:

> 输入: s = "LEETCODEISHIRING", numRows = 3  
> 输出: "LCIRETOESIIGEDHN"  

示例 2:  

> 输入: s = "LEETCODEISHIRING", numRows = 4  
> 输出: "LDREOEIIECIHNTSG"  

解释:
```
L     D     R
E   O E   I I
E C   I H   N
T     S     G
```

# 分析
根据题意，要将原来$\longrightarrow$方向的字符串改成$\downarrow\nearrow\downarrow\nearrow$这样排布的字符串，并且按行输出。  
而且题目给大家省事了，不用考虑空格，那么其实就可以以$\downarrow\uparrow\downarrow\uparrow$的方向来填充，只不过需要注意的是，在上下两个端点，都只能停留一下。用a-z表示的话，差不多就是这样的：  
```
agm
bfhln
ceiko
djp
```
而因为无论如何，所有字符都是需要遍历一遍的，也就是说算法是$O(n)$的，那么模拟一下排列的顺序，就可以了。  
我们取一个变量`i`，让其代表即将填充到第`i`行所代表的字符串中。然后每填完一行，`i`就自增，直到到达行数`numRows`；再依次自减，直到为0；再依次自增，直到为`numRows`……如此循环，直到所有字符都被输出，结束。  
为了减少字符串的构建，我们采用`StringBuilder`存储每一行，最后再合并。  

# 解题
```java
class Solution {
    public String convert(String s, int numRows) {
        //if only 1 row, returns with unmodified
        if(numRows==1)
            return s;
        //numRows StringBuffers
        StringBuffer[] sbs=new StringBuffer[numRows];
        for(int i=0;i<numRows;i++){
            sbs[i]=new StringBuffer();
        }
        //the row to append the character
        int arrIndex=0;
        //step dicrection. 1: downward  0: upward
        int direction=1;
        //iterate the string
        for(int stringIndex=0;stringIndex<s.length();++stringIndex){
            sbs[arrIndex].append(s.charAt(stringIndex));
            arrIndex+=direction;
            if(direction>0&&arrIndex==numRows-1){
                direction=-1;
            }else if(direction<0&&arrIndex==0){
                direction=1;
            }
        }
        StringBuffer result=new StringBuffer();
        for(StringBuffer sb:sbs){
            result.append(sb);
        }
        return result.toString();
    }
}
```
# 复杂度分析
纯模拟算法，目标字符串长度是多少，时间复杂度就是多少，所以时间复杂度是$O(n)$.   
空间上，由于需要将每一行的内容分别存储，而所有行总共的字符也是目标字符串的长度，所以空间复杂度也是$O(n)$.