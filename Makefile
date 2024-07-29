build: src/*.cr src/languages.yml templates/*.j2
	shards build -Dstrict_multi_assign -Dno_number_autocast
release: src/*.cr src/languages.yml templates/*.j2
	shards build --release
static: src/*.cr src/languages.yml templates/*.j2
	shards build --release --static
	strip bin/crycco
