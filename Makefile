PREFIX := /usr/local

all:

install:
	install -d $(DESTDIR)$(PREFIX)/sbin
	install m4bify.sh $(DESTDIR)$(PREFIX)/sbin/m4bify
	install m4bulk.sh $(DESTDIR)$(PREFIX)/sbin/m4bulk

uninstall:
	rm $(DESTDIR)$(PREFIX)/sbin/m4bify
	rm $(DESTDIR)$(PREFIX)/sbin/m4bulk