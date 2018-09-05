SRC_FILES=$(wildcard src/*.coffee src/*/*.coffee)
JS_FILES=$(subst src/,lib/,$(SRC_FILES:.coffee=.js))

all: $(JS_FILES)

lib/%.js: src/%.coffee
	# Compiling $<...
	@(o=`dirname $@` && \
		mkdir -p $$o && \
		coffee -o $$o -c $<)

test: all
	@./test/all.sh

clean:
	rm -rf lib/*

force:
	make -B all

.PHONY: all test clean
