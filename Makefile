BINDIR=/usr/local/bin

cpan:
	cpan -i Net::FTP
	cpan -i Net::Ping
	cpan -i POSIX
	cpan -i Term::ReadLine

install:
	@echo You must be root to install
	install -m 0555 pftpfse.pl $(BINDIR)
	install -m 0555 pftpfse.update.pl $(BINDIR)
	install -m 0555 pftpfse.scaner.pl $(BINDIR)
	install -m 0555 pftpfse.common.pl $(BINDIR)
