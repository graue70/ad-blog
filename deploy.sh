#!/bin/bash
if [[ -f "./hugo" ]]; then
	./hugo
else
	hugo
fi

chmod -R ug+rwX public/
rsync -avuz public/ ad-blog.informatik.uni-freiburg.de:/var/www/ad-blog/
