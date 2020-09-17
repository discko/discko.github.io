---
title: LC-0236-二叉树的最近公共祖先
tags:
  - LeetCode
  - Tree
categories: LeetCode
mathjax: true
date: 2020-09-17 11:24:08
---


# 题干
给定一个二叉树, 找到该树中两个指定节点的最近公共祖先。
<!--more-->
例如，给定如下二叉树:  root = [3,5,1,6,2,0,8,null,null,7,4]  
[![二叉树示例](binarytree.png)](https://leetcode-cn.com/problems/lowest-common-ancestor-of-a-binary-tree/)  
（图片来源[LeetCode-CN](https://leetcode-cn.com/problems/lowest-common-ancestor-of-a-binary-tree/)） 


 

示例 1:  
> 输入: root = [3,5,1,6,2,0,8,null,null,7,4], p = 5, q = 1  
> 输出: 3  
> 解释: 节点 5 和节点 1 的最近公共祖先是节点 3。  

示例 2:  
> 输入: root = [3,5,1,6,2,0,8,null,null,7,4], p = 5, q = 4  
> 输出: 5  
> 解释: 节点 5 和节点 4 的最近公共祖先是节点 5。因为根据定义最近公共祖先节点可以为节点本身。  
 

说明:  
* 所有节点的值都是唯一的。  
* p、q 为不同节点且均存在于给定的二叉树中。  

# 分析
此题与上一题[LC-0235-二叉搜索树的最近公共祖先](2020/09/17/LC-0235-LowestCommonAncestorOfABinarySearchTree/) 比较相似。区别在于，对二叉树的限制（原本为二叉搜索树BST，现在为一棵普通二叉树）。但我们分析的思路还是一致的。  
根据上一题的分析经验，同样有这样三种情况：
* 情况一：p或q正好是我们遍历到的结点。   
题目保证结果一定存在、而且不存在重复值的元素，那么当前结点一定就是p和q的最低公共祖先。   
* 情况二：p或q在当前结点的左右两个不同的子树上。   
这种情况下，两个子树的最终交汇位置，已经就是当前结点，所以当前结点就是p和q的最低公共祖先。   
* 情况三：p和q在当前结点的同一棵子树上。
这种情况下，我们需要继续向这个子树的深度方向去遍历。直到找到最低公共祖先为止。 

但不同的时，此时我们无法利用BST结点值有序的性质去快速判断目标结点位于左子树还是右子树。因此我们只能进行尝试与回溯，也就是深度优先搜索(Deep First Search，DFS)。

当遍历到某一个结点`node`时，如果左右子树中都不存在`p`或`q`，则这个结点一定不是`p`和`q`的祖先；如果如果该结点就是`p`或`q`，则这个结点

# 解题
```java
class Solution {
    public class TreeNode {
        int val;
        TreeNode left;
        TreeNode right;
        TreeNode(int x) { val = x; }
    }
    public TreeNode lowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
        //if current node is exactly p or q,
        //the current node must be the common ancestor
        if(root==p || root==q){
            return root;
        }
        //if current node is null
        //it reaches the leaf
        if(root==null){
            return null;
        }
        //try left child tree and right child tree
        TreeNode left=lowestCommonAncestor(root.left, p, q);
        TreeNode right=lowestCommonAncestor(root.right, p, q);

        if(left!=null && right!=null){
            //p and q are at both side of current node
            return root;
        }else if(left != null && right == null){
            //p and q are in left child tree
            return left;
        }else if(left == null && right != null){
            //p and q are in right child tree
            return right;
        }
        //left==null && right==null
        //it means cannot find the common ancestor
        return null;
    }
}
```

# 复杂度
这一题的复杂度很经典，就是DFS的复杂度。对于元素数量为$n$高度为$h$的二叉树：   

时间复杂度为$O(n)$，空间复杂度也就是递归的深度最坏时就是树的最大深度$O(h)$。