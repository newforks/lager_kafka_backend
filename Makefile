DIALYZER = dialyzer
REBAR = ./rebar3
MAKE = make

all:app

rel: deps
	@$(REBAR) as prod release

tar: deps
	@$(REBAR) as prod tar

app: deps
	@$(REBAR) compile

eunit: deps
	@$(REBAR) eunit

deps:
	@$(REBAR) get-deps

cdeps:
	@$(MAKE) -C _build/default/lib/merl/

upgrade:
	@$(REBAR) upgrade

clean:
	@$(REBAR) clean
	rm -f rebar3.crashdump

clean_all:
	rm -rf _build
	rm -f rebar.lock

