---
title: LC-0273-整数转换英文表示
tags:
  - LeetCode
  - String
categories: LeetCode
mathjax: true
date: 2020-09-18 11:13:20
---


# 题干
将非负整数转换为其对应的英文表示。可以保证给定输入小于 231 - 1 。
<!--more-->

示例 1:  
> 输入: 123  
> 输出: "One Hundred Twenty Three"  

示例 2:  
> 输入: 12345  
> 输出: "Twelve Thousand Three Hundred Forty Five"  

示例 3:  
> 输入: 1234567  
> 输出: "One Million Two Hundred Thirty Four Thousand Five Hundred Sixty Seven"  

示例 4:  
> 输入: 1234567891  
> 输出: "One Billion Two Hundred Thirty Four Million Five Hundred Sixty Seven Thousand Eight Hundred Ninety One"  


# 分析
这题的难点估计是在英文数字的拼写吧（→，→）

从英文数字的组合来看，这题可以使用分治的思想。对于下面这个很长的数字，我们可以给他分成几组：  
$$
\overbrace{456}^{trillion}\vdots\overbrace{789}^{billions}\vdots\overbrace{123}^{millions}\vdots\overbrace{456}^{thousands}\vdots\overbrace{789}
$$
每一组里都是一个小于1000的数，使用“几百几十几”这样的写法写出来后，再将大数词（thousand和-llion）加在后面即可。  
有几个需要注意的地方：
* “几十几”部分，小于20的，有专门的单词去表示，超过20的，才使用“forty two”这样的表示法。   
* 除非输入的数是0，否则是用不到Zero的，这是一个特殊情况。   
* 如果百位是0，那么就不用显示hundred了；如果十位和个位都是0，那么hundred后面就是空的；
* 最重要的，如果“几百几十几”都是0的话，这一段就都不用输出，大数词也不用输出。（血泪的教训）   

话不多说，直接上代码。

# 解题
```java
class Solution {
    
    final String[] ONES={""," One"," Two"," Three"," Four",
                        " Five"," Six"," Seven"," Eight"," Nine", 
                        " Ten"," Eleven"," Twelve"," Thirteen"," Fourteen"," Fifteen",
                        " Sixteen"," Seventeen", " Eighteen", " Nineteen"};
    final String[] TENS={"",""," Twenty"," Thirty"," Forty"," Fifty",
                        " Sixty"," Seventy"," Eighty"," Ninety"};
    final String[] BIGS={"", " Thousand", " Million", " Billion"};
    final String HUNDRED=" Hundred";
    final String ZERO="Zero";

    public String numberToWords(int num) {
        if(num==0){
            return "Zero";
        }
        ArrayList<Integer> list=new ArrayList<>();
        while(num!=0){
            list.add(num%1000);
            num/=1000;
        }
        StringBuilder sb=new StringBuilder();
        int i=list.size()-1;
        while(i>=0){
            int n=list.get(i);
            if(n==0){
                i--;
                continue;
            }
            int hundreds=n/100;
            if(hundreds>0){
                sb.append(ONES[hundreds]).append(HUNDRED);
            }
            n%=100;
            if(n<20){
                sb.append(ONES[n]);
            }else{
                sb.append(TENS[n/10]).append(ONES[n%10]);
            }
            sb.append(BIGS[i--]);
        }
        return sb.substring(1);
    }
}
```

# 代码分析
可以看到，我将所有数词都先抽出来了，然后把空格`" "`加在了数词前面，这样在下面的编码中就不用再考虑空格的事情了。当然，留空的几个（比如`ONES[0]`、`TENS[0]`、`TENS[1]`、`BIGS[0]`）不能加，不然反而会多一个空格。`"Zero"`因为是特例，所以也不用加。   

在程序中，在判断完特殊情况`num==0`后，首先利用取余和整除，将num每3位取出，并从低到高放在List中。从低到高放的好处是，能够很清楚的将大数词`BIGS`和List中的元素对应起来。

然后开始分治处理，因为最终的英文字符串是从高位到低位标书的，所以List要倒序遍历。对每一个三位数，如果是0的话，直接跳过。如果不是0，就将“几百几十几”追加到输出的字符串中。  

最后，由于每一个数词前都有一个空格，而最终输出的字符串开头不是空格，所以要`substring`一下。观察了一下源码，无论是`StringBuilder::toString`还是`StringBuilder::substring`，最终都是调用的都是`StringLatin1`或`StringUTF16`的`newString(byte[] val, int index, int len)`方法，所以没有明显的性能损失。  
