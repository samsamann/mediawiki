# Dockerized Mediawiki

## What is MediaWiki?
> MediaWiki is a free software open source wiki package written in PHP, originally for use on Wikipedia.
> It is now also used by several other projects of the non-profit Wikimedia Foundation and by many other wikis.
> [MediaWiki](https://www.mediawiki.org/wiki/MediaWiki)

## How to use this image
`docker run -d --name some-container-name --link some-db-name:mysql -e WIKI_SITE_NAME=MyWiki samsamann/mediawiki`

This command runs a MediaWiki container called *some-container-name* with the site name *MyWiki*.

### Additional configurations
**db connection configurations:**
- `-e WIKI_DB_NAME=...` (defaults to *wiki*)
- `-e WIKI_DB_USER=...` (defaults to *root*)
- `-e WIKI_DB_PW=...` (defaults to the value of the linked mysql container)

**network configurations:**
- `-e WIKI_DNS_NAME=...` (defaults to *localhost*. If you want expose your wiki, then set the FQN. example:`wiki.example.org`)
- `-e WIKI_EXTRA_EXPOSED_PORT=...` (If you'd like to be able to access the instance from another port, you must use standard port mapping and `WIKI_EXTRA_EXPOSED_PORT` together.)

`docker run -d --name some-container-name --link some-db-name:mysql -p 8080:80 -e WIKI_EXTRA_EXPOSED_PORT=8080 -e WIKI_SITE_NAME=MyWiki samsamann/mediawiki`

**other configurations:**
- `-e WIKI_SKIP_DB=true` if you want recreate the instance but retain site content, then set this env variable.
