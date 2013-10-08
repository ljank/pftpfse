#!/usr/bin/perl -w
use Net::FTP;
use Net::Ping;
$_ = $0;
$_ =~ s/[^\/]*$/pftpfse.common.pl/;
require;
use vars qw( %info $path $DBG $FTP_DEBUG $FTP_PASSIVE $timeout $Config );

my $scan_username = defined $Config->{scan_username} ? $Config->{scan_username} : 'anonymous';
my $scan_password = defined $Config->{scan_anon_passwd} ? $Config->{scan_anon_passwd} : 'me@domain.com';
my $port = defined $Config->{scan_port} ? $Config->{scan_port} : 21;

if( @ARGV ) {
	foreach( @ARGV ) {
		if( /^\-t=(\d+)$/i ) {
			$timeout = $1;
		}
	}
}

$timeout = defined $timeout ? $timeout : $Config->{scan_timeout};

sub config_part {
	my( $arrayref, $str ) = @_;
	my @s = split /,/, $str;
	foreach( @s ) {
		$arrayref->[$1] = 1 if /^(\d+)$/;
		&range( $arrayref, 0, 255 ) if /^x$/i;
		&range( $arrayref, $1, $2 ) if /^(\d+)\-(\d+)$/;
	}
}

sub range {
	my( $arrayref, $from, $to ) = @_;
	for( $from..$to ) {
		$arrayref->[$_] = 1;
	}
}

sub checkout {
	my( $i1, $i2, $i3, $i4 ) = @_;
	my $ip = join '.', $i1, $i2, $i3, $i4;
	my @comment;
	&dbg( $ip, ': ' );
	my $p = Net::Ping->new( $Config->{scan_protocol}, $timeout );
	return 'Host is down' unless $p->ping( $ip );
	my $ftp = Net::FTP->new( $ip, Debug => $FTP_DEBUG, Port => $port, Passive => $FTP_PASSIVE, Timeout => $Config->{ftp_timeout} ) or return 'nothing';
	push @comment, 'ftp';
	if( !$ftp->login( $scan_username, $scan_password ) ) {
		$ftp->close();
	} else {
		push @comment, 'anonymous';
	}
	$ftp->close();
	&add( $ip, @comment );
	&dbg( join( ', ', @comment ), "\n" );
	$p->close();
	return;
}

sub add {
	my( $ip, @comment ) = @_;
	my $c = join ', ', @comment;
	open SLIST, ">>$path$info{'LIST'}";
	print SLIST "$ip # $c\n";
	close SLIST;
}

if( @ARGV ) {
	if( $ARGV[0] =~ /^([\dx\-,]+)\.([\dx\-,]+)\.([\dx\-,]+)\.([\dx\-,]+)$/i ) {
		my $time_start = time;
		my( @p1, @p2, @p3, @p4, $up, $all );
		$up = 0;
		&config_part( \@p1, $1 );
		&config_part( \@p2, $2 );
		&config_part( \@p3, $3 );
		&config_part( \@p4, $4 );
		for( $i1 = 0; $i1 < 256; $i1++ ) {
			if( $p1[$i1] ) {
				for( $i2 = 0; $i2 < 256; $i2++ ) {
					if( $p2[$i2] ) {
						for( $i3 = 0; $i3 < 256; $i3++ ) {
							if( $p3[$i3] ) {
								for( $i4 = 0; $i4 < 256; $i4++ ) {
									if( $p4[$i4] ) {
										$all++;
										$msg = &checkout( $i1, $i2, $i3, $i4 );
										if( $msg ) {
											&dbg( $msg, "\n" );
											next;
										} else {
											$up++;
										}
									}
								}
							}
						}
					}
				}
			}
		}
		$end = time - $time_start;
		&dbg( "\nFinished in $end seconds. Found $up FTP servers from $all.\n" );
	} else {
		print "syntax error\n";
	}
} else {
	print "usage:\t\tpftpfse.scaner.pl ip\nexample:\tpftpfse.scaner.pl 10.2.5.x\n";
}
