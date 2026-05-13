.PHONY: test

test:
	nvim --headless -u spec/minimal_init.lua \
	  -c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/minimal_init.lua'}" \
	  -c qa
