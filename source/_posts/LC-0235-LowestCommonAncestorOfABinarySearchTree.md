---
title: LC-0235-二叉搜索树的最近公共祖先
tags:
  - LeetCode
  - Tree
  - BST
categories: LeetCode
mathjax: true
date: 2020-09-17 10:30:39
---


# 题干
给定一个二叉搜索树, 找到该树中两个指定节点的最近公共祖先。
<!--more-->
例如，给定如下二叉搜索树:  root = [6,2,8,0,4,7,9,null,null,3,5]  
[![二叉搜索树示例](binarysearchtree_improved.png)](https://leetcode-cn.com/problems/lowest-common-ancestor-of-a-binary-search-tree/)  
（图片来源[LeetCode-CN](https://leetcode-cn.com/problems/lowest-common-ancestor-of-a-binary-search-tree/)） 

示例 1:  
> 输入: root = [6,2,8,0,4,7,9,null,null,3,5], p = 2, q = 8  
> 输出: 6   
> 解释: 节点 2 和节点 8 的最近公共祖先是 6。  

示例 2:  
> 输入: root = [6,2,8,0,4,7,9,null,null,3,5], p = 2, q = 4  
> 输出: 2  
> 解释: 节点 2 和节点 4 的最近公共祖先是 2, 因为根据定义最近公共祖先节点可以为节点本身。  
 
说明:  
* 所有节点的值都是唯一的。
* p、q 为不同节点且均存在于给定的二叉搜索树中。

# 分析
二叉搜索树（Binary Search Tree，BST）是一种特殊的树，其各个结点满足`node.left.val <= node.val <= node.right.val`。   
根据题目给定的数据结构：
```java
    public class TreeNode {
        int val;
        TreeNode left;
        TreeNode right;
        TreeNode(int x) { val = x; }
    }
```
该BST是单向的（一般的树，没有特殊说明，都只能从上往下遍历）。由于两个要去查找的结点`p`和`q`是等价的，我们不妨令`p.val<q.val`。这样，就存在如下几种情况。   


* 情况一：p或q正好是我们遍历到的结点。   
题目保证结果一定存在、而且不存在重复值的元素，那么当前结点一定就是p和q的最低公共祖先。   
* 情况二：p或q在当前结点的左右两个不同的子树上。   
这种情况下，两个子树的最终交汇位置，已经就是当前结点，所以当前结点就是p和q的最低公共祖先。   
* 情况三：p和q在当前结点的同一棵子树上。
这种情况下，我们需要继续向这个子树的深度方向去遍历。直到找到最低公共祖先为止。   

三种情况如下图所示。   
![三种情况](TreeConditions.png)   
其中Cur为当前遍历到的结点。  

而且，根据BST的性质，我们判断一个目标结点到底是在左子树还是在右子树上，只需要根据结点的值的大小就可以了。如果`target.val < node.val`则target应当出现在node的左子树上；如果`node.val < target.val`，则target应当出现在node的右子树上。  

这样，我们只需要根据上述策略，从根节点向下遍历就可以了。

# 解题
```java
class Solution {
    // public class TreeNode {
    //     int val;
    //     TreeNode left;
    //     TreeNode right;
    //     TreeNode(int x) { val = x; }
    // }
    public TreeNode lowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
        //make p < q
        if(p.val>q.val){
            TreeNode t=p;
            p=q;
            q=t;
        }

        while(true){
            if(p==root || q==root){
                return root;
            }else if(p.val<root.val && root.val<q.val){
                return root;
            }else{
                if(p.val<root.val){
                    root=root.left;
                }else{
                    root=root.right;
                }
            }
        }
    }
}
```
这里，根据题目说明，是一定有解的，所以使用了`while(true)`。如果在真实环境下，当遍历的结点到达叶子结点时，还没有找到的话，就应当结束遍历，并返回未找到的标志。如果未找到的标志为`null`的话，可以改写为：
```java
                if(p.val<root.val){
                    if(root.left!=null)
                        root=root.left;
                    else
                        return null;
                }else{
                    if(root.right!=null)
                        root=root.right;
                    else
                        return null;
                }
```

# 复杂度
这一题的复杂度很好分析。   
空间上，由于没有使用额外空间，所以空间复杂度为$O(1)$。   

时间上，对于最大深度为$h$的BST，其最坏时间复杂度就是$O(h)$，当`p`和`q`位于最深的那个子树上的叶子结点处时。