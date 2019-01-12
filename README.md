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