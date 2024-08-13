#!/bin/sh -x
set -e
ameba --fix || true
make
bin/crycco src/languages.yml src/*.cr --theme phd 
rsync -rav docs/* ralsina@pinky:/data/websites/crycco.ralsina.me/
