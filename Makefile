.POSIX:

CRYSTAL = crystal
CRFLAGS =
OPTS = --parallel=4 --chaos -v

all: test

test: .phony
	$(CRYSTAL) run $(CRFLAGS) test/*_test.cr -- $(OPTS)

.phony:
