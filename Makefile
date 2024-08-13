build: $(wildcard src/**/*.cr) src/languages.yml $(wildcard templates/*.j2)
	shards build -Dstrict_multi_assign -Dno_number_autocast
release: $(wildcard src/**/*.cr) src/languages.yml $(wildcard templates/*.j2)
	shards build --release
static: $(wildcard src/**/*.cr) src/languages.yml $(wildcard templates/*.j2)
	shards build --release --static
	strip bin/crycco

.PHONY: build release static