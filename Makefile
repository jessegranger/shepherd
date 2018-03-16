JS_FILES=$(shell find src -name \*.coffee | sed -e 's/src/lib/' -e 's/\.coffee/.js/')

all: $(JS_FILES)

lib/%.js: src/%.coffee
	# Compiling $<...
	@(o=`dirname $< | sed -e 's/src/lib/'` && \
		mkdir -p $$o && \
		coffee -o $$o -c $<)

test: all
	./test/all.sh

clean:
	rm -rf lib/*

.PHONY: all test clean
