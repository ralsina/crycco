build: src/*.cr languages.yml templates/*.j2
	shards build
release: src/*.cr languages.yml templates/*.j2
	shards build --release
static: src/*.cr languages.yml templates/*.j2
	shards build --release --static
	strip bin/crycco