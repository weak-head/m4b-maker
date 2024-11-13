PREFIX := /usr/local

all:

install:
	install -d $(DESTDIR)$(PREFIX)/sbin
	install create-m4b.sh $(DESTDIR)$(PREFIX)/sbin/create-m4b

uninstall:
	rm $(DESTDIR)$(PREFIX)/sbin/create-m4b