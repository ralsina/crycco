build: src/*.cr languages.yml templates/*.j2
	shards build -Dstrict_multi_assign -Dno_number_autocast
release: src/*.cr languages.yml templates/*.j2
	shards build --release
static: src/*.cr languages.yml templates/*.j2
	shards build --release --static
	strip bin/crycco
