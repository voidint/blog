---
title: "git commit message后悔药"
date: 2020-02-25 16:33:19
tags: [git]
categories: ["工具箱"]
draft: true
---


![题图](https://voidint.github.io/tool/git.jpg)

# 场景描述
假设你创建了一个文件，并写入了一些内容，然后通过git add和git commit将此变更提交。提交之后才发现这个文件中少了一些内容，此时有两个选择摆在你面前：

- 将文件内容补全，然后和之前一样git add、git commit。显然，你可以通过git log看到这两条commit记录。
- 回到过去，修改上一次提交的那个文件。如此一来，你的commit记录只会有一条。对于一些有代码洁癖并且看中git commit记录的程序员，这点很重要，特别是在开源项目中。

# 场景再现
初始化git仓库

```shell
$ mkdir test && cd test && git init
```

第一次commit内容

```shell
$ echo 'Hello world' > README.md
$ git add .
$ git commit -m "Add README.md"
$ git log --oneline
c56f680 Add README.md
```

修改文件内容并合并到上一次的commit变更当中

```shell
$ echo 'Hello voidint' >> README.md
$ git add .
$ git commit --amend --no-edit
$ git log --oneline
eb6c8cb Add README.md // hash值发生了变化
```

可以看到，在执行git commit --amend --no-edit之后，hash值由c56f680变成了eb6c8cb，但是message内容并没有发生变化，并且最重要的是只有一条commit记录。

如果要修改上一条的message，那么去掉--no-edit选项即可，git commit --amend -m "xxxx"。同理，commit记录同样只会有一条。