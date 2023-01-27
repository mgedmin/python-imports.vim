.PHONY: test
test: vader.vim
	test/run

vader.vim:
	git clone --depth=1 https://github.com/junegunn/vader.vim
