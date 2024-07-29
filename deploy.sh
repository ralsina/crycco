#!/bin/sh -x
set -e
ameba --fix
make
bin/crycco src/languages.yml src/*.cr 
rsync -rav docs/* ralsina@pinky:/data/websites/crycco.ralsina.me/
