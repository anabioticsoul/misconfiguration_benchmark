# Nested Nginx location (prefix blocks in regex blocks) not working

# Question

I'm having trouble understanding nested locations in nginx. I have two locations with some configuration directives in common, so rather than repeat the directives, I'd prefer to repeat the URI using a regular-expression:

```
location ~ /a|/b {
        location /a {
        }
        location /b {
        }
}
```

However, this gives the error

```
nginx: [emerg] location "/a" is outside location "/a|/b" in /etc/nginx/nginx.conf:36
```

Without the or `|` it seems okay, though.

```
location ~ /a {
        location /a {
        }
}
```

What am I doing wrong? Is there a better way to do this without repeating anything? Can I group locations in another way?



### Question Comments

=== COMMENTS ===
- (1) pkhamre [Commented Apr 5, 2013 at 7:15]: forum.nginx.org/read.php?2,174517,174534#msg-174534
- (2) Jayen [Commented Apr 6, 2013 at 9:26]: because logically they are grouped
- (3) artfulrobot [Commented May 22, 2018 at 10:16]: This took me a long time to understand but in the end I was able to create a simple(ish) priority list of how locations are chosen .
- (4) cweiske [Commented Jan 5, 2022 at 12:24]: There is a ticket for improving location docs: trac.nginx.org/nginx/ticket/1467
- (5) Ivan Shatsky [Commented Apr 3 at 15:05]: F5 killed off the nginx forum (and badly broke the nginx blog on f5.com ), although the post referred to by pkhamre is still available in the nginx mailing list archives: mailman.nginx.org/pipermail/nginx/2011-February/025204.html


---


# Accepted Answer

Old question, but the issue is because the parent location is a regex location while the nested locations are prefix locations.

When a parent location is defined by a regex, any nested locations must also be defined by regexes:

```
location ~ ^/(a|b) {
        location ~ ^/a {
        ...
        }
        location ~ ^/b {
        ...
        }
}
```

You may only define nested prefix locations when the parent location is also a prefix location:

```
location /a {
        location /a {
               # You can also skip this location and just write
               # your code directly under the parent location
        }
        location /a/b {
        ...
        }
}
```

However, you may define nested regex locations when the parent location is a prefix location:

```
location /a/b {
        location ~ /a {
        ...
        }
        location ~ /b {
        ...
        }
}
```



### Answer Comments

=== COMMENTS ===
- (1) Jayen [Commented Sep 10, 2014 at 1:33]: I got confused by your first sentence, but your examples make sense.  I assume in the last example, the prefix location /b will throw an error?
- (2) AndreKR [Commented Apr 15, 2015 at 7:13]: That first sentence should be in the documentation .
- (3) Meekohi [Commented May 15, 2017 at 20:46]: In the first example, if you leave out the location /a { } boilerplate -- does the order matter?
- (4) Meekohi [Commented May 15, 2017 at 20:52]: Ah nevermind I misunderstood. The nested locations don't inherit anything from their parent locations.
- (5) MitchellK [Commented Jun 26, 2018 at 7:45]: The parent location can be a non regex location but any multiple nested locations within the parent have to all be either regex / non regex.
- (6) Mike Lippert [Commented Aug 7, 2018 at 0:03]: the comment in the 1st example almost answers my question. If I put directives in the top location block are they inherited by all nested location blocks, or do the nested blocks need to repeat or override those directives?
- (7) purefanatic [Commented May 20, 2020 at 15:54]: This does not explain why the asker's second example would work.
- (8) Dayo [Commented Jun 6, 2020 at 17:11]: @purefanatic. It doesn't explain this because the second example will not work. A Prefix Location Block will fail when nested in a Regex Location Block as shown.
- (9) purefanatic [Commented Jun 6, 2020 at 18:12]: @Dayo But you are wrong: The asker's second example works just fine while you claim it shouldn't. It's exactly that: a prefix location block nested in a regex location block, yet it still works. And I don't know why it works, neither does the asker and your answer does not explain it.
- (10) purefanatic [Commented Jun 6, 2020 at 18:14]: And even if the second example of the asker didn't work I feel like an answer should point that out because the whole question presupposes that it does work.
- (11) Dayo [Commented Jun 9, 2020 at 18:54]: @purefanatic. It could be that it does work now but pretty certain that would not have worked when the answer was written. As for your feeling about what should have been pointed out, feel free to add an answer of your own on this.
- (12) Honza [Commented Aug 13, 2021 at 16:48]: @purefanatic, @Dayo: The second example is regex location nested in regex location. location ~ ^/a defines regex, location /a is prefix, although both match same urls.