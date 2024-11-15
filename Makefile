PREFIX := /usr/local

all:

install:
	install -d $(DESTDIR)$(PREFIX)/sbin
	install m4bify.sh $(DESTDIR)$(PREFIX)/sbin/m4bify

uninstall:
	rm $(DESTDIR)$(PREFIX)/sbin/m4bify