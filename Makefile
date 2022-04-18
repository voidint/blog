build:
	hugo -D

run:
	hugo server -D

publish: build
	cp -a ./public/* ../voidint.github.io

.PHONY: build run publish
