#!/bin/sh -x

set -e

rsync -rav docs/* ralsina@pinky:/data/websites/crycco.ralsina.me/
