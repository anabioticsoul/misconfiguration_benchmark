# Turning off auto indent when pasting text into vim

# Question

I am making the effort to learn Vim.

When I paste code into my document from the clipboard, I get extra spaces at the start of each new line:

```
line
  line
    line
```

I know you can turn off auto indent but I can't get it to work because I have some other settings conflicting or something (which look pretty obvious in my .vimrc but don't seem to matter when I take them out).

How do I turn off auto indenting when I paste code but still have vim auto indent when I am writing code? Here is my `.vimrc` file:

```
set expandtab  
set tabstop=2  
set shiftwidth=2  
set autoindent  
set smartindent  
set bg=dark  
set nowrap
```



### Question Comments

=== COMMENTS ===
- (1) sh1 [Commented Nov 9, 2017 at 17:12]: FWIW, vim 8.0.210 adds native support for bracketed paste, so it will avoid indenting pasted text.
- (2) unknown: 
- (3) ccpizza [Commented Oct 6, 2019 at 19:22]: For new files in order to avoid fiddling with vim's paste/nopaste you can do cat > mynewfile.txt press Enter , paste your text, press Enter again, and then Ctr+D to save. The file is now created and you can edit it with vim mynewfile.txt .
- (4) Sloomy [Commented Jul 11, 2022 at 19:58]: the cat solution has one disadvantage : variables are changed to the value of that variable
- (5) John Scott Stensland [Commented Aug 25, 2022 at 16:00]: several years ago this was never an issue ... seems the default behavior has changed as I always use very minimal vim customizations
- (6) unknown: 


---


# Accepted Answer

**Update:** Better answer here: <https://stackoverflow.com/a/38258720/62202>

To turn off autoindent when you paste code, there's a special "paste" mode.

Type

```
:set paste
```

Then paste your code. Note that the text in the tooltip now says `-- INSERT (paste) --`.

After you pasted your code, turn off the paste-mode, so that auto-indenting when you type works correctly again.

```
:set nopaste
```

However, I always found that cumbersome. That's why I map `<F3>` such that it can switch between paste and nopaste modes *while editing the text!* I add this to `.vimrc`

```
set pastetoggle=<F3>
```