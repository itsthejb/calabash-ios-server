all:
	$(MAKE) framework
	$(MAKE) frank
	$(MAKE) dylibs

clean:
	rm -rf build
	rm -rf calabash.*framework
	rm -rf libFrankCalabash.a
	rm -rf calabash-dylibs

framework: #clean
	scripts/make-calabash-lib.rb sim
	scripts/make-calabash-lib.rb device
	scripts/make-calabash-lib.rb version
	scripts/make-libraries.rb verify-framework

frank: clean
	scripts/make-frank-lib.rb sim
	scripts/make-frank-lib.rb device
	scripts/make-libraries.rb verify-frank

dylibs: clean
	scripts/make-calabash-dylib.rb sim
	scripts/make-calabash-dylib.rb device
	scripts/make-libraries.rb verify-dylibs

dylib_sim: clean
	scripts/make-calabash-dylib.rb sim
	scripts/make-libraries.rb verify-sim-dylib

install_test_binaries:
	$(MAKE) framework
	$(MAKE) dylibs
	./scripts/install-test-binaries.rb

webquery_headers:
	scripts/insert-js-into-webquery-headers.rb

test_app:
	scripts/make-lp-test-app.rb

xct:
	scripts/test/xctest.rb
