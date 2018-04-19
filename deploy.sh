#!/bin/bash
hugo
rsync -avuz public/ elba.informatik.uni-freiburg.de:/var/www/ad-blog/
