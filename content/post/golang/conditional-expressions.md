---
title: "Go 三目运算符杂谈"
date: 2022-01-09T16:10:10+08:00
tags: [golang,泛型]
categories: ["Golang"]
draft: true
---

Go 是一门十分精简的语言。对于每一个引入的语言特性，Go 核心团队都慎之又慎，有时候甚至让人觉得有点死脑筋。

Go 语言深得我心，但并不意味着她没有缺点，也不意味着她没有改进空间。除了泛型（即将支持）外，我还寄希望于 Go 核心团队引入三目运算符（或者叫`三目表达式`、`条件表达式`）和 const 不可变对象等特性。虽然，Go 核心团队之前都已经否认会引入此类特性，但谁又能保证这些特性不会是第二第三个泛型呢。这次我想聊聊三目运算符这个特性相关的话题。

# 什么是三目运算符？
`什么是三目运算符`这种问题对于编程老手来说简直是侮辱智商的问题，但为了篇幅的完整性，还是得要提一下。

首先，看一下不支持三目表达式特性的 Go 语言的写法
```go
var genderDesc string
if gender == 1{
    genderDesc = "男"
} else {
    genderDesc = "女"
}
fmt.Println(genderDesc)
```

再看一下支持三木表达式特性的 C++ 语言的写法

```c++
std::string genderDesc = (gender == 1 ? "男" : "女");
std::cout << genderDesc << std::endl;
```

没错，这个`?:`就是三目运算符的典型语法。

# Go为什么不支持三目运算符？
支持三目运算符的编程语言有很多，C/C++、C#、Java、JavaScript、Python、Ruby等。但 Go 为什么不支持这个主流语言普遍都支持的特性呢？从 Go 语言的 FAQ 中可以略知一二。

> The reason ?: is absent from Go is that the language's designers had seen the operation used too often to create impenetrably complex expressions. The if-else form, although longer, is unquestionably clearer. A language needs only one conditional control flow construct.

Go 核心团队认为，程序员常常会利用三目运算符构建及其复杂的表达式，而这么复杂的表达式一定都可以通过拆解成一个或者多个 if 语句来实现，并且 if 语句的可读性更好。顺便猜测一下，因为 Go 核心团队成员都是拥有多年经验的 C/C++ 大师，对于 C++ 那不断膨胀的语言特性一定也是心有余悸。他们不想让 Go 走上 C++ 的老路，不想在 Go 语言中出现**做同一件事却有10种炫技式的不同写法**的现象，他们希望在 Go 中有且只有一种写法。

对于官方给出的这么官方的回答，肯定有人同意，也有人会反对。显然我属于后者，否则也不会有这篇吐槽文章。至于原因，请继续往下看。

# 三目运算符有哪些常见的使用场景？
同一个语言特性，不同的人会有不同的使用方式。我无法穷举三目运算符的所有使用方式，下面我按照**是否嵌套**的的三目运算符划分了两个常见的场景。

- 场景一：无三目运算符嵌套

```C++
#include <iostream>

struct Person {
    unsigned char gender;
};

int main() {
    Person p;
    std::cout << (p.gender == 1 ? "男" : "女") << std::endl;
}
```
可见，在没有三目运算符嵌套的情况下，并不会对代码可读性产生任何影响。当然，我也见过极个别网友说这种代码的可读性也不高。对于这种例外，我只能建议其去看眼科了。


- 场景二：三目运算符嵌套

```C++
#include <iostream>

struct Person {
    unsigned char gender;
};

int main() {
    Person *p = new Person;
    p->gender = 1;
    std::cout << (p == nullptr ? "未知" : (p->gender == 1 ? "男" : "女")) << std::endl;
    delete p;
}
```

对于三目运算符嵌套的场景，最常见的也是示例中的两层嵌套，多于两层的嵌套就会对代码可读性产生较大影响。但我认为，这不能成为否定三目运算符积极意义的理由，if 的多层嵌套同样会影响代码可读性。下面再看一下没有三目运算符特性的 Go 语言的写法。

```go
package main

import "fmt"

type Person struct {
	gender uint8
}

func main() {
	var genderDesc string

	p := new(Person)
	if p == nil {
		genderDesc = "未知"
	} else {
		if p.gender == 1 {
			genderDesc = "男"
		} else {
			genderDesc = "女"
		}
	}

	fmt.Println(genderDesc)
}
```

