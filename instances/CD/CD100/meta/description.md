# How to set Python language specific tab spacing in Visual Studio Code?

## Question

Using VSCode 1.9.0 with the (donjayamanne) Python 0.5.8 extension, **is it possible to provide Python specific editor options?**

Or more generally speaking, is it possible to provide language specific tab spacing and replacement rules? For example, Python should be tab=4 spaces (replaced as spaces), and Ruby should be tab=2 spaces (replaced). Other languages tend to have their own opinions. However, I only see the general

```json
"editor.tabSize": 4,
"editor.insertSpaces": true
```

options.

I thought perhaps there was a `"python.editor": { }` block or perhaps a `"python.editor.tabSize"` option, but I can't find reference to such, nor have I successfully guessed a working name.

### Question Comments

- (1) JinSnow [2018-10-26T13:40:07+00:00]: How do I auto-indent Python code in Visual Studio Code? stackoverflow.com/questions/35531080/…
- (2) Manohar Reddy Poreddy [2023-09-21T16:30:56+00:00]: This fixed issue - stackoverflow.com/questions/57750880/…

## Accepted Answer

I had the same problem today.  
This is how I fixed it. Add this lines in setting.json in VSCode:

```json
"[python]": {
  "editor.insertSpaces": true,
  "editor.tabSize": 4
}
```

It works like a charm.

### Answer Comments

- (1) MagTun [2019-10-23T16:37:54+00:00]: It also works for the other files format: [javascript], [html], [json], [tsv] ....
- (2) zwcloud [2021-04-29T05:37:54+00:00]: code.visualstudio.com/docs/getstarted/…
- (3) michael_teter [2021-05-16T13:42:32+00:00]: As Oliver explains in his answer, it may be helpful to include `"editor.detectIndentation" : false` in the [python] block. See his answer for details.
- (4) jstm [2021-05-19T21:37:07+00:00]: Note: I had to restart vscode in order for the change to take effect.
- (5) ai2ys [2021-11-23T14:50:09+00:00]: I added two of the above mentioned configurations, one for Python (spaces) and one for C (tabs), but unfortunately, the editor keeps the previous set setting and does not use the language specific one. Do I have to set an additional setting?
- (6) risa_risa [2022-01-14T20:50:09+00:00]: I had to turn Editor: Detect Indentation settings to False for my settings.json to work.
