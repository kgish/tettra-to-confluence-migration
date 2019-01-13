# Tettra to Confluence Migration

An advanced tool for migrating from Tettra to Confluence.

## Installation

The toolset has been written with the [Ruby programming language](https://www.ruby-lang.org). In order to be able to use it, you will have to have downloaded and installed the following items on your computer:

* [Ruby](https://www.ruby-lang.org/en/downloads)
* [Bundler](http://bundler.io)
* [Git](https://git-scm.com/downloads)

Ensure that you have the correct version of ruby installed and set to using it for scripts.

```
$ rvm install `cat .ruby-version`
$ rvm use `cat .ruby-version`
```

Once this has been done, you can checkout and install the toolset from the github repository.

```
$ git clone https://github.com/kgish/tettra-to-confluence-migration.git tettra-to-confluence
$ cd tettra-to-confluence
$ gem install bundler
$ bundle install
```

## markdown2confluence

Install this gen as follows:

```
$ gem install markdown2confluence
```

## Configuration

```
$ cat .env
DEBUG=true
DATA_DIR=data
CONVERTER=/path/to/markdown2confluence
```

To get the converter path simply execute:

```
$ which markdown2confluence
/home/kiffin/.rvm/gems/ruby-2.6.0/bin/markdown2confluence
```

Now it can be called within this application.

## Markdown to Confluence

```
| Markdown | Confluence |
| -------- | ---------- |
| # H1
| ## H2
| ### H3
| #### H4
| ##### H5
| ###### H6
| Alt-H1
| ======
| Alt-H2
| ------
| *emphasis*
| _emphasis_
| **bold**
| __bold__
| **asterisks and _underscores_**.
| ~~strikethru~~
| [text](url)
|
| Inline-style:
| ![alt text](url "text")
|
| Reference-style:
| ![alt text][logo]
|
| [logo]: url "text"
| `code`
| ```[lang]
| code
| ```
| Blockquotes
| <
| Horizontal rule. 3 or more...
| ---
| ***
| ___
| Lists
| 1. First ordered list item
| 2. Another item
| ⋅⋅* Unordered sub-list.
| 1. Actual numbers don't matter, just that it's a number
| ⋅⋅1. Ordered sub-list
| 4. And another item.
|
| ⋅⋅⋅You can have properly indented paragraphs within list items. Notice the blank line above, and the leading spaces (at least one, but we'll use three here to also align the raw Markdown).
|
| ⋅⋅⋅To have a line break without a paragraph, you will need to use two trailing spaces.⋅⋅
| ⋅⋅⋅Note that this line is separate, but within the same paragraph.⋅⋅
| ⋅⋅⋅(This is contrary to the typical GFM line break behaviour, where trailing spaces are not required.)
|
| * Unordered list can use asterisks
| - Or minuses
| + Or pluses
| Tables

```


## References

* [Markdown Cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)
* [Confluence Markup](https://confluence.atlassian.com/doc/confluence-wiki-markup-251003035.html)
* [Markdown2Confluence](https://github.com/jedi4ever/markdown2confluence)