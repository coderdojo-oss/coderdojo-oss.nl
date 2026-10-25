# coderdojo-oss.nl

Website of [CoderDojo Oss](https://coderdojo-oss.nl), built with [Hugo](https://gohugo.io).

## Origin

This site started as a fork of the [CoderDojo Helmond website](https://github.com/Coderdojo-Helmond/coderdojohelmond.nl-hugo),
made by Stan van de Wiel ([@stan754](https://github.com/stan754)) and the CoderDojo Helmond volunteers,
and was forked in agreement with Stan. The theme in
`themes/CoderDojo-Helmond-Theme` and most of the layout come from their work. Thanks!

## Running locally

```sh
hugo server --buildFuture
```

`--buildFuture` is needed so upcoming editions show up, just like in the deploy.

## Editions

Each edition is a page in `content/edities/YY-MM-DD.md`. They are imported from
our [Eventbrite organizer page](https://www.eventbrite.nl/o/infocoderdojo-ossnl-9037398032):

```sh
tools/importEventbrite.sh
```

It imports past and upcoming editions. Existing pages are skipped, except upcoming ones
("vindt plaats"), which are regenerated until their date has passed. So the script can be run
again whenever a new edition is published.

## Deploy

Every push to `main` is built and deployed to GitHub Pages by `.github/workflows/hugo.yaml`.
