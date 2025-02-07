# sml-repl-mode

A minor mode for inline evaluation and REPL integration for Standard ML in Emacs.

## Overview

`sml-repl-mode` provides a lightweight REPL for Standard ML along with
inline evaluation functionality, similar to what is available in Emacs
for languages like Elisp and Clojure. The package allows evaluating
SML expressions and displaying results directly within the buffer
using overlays.

## Features

- Inline evaluation of expressions with results displayed in the buffer.
- Seamless integration with an external Standard ML REPL.
- Font-locking for inline evaluation results.
- Support for evaluating regions, lines, buffers, and files.

## Installation

Clone or download the repository and add the following to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/sml-repl-mode")
(require 'sml-repl)
```

## Usage

Enable `sml-repl-mode` in your Standard ML source buffer:

```elisp
(sml-repl-mode 1)
```

### Keybindings

| Keybinding  | Description                                 |
| ----------  | ---------------------------- |
| `C-c C-e`    | Evaluate the current region. |
| `C-c C-l`    | Evaluate the current line.    |
| `C-c C-b`    | Evaluate the entire buffer.  |
| `C-c C-f`    | Evaluate a selected file.      |

## Configuration

Several customization options are available via `M-x customize-group sml-repl`:

- `sml-repl-show-repl-on-start` (default: `t`): Whether to show the REPL when it starts.
- `sml-repl-buffer-name` (default: `*SML-REPL*`): Name of the REPL buffer.
- `sml-repl-font-lock` (default: `t`): Enable font-lock in the REPL.
- `sml-repl-overlay-font-lock` (default: `t`): Apply font-lock to inline evaluation results.
- `sml-repl-prompt-regexp` (default: `"^- "`): Regular expression for detecting the SML REPL prompt.

## Example

To start the REPL manually:

```elisp
M-x sml-repl-run
```

To evaluate a piece of code inline, select a region and press `C-c C-e`. The result will be displayed directly in the buffer.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.html) for details.

## Author

Henrik Kjerringvåg [henrik@kjerringvag.no](mailto\:henrik@kjerringvag.no)
