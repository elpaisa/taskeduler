
APP_NAME = taskeduler
NAME = $(APP_NAME)
NAME_PRE =
NAME_POST =
LOCATION = /var/taskeduler
LOCATION_PRE =
LOCATION_POST =
REBAR=./rebar3
RELEASE_LOCATION= ./_build/default/rel

.PHONY: all compile deps clean empty release test doc


all: compile

docs:
	$(REBAR) edoc

me:
	$(REBAR) compile skip_deps=true

shell:
	$(REBAR) shell


compile:
	$(REBAR) compile


test:
	$(REBAR) do eunit, cover

eunit:
	$(REBAR) eunit

empty:
	rm -rf _build
	rm -rf rebar.lock

doc:
	apidoc -v -i doc/ -o doc/api/ -f .erl


dialyzer:
	./dialyzer.sh


clean:
	$(REBAR) clean

clean-doc:
	rm -rf doc/api

release:
	$(REBAR) do eunit, clean, release
	cp -R files _build/default/rel/taskeduler
	$(REBAR) tar


fresh: clean compile test


-include deps/al_node_scripts/Makefile.incl


NODE_NAME = taskeduler

check: rpmbuild-exists
rpmbuild-exists: ; which rpmbuild > /dev/null
rpm: check
	test -e config/sys.config || mv config/sys.config.tmpl config/sys.config

	rm -f ./*.rpm

	mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SRPMS,SPECS,tmp}
	mkdir rpmbuild/RPMS/{i386,i586,i686,noarch,x86_64}

	cp build.spec rpmbuild/SPECS/build.spec
	make release

	rm -rf src
	mkdir src

	cp -R $(RELEASE_LOCATION) src/

	tar czf rpmbuild/SOURCES/build.tar.gz src

	rpmbuild -ba --define "_topdir `pwd`/rpmbuild" \
				--define "_version $(RPM_VERSION)" \
				--define "_NAME $(NAME)" \
				--define "_tmppath /var/tmp" \
				--define "_LOCATION $(LOCATION)" \
				--define "_release $(RPM_RELEASE)" \
				rpmbuild/SPECS/build.spec

	cp -R rpmbuild/RPMS/x86_64/ final/

