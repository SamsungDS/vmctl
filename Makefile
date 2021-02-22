SHELLCHECK := $(shell command -v shellcheck 2>/dev/null)

check:
ifndef SHELLCHECK
	$(error "cannot find shellcheck; install to run check")
endif
	shellcheck -a -x \
		vmctl cmd/* common/* lib/qemu/*
