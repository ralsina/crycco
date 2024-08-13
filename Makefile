all: build

build: $(wildcard src/**/*.cr) src/languages.yml $(wildcard templates/*.j2)
	shards build -Dstrict_multi_assign -Dno_number_autocast
release: $(wildcard src/**/*.cr) src/languages.yml $(wildcard templates/*.j2)
	shards build --release
static: $(wildcard src/**/*.cr) src/languages.yml $(wildcard templates/*.j2)
	shards build --release --static
	strip bin/crycco

clean:
	rm -rf bin lib shard.lock

test:
	crystal spec

lint:
	ameba --fix src spec

.PHONY: clean all test bin lint static
