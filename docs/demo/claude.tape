# Records docs/demo-claude.gif. Run through docs/demo/record-claude.sh, which
# prepares the files this tape reads from $DEMO_RC and $DEMO_APP.
Output docs/demo-claude.gif

Set Shell bash
Set FontFamily "Menlo"
Set FontSize 18
Set Width 1200
Set Height 720
Set Padding 24
Set TypingSpeed 60ms
Set Theme { "background": "#2B2B2B", "foreground": "#FFFFFF", "cursor": "#FFFFFF", "green": "#9FE6A0", "red": "#FF8A80", "black": "#2B2B2B", "brightBlack": "#6B6B6B" }

Hide
# The recorded shell loads the demo rc file, which runs `oops init bash`.
Type 'oops record -- bash --rcfile "$DEMO_RC"' Enter
Sleep 2.5s
Type 'cd "$DEMO_APP" && clear' Enter
Sleep 1s
Show

Type "ruby test_user.rb --seed 7" Sleep 500ms Enter
Sleep 3s
Type "claude" Sleep 500ms Enter
Sleep 6s
Type "why did the test fail?" Sleep 700ms Enter
Sleep 20s