在某种程度上说，`代码可读性`也是一件挺主观的事。主观，则意味着没有绝对的对错。也许有人会觉得上面 Go 代码清晰明了，容易理解。还有人可能认为，使用三目运算符的 C++ 代码更加简洁。对于纯主观的问题，多说无益，千金难买我愿意，爱喜欢哪个就喜欢哪个。那么，就来说说相对客观点的事实。

- 三目运算符的实现更加简短，代码更少。
这个从代码行数上可以直观看到，也无需赘言。

- 三目运算符可以减少非必要的中间变量的定义。
这里强调的是由程序员定义的变量，而非编译器产生的临时变量。很明显，上面的 C++ 代码中无需定义`genderDesc`这个变量。有人说**命名**和**缓存失效**是计算机科学中最困难的两件事，我觉得有一定道理。好的变量命名要做到见名知意，这并不是一件容易的事，特别是对于我这样有代码洁癖的人。

# 如何造一个三目运算符的轮子？
既然 Go 不支持三目运算符，而我又需要它，那只能尝试去造一个这样的轮子。我会使用三种方式来造这个轮子，代码也没几行，实现起来也不难，那为什么还要官方作为语言特性提供呢？那些认为三目运算符没必要的人可能也会拿这个当作理由。看完下面再来评价这个轮子好不好。

- 版本一：为每种基本数据类型添加一个类似三目运算符的条件表达式函数

```go
package condexpr

// Str string类型的条件表达式函数
func Str(expr bool, a, b string) string {
	if expr {
		return a
	}
	return b
}

// Int int类型的条件表达式函数
func Int(expr bool, a, b int) int {
	if expr {
		return a
	}
	return b
}

// Float64 float64类型的条件表达式函数
func Float64(expr bool, a, b float64) float64 {
	if expr {
		return a
	}
	return b
}
```

通过`genderDesc := condexpr.Str(p.gender == 1, "男", "女")`方式进行仿三目运算符的调用。缺点是需要为每种数据类型都定义一个专门的函数。

- 版本二：定义一个`interface{}`类型的万能条件表达式函数

```go
package condexpr

// Interface interface{}类型的条件表达式函数
func Interface(expr bool, a, b interface{}) interface{} {
	if expr {
		return a
	}
	return b
}
```

通过`genderDesc := condexpr.Interface(p.gender == 1, "男", "女").(string)`方式进行仿三目运算符的调用。缺点是返回了万能类型`interface{}`，每次使用都需要断言，不方便性能还差。

- 版本三：使用泛型特性定义一个万能条件表达式函数

```go
package condexpr

// Any 若expr成立，则返回a；否则返回b。
func Any[T any](expr bool, a, b T) T {
	if expr {
		return a
	}
	return b
}
```

通过`genderDesc := condexpr.Any(p.gender == 1, "男", "女")`方式进行仿三目运算符的调用。这个版本克服了以上两个版本的缺点，看似还比较完美。事实真的是这样吗？来看看下面的例子。

```go
var p *Person
genderDesc := Any(p == nil, "未知", Any(p.gender == 1, "男", "女")) // panic
fmt.Println(genderDesc)
```

以上示例将无可避免地发生 panic ，原因是当`p == nil`成立时，`p.gender`将发生 panic 。相信肯定会有人觉得奇怪，明明在访问 gender 字段前已经做了判空操作，怎么还会 panic？实际上，这就是函数怎么也无法代替三目运算符语言特性的地方：**作为语言特性的三目运算符可以做到惰性计算，而函数做不到。**

函数 Any 有3个参数，函数在压栈前必须对它的实参先进行计算并获得相应的值，也就是说，`p == nil`和`p.gender == 1`都会被求值，两者没有逻辑上的关系。

# 总结
我个人极为期待三目运算符这个语言特性，因为它能让代码更加简洁，它能减少非必要变量的定义，降低程序员在命名方面的负担。虽然，可以人为地通过函数方式模拟三目运算符，但这种方式依然做不到语言特性级别的惰性计算，无法真正取代三目运算符。

# 参考
- [Why does Go not have the ?: operator?](https://go.dev/doc/faq#Does_Go_have_a_ternary_form)




