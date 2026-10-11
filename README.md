# hbina.github.io

Personal site for Hanif Bin Ariffin, built with [Hugo](https://gohugo.io/) and hosted on GitHub Pages.

The site is a minimal blog — a plain list of articles on the home page, each rendered as a single HTML page with no external dependencies or frameworks.

## Running locally

```
hugo serve -DF
```

Open `http://localhost:1313` in your browser.

## Building a single HTML file

Run:

```sh
hugo --config config.toml,config.single.toml --destination single-file
```

Open `single-file/index.html` directly in your browser. It includes all published
articles, inline styling, anchor navigation, and the linked althttpd source download.
External links still require internet access. The normal Hugo build is unchanged.

To include drafts and future-dated posts, add `-DF` to the command.
