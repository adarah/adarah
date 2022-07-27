---
title: First post
date: '2022-07-27'
---
It took me about a day to get this blog up and running, but it's finally working! Yeah, it's still a little ugly but it's a working MVP, which is more than I could say about a lot of my abandoned side projects.

![Screenshot of the homepage as of 2022-07-27](/01-first-post/homepage.png)
*Could use some work, but I'll get to that eventually.*

```zig
var q: []const u8 = "Why start a blog?";
```

Why not? ;)
In all seriousness, I don't use Twitter or any traditional social media, and writing posts is a good creative outlet.
Often times I would find myself making mini write-ups in the Discord servers to random strangers, and I figured that I might as well
put them in a more permanent and easily accessible location. Now that I've officially graduated, I have more free time to focus on my own
projects instead of toiling away into some random subject I don't care about. Yay!

```zig
q = "Why not use one of the many ready-made blogging platforms?";
```  

Well you see, the problem with those platforms is that they work incredibly well, which allows users to focus exclusively on producing good content, and I'm not a particularly good writer.
By building my own blog, I can create an infinite number of meaningless tasks to distract myself from having to write new posts!

```zig
q = "Okay... What technologies did you use to build this blog?";
```

I'm glad you asked my dear reader! Such a convenient question to segway into what I wanted to talk about in the first place!

I built this blog using [Sveltekit](https://kit.svelte.dev/) since it seemed pretty simple to use, and I'm happy with the results so far.
Since I'm using [adapter-static](https://github.com/sveltejs/kit/tree/master/packages/adapter-static), all my pages get compiled to mostly HTML and CSS. The site still
works with Javascript disabled!
And thanks to [mdsvex](https://mdsvex.com/), I can simply use markdown files to auto-generate these posts with a layout of my choosing.
Many of you may be rolling your eyes thinking "Yeah it's called JAMstack and we've been doing this for nearly a decade at this point". First of all, wow time flies! 
Second of all, the fact that Svelte has a big enough ecosystem to make it this easy to build this blog is impressive in and of itself, especially considering how recently it hit the "mainstream".

![Usage of frontend frameworks from State of JS 2021](/01-first-post/usage.png)
*Take the specific numbers with a grain of salt, as with many other surveys, [self-selection bias](https://en.wikipedia.org/wiki/Self-selection_bias) is a thing. It's still useful to see trends though!*

As for hosting, I'm using [Cloudflare Pages](https://pages.cloudflare.com/). I haven't had any issues so far, and I've even used some of their offerings such as [R2](https://www.cloudflare.com/products/r2/) and [Workers](https://workers.cloudflare.com/) in some of my other projects, which I will eventually write about in future posts. 

All in all, I'm content with what I've built so far, so I'll wrap things up here. If you want to check out the code, the source can be found [here](https://github.com/adarah/adarah).
My next posts will probably be about my current learnings about openGL, which I've
been exploring to build my NES emulator on [Zig](https://ziglang.org/). Tune in later to see the results! (I should figure out how to add an RSS button here...)