#!/bin/sh -x
set -e
ameba --fix
shards build
bin/crycco languages.yml src/*.cr TODO.md
rsync -rav docs/* ralsina@pinky:/data/websites/crycco.ralsina.me/
