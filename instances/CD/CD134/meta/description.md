# Is possible to change the default diff tool in Mercurial?

# Question

Every time I do an `hg diff file.ext` I end up using a console diff application. I would like to use Kdiff3 or WinMerge (I'm using Windows).

Is there a way to change that? I can't find a reference in Mercurial documentation (**I'm not talking about merge!**).


---


# Accepted Answer

I've solved this using a Mercurial built-in extension... I just have to add the following lines to Mercurial.ini (on Mercurial folder):

```
[extensions]
hgext.extdiff=

[extdiff]
cmd.vdiff = kdiff3
```

When I want to use kdiff3 instead of diff I only have to use:

```
hg vdiff file.ext
```