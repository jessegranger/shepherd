SRC_FILES=$(subst src/,lib/,$(wildcard src/*/*.coffee))
JS_FILES=$(SRC_FILES:.coffee=.js)

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

.PHONY: all test clean
