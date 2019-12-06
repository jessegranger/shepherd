SRC_FILES=$(wildcard src/*.coffee src/*/*.coffee)
JS_FILES=$(subst src/,lib/,$(SRC_FILES:.coffee=.js))
COFFEE=./node_modules/.bin/coffee

all: $(COFFEE) $(JS_FILES)

lib/%.js: src/%.coffee package-lock.json
	# Compiling $<...
	@(o=`dirname $@` && \
		mkdir -p $$o && \
		$(COFFEE) -o $$o -c $<)

$(COFFEE):
	npm install --no-save coffeescript

test: all
	@./test/all.sh

clean:
	rm -rf lib/*

force:
	make -B all

.PHONY: all test clean
