# Create snippets in VSCode, and bind keyboard shortcuts

## Create new user snippets

**Ctrl+Shift+P** > **Snippets: Configure User Snippets** > **New Global Snippets File** > Input file name (`footnote` in this example).

This would auto create a file named `footnote.code-snippets`:

Then input the following code:

```json
{
	"footnote": {
		"scope": "markdown",
		"prefix": "footnote",
		"body": [
			"<f>$TM_SELECTED_TEXT$0</f>"
		],
		"description": "Insert footnote tag (<f>) in markdown"
	}
}
```

- `scope`: language scope where current snippet is available
- `prefix`: the prefix of typing text to trigger the snippet
- `$TM_SELECTED_TEXT`: placeholder of **selected text**.
- `$0`: placeholder of **cursor position** after snippet inserted.


## Bind keys to this snippet

**Ctrl+Shift+P** > **Preferences: Open Keyboard Shortcuts(JSON)**.

This would would open `keybindings.json`.

Then add the following code:

```json
{
    "key": "alt+f",
    "command": "editor.action.insertSnippet",
    "when": "editorTextFocus",
    "args": {
        "langId": "markdown",
        "name": "footnote"
    }
}
```