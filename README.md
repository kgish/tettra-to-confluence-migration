# Tettra to Confluence Migration

An advanced tool for migrating from Tettra to Confluence easily without haven't to think too much.

Feel free to use this on your own, but if you require support do not hesitate to contact me.

Kiffin Gish
kiffin.gish@planet.nl

## Installation

The toolset has been written with the [Ruby programming language](https://www.ruby-lang.org). In order to be able to use it, you will have to have downloaded and installed the following items on your computer:

* [Ruby](https://www.ruby-lang.org/en/downloads)
* [Bundler](http://bundler.io)
* [Git](https://git-scm.com/downloads)
* [Cypress](https://www.cypress.io/)

Ensure that you have the correct version of ruby installed and set to using it for scripts.

```
$ rvm install `cat .ruby-version`
$ rvm use `cat .ruby-version`
```

Once this has been done, you can checkout and install the toolset from the github repository.

```
$ git clone https://github.com/kgish/tettra-to-confluence-migration.git tettra-to-confluence
$ cd tettra-to-confluence
$ bundle install
```

## Configuration

```
$ cat .env.example
# Edit this file and copy it to .env

# General
DEBUG=true
DATA=data
IMAGES=images
CONVERTER=/path/to/markdown2confluence
EXT=confluence

# Tettra
TETTRA_HOST=https://app.tettra.co
TETTRA_COMPANY=company
TETTRA_EMAIL=user.name@example.org
TETTRA_PASSWORD=secret
TETTRA_LOGFILE=crawler/crawler.log

# Confluence
CONFLUENCE_API=https://company.atlassian.net/wiki/rest/api
CONFLUENCE_SPACE=Tettra
CONFLUENCE_EMAIL=user.name@example.org
CONFLUENCE_PASSWORD=secret
```

## Cypress

I use Cypress for scraping the Tettra website, so ensure that it is installed correctly.

First install the required dependencies:

```
$sudo apt-get install xvfb libgtk2.0-0 libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2
```

Then you can install the package:

```
$ cd crawler
$ npm install
```

In order to configure, copy  `cypress.json.example` to `cypress.json` and make the necessary changes.

```
$ cat cypress.json
{
  "env": {
    "EMAIL": "john.doe@example.org",
    "PASSWORD": "secret",
    "TETTRA": "https://app.tettra.co",
    "SPACE": "company",
    "LOGFILE": "crawler.log"
  }
}
```

Running cypress is simple:

```
$ yarn cypress:run
```

## References

* [Confluence Cloud REST API](https://developer.atlassian.com/cloud/confluence/rest)

## Author

Kiffin Gish

