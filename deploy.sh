#!/bin/sh -x
set -e
ameba --fix
make
bin/crycco src/languages.yml src/*.cr --theme monokai
rsync -rav docs/* ralsina@pinky:/data/websites/crycco.ralsina.me/
