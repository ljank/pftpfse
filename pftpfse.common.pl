use vars qw( %info $path $DBG $FTP_DEBUG $FTP_PASSIVE $Config @files $req $Default );

%info = (
	PKGNAME => 'pftpfse',
	DESCRIPTION => 'perl FTP File Search',
	VERSION => '0.0.10',
	AUTHOR => 'Lech Jankovski',
	NICK => 'godzhirra_da_mc',
	CONTACT => 'godzhirra@one.lt',
	LIST => 'server.list',
	DB => 'files.db',
	CFG => 'config'
);

$path = ( $^O =~ /win/i ) ? "c:/program files/$info{'PKGNAME'}/" : "$ENV{'HOME'}/.$info{'PKGNAME'}/";

$Default = {
	prompt => ' > ',
	downloads_dir => $path .'downloads/',
	ftp_debug => 0,
	ftp_timeout => 30,
	scan_timeout => 5,
	ftp_passive => 1,
	scan_username => 'anonymous',
	scan_anon_passwd => 'me@domain.com',
	scan_port => 21,
	ftp_username => 'anonymous',
	ftp_password => 'me@domain.com',
	ftp_port => 21,
	wget => `which wget` | '',
	scan_protocol => ( ( $^O =~ /win/i ) ? 'icmp' : 'tcp' )
};

foreach( values %$Default ) { chomp; }
$Default->{wget} = $Default->{wget} . ' -c -O' if $Default->{wget} ne '';
$Default->{download_manager} = ( $Default->{wget} ne '' ? 'wget' : 'Net::FTP' );

$req = {
	prompt => 1,
	downloads_dir => 1,
	ftp_debug => 1,
	ftp_timeout => 1,
	scan_timeout => 1,
	ftp_passive => 1,
	ftp_username => 1,
	ftp_port => 1,
	ftp_password => 1,
	wget => 1,
	download_manager => 1,
	scan_protocol => 1
};

if( ! -e "$path$info{'CFG'}" ) {
	&write( $Default );
	print "Checkout new 'conf' command and $path$info{'CFG'}. Type `help conf` for more info.\n\n";
} else {
	&load;
	foreach( sort keys %$Default ) {
		if( !defined $Config->{$_} ) {
			print "New var '$_' in conf\n"; $Config->{$_} = $Default->{$_};
		}
	}
	&write( $Config );
}

@files = ( $info{DB}, $info{LIST} );
foreach $file ( @files ) {
	&checkFile( $file );
}

sub checkFile {
	$file = shift;
	if( !( -e "$path$file") ) {
		if( !( -e $path ) ) { mkdir $path, 0700; }
		open FH, ">$path$file";
		close FH;
		chmod 0600, "$path$file";
	}
}

sub destroy {
	my $file = shift;
	open FH, ">$file";
	close FH;
	return 1;
}

foreach( @ARGV ) {
	chomp;
	if( /^(\-\-no\-debug|\-nd)$/i ) {
		$DBG = 1;
	}
	if( /^(\-\-ftp\-debug|\-fd)$/i ) {
		$FTP_DEBUG = 1;
	}
	if( /^((\-p|\-\-passive)=(true|false|\d))$/i ) {
		$FTP_PASSIVE = &true_false( $3 );
	}
}

$FTP_PASSIVE = defined $FTP_PASSIVE ? $FTP_PASSIVE : $Config->{ftp_passive};

sub true_false {
	my $str = shift;
	return 1 if( $str =~ /^true|1$/i );
	return 0 if( $str =~ /^false|0$/i );
}

sub dbg {
	$out = join( '', @_ );
	print $out if !$DBG;
}

sub load {
	require "$path$info{'CFG'}";
	$Config->{downloads_dir} =~ s/^\s*//;
	$Config->{downloads_dir} =~ s/^~/$ENV{HOME}/;
	$Config->{downloads_dir} .= '/' if $Config->{downloads_dir} !~ /\/$/;
	mkdir( $Config->{downloads_dir}, 0700 ) if ! -e $Config->{downloads_dir};
}

&load;

sub write {
	my $Config = shift;
	open CFG, ">$path$info{'CFG'}";
	print CFG "\$Config = {\n";
	foreach( sort keys %$Config ) {
		print CFG "\t$_ => q[", $Config->{$_}, "],\n";
	}
	print CFG "};\n1;\n";
	close CFG;
	chmod 0600, "$path$info{'CFG'}";
	return;
}

sub set {
	my( $key, $val ) = @_;
	$key = lc $key;
	$Config->{$key} = $val;
	&write( $Config );
	&load;
	return;
}

sub unset {
	my $key = shift;
	$key = lc $key;
	if( defined $Config->{$key} and !$req->{$key} ) {
		delete $Config->{$key};
		&write( $Config );
	}
}

sub get {
	my $key = shift;
	$key = lc $key;
	return "\t$key\t$Config->{$key}" if defined $Config->{$key};
	return;
}

sub default {
	my $key = shift;
	$key = lc $key;
	if( defined $Default->{$key} ) {
		$Config->{$key} = $Default->{$key};
		&write( $Config );
		return $Config->{$key};
	} else {
		return;
	}
}

1;
