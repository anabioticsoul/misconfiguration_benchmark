# Inno Setup parameter with quotes in [Run] section

# Question

I use `[Run]` section to modify the merit value of some codecs with `commandmerit.exe` that supports command-line.

So the syntax is:

```
Commandmerit.exe "{E2B7DF46-38C5-11D5-91F6-00104BDB8FF9}" "0x800000"
```

`{E2B7DF46-38C5-11D5-91F6-00104BDB8FF9}` is the CLSID of the codec and
`0x800000` is the value of the new merit, but when I put this line in `[Run]` section :

```
Filename: "{app}\Commandmerit.exe"; \
    Parameters: ""{F8FC6C1F-DE81-41A8-90FF-0316FDD439FD}" "0x10000000""; \
    WorkingDir: "{app}"
```

The following error is displayed:

> Mismatched or misplaced quotes on parameter.

---

If I put this line:

```
Filename: "{app}\Commandmerit.exe"; \
    Parameters: """{F8FC6C1F-DE81-41A8-90FF-0316FDD439FD}" "0x10000000"""; \
    WorkingDir: "{app}"
```

The following error is displayed:

> Unknown constant ...... use two consecutive"{" if .....

---

If I put this line:

```
Filename: "{app}\Commandmerit.exe"; \
    Parameters: """{{F8FC6C1F-DE81-41A8-90FF-0316FDD439FD}}" "0x10000000"""; \
    WorkingDir: "{app}"
```

Then no error is displayed but it seems that the `commandmerite.exe` don't understand the parameter, so after the installer finishes the merit still unchanged.


---


# Accepted Answer

To add quotes to a parameter, you must double up each quote, and then put quotes around the entire value.

Your second attempt was close but you forgot the middle ones.

```
Filename: "{app}\Commandmerit.exe"; \
    Parameters: """{F8FC6C1F-DE81-41A8-90FF-0316FDD439FD}"" ""0x10000000"""; \
    WorkingDir: "{app}"
```



### Answer Comments

=== COMMENTS ===
- (1) jachguate [2013-04-05T21:59:15+00:00]: Well that was my second guess... +1 for you, Deanna ;)