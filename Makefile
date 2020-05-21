# vim: ts=8 noet:

NVME_SCRIPTS := $(subst scripts/,build/,$(wildcard scripts/nvme/*))
CORE_PROFILES := $(wildcard profiles/*/*)
TARGET_PROFILES := $(wildcard profiles/*.conf)

PROFILE :=
BUILD :=
BUILDS := $(BUILD)
LEVEL :=

# by default, use the 'packer' in the path
PACKER := packer
export PACKER


check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
        $(error Undefined $1$(if $2, ($2))$(if $(value @), \
                required by target `$@')))


.PHONY: amis prune release-readme clean

amis: build/packer.json build/profile/$(PROFILE) build/update-release.py build/make-amis.py build/setup-ami $(NVME_SCRIPTS)
	@:$(call check_defined, PROFILE, target profile name)
	build/make-amis.py $(PROFILE) $(BUILDS)

prune: build/prune-amis.py
	@:$(call check_defined, LEVEL, pruning level)
	@:$(call check_defined, PROFILE, target profile name)
	build/prune-amis.py $(LEVEL) $(PROFILE) $(BUILD)

release-readme: releases/README.md
releases/README.md: build/gen-release-readme.py
	@:$(call check_defined, PROFILE, target profile name)
	@:$(call require_var, PROFILE)
	build/gen-release-readme.py $(PROFILE)

build/%: scripts/%
	mkdir -p $$(dirname $(subst scripts/,build/,$<))
	cp $< $@

build:
	python3 -m venv build
	[ -d build/profile ] || mkdir -p build/profile
	build/bin/pip install -U pip pyhocon pyyaml boto3

build/packer.json: packer.conf build 
	build/bin/pyhocon -i $< -f json > $@

.PHONY: build/profile/$(PROFILE)
build/profile/$(PROFILE): build/resolve-profile.py $(CORE_PROFILES) $(TARGET_PROFILES)
	@:$(call check_defined, PROFILE, target profile name)
	build/resolve-profile.py $(PROFILE)

build/%.py: scripts/%.py.in build
	sed "s|@PYTHON@|#!`pwd`/build/bin/python|" $< > $@
	chmod +x $@

clean:
	rm -rf build
