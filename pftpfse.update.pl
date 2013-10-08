#!/usr/bin/perl -w
use Net::FTP;
$_ = $0;
$_ =~ s/[^\/]*$/pftpfse.common.pl/;
require;
use vars qw( %info $path $DBG $FTP_DEBUG $FTP_PASSIVE );

sub get_date {
	my @date = localtime;
	$temp{year} = $date[5] + 1900;
	$temp{month} = $date[4] + 1;
	$temp{day} = $date[3];
	return %temp;
}
my %temp = get_date;
my %months = ('Jan'=>'01', 'Feb'=>'02', 'Mar'=>'03', 'Apr'=>'04', 'May'=>'05','Jun'=>'06','Jul'=>'07', 'Aug'=>'08', 'Sep'=>'09', 'Oct'=>'10','Nov'=>'11', 'Dec'=>'12');

sub dateFormat {
	my( $month, $day, $time ) = @_;
	my( $mon, $hours, $minutes );
	$mon = $months{$month};
	if( $time =~ /^(\d+):(\d+)$/ ) {
		$hours = $1;
		$minutes = $2;
		$hours = "0$hours" if ( length( $hours ) == 1 );
		$minutes = "0$minutes" if ( length( $minutes ) == 1 );
		$year = $temp{year};
		$time = "$hours$minutes";
	} elsif( $time =~ /^(\d+)$/ ) {
		$year = $1;
		$time = 0000;
	}
	$day = "0$day" if length $day == 1;
	return "$year$mon$day$time";
}

my $i = 0;
my @files;
sub walk {
	my( $shortname, $fullname ) = @_;
	$fullname =~ s/^\///;
	
dir_scan:

	if( $shortname ne '' ) {
		$ftp->cwd( $shortname ) or next; #print "$fullname$shortname: Can't cwd\n";
	}
	my @list = $ftp->dir();
	foreach( @list ) {
		if( /^([d\-])\S{9}\s+\S+\s+\S+\s+\S+\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+) (.*?)\r?$/
			or /^([d\-])\S{9}\s+\S+\s+\S+\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+) (.*?)\r?$/
			or /^([d\-])\s+\[[^\]]+\]\s+\S+\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+) (.*?)\r?$/
			or /^([d\-])\[[^\]]+\]\s+\d+\s+\S+\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+) (.*?)\r?$/ ) {
			my $filename = $6;
			next if( $filename eq '.' or $filename eq '..' or $filename eq '' );
			my $filetype = $1;
			if( $filetype eq '-' ) {
				my $filesize = $2;
				$files[$i]{filename} = $filename;
				$files[$i]{path} = $fullname;
				$files[$i]{size} = $filesize;
				$files[$i]{date} = dateFormat( $3, $4, $5 );
				$i++;
			} elsif( $filetype eq 'd' ) {
				&walk( $filename, "$fullname/$filename" );
			}
		} else {
			next;
		}
	}
	if ($shortname ne '') {
		$ftp->cdup();
	}
	return @files;
}

&dbg( "Starting $info{'PKGNAME'} v$info{'VERSION'} by $info{'NICK'}.. This may take a few minutes, so smile while waiting ;)\n\n" );

$path = ( $^O =~ /win/i ) ? "c:/program files/$info{'PKGNAME'}/" : "$ENV{'HOME'}/.$info{'PKGNAME'}/";

open DB, ">$path$info{DB}" or die "$path$info{'DB'}: ", $!;

my $line_count = 1;
open( FILE, $path.$info{LIST} ) or die $path, $info{LIST}, ': ', $!;
$time_start = time;
foreach $line ( <FILE> ) {
	next if $line =~ /^$/ or $line =~ /^#/;
	$line =~ s/\s*?#.*?$//;
	chomp( $line );
	if( $line =~ /^(ftp:\/\/)?((\w+):(\w+)@)?([\w\.]+):?(\d{1,5})?(\/(.+))?$/ ) {
		$username = ( defined $3 ) ? $3 : $Config->{ftp_username};
		$password = ( defined $4 ) ? $4 : $Config->{ftp_password};
		$port = ( defined $6 ) ? $6 : $Config->{ftp_port};
		&dbg( "Connecting to $5:$port .. ");
		$ftp = Net::FTP->new( $5, Debug => $FTP_DEBUG, Port => $port, Passive => $FTP_PASSIVE, Timeout => $Config->{ftp_timeout} ) or print "failed\n";
		if( $ftp ) {
			&dbg( "ok\n" );
			&dbg( "Logging in .. " );
			if( $ftp->login( $username, $password ) ) {
				&dbg( "ok\n" );
				$srv = $5;
				if( defined $8 ) {
					$special_dir = $8;
				} else {
					undef $special_dir;
				}
				$account = ( $username ne 'anonymous' ) ? "$username:***\@$srv:$port" : $srv;
				&dbg( "Getting data from $srv .. \n" );
				if( defined $special_dir ) {
					&dbg( "cwd into special directory: $special_dir .. ");
					$ftp->cwd( $special_dir );
					&dbg( "ok\n" );
				}
				&walk( '', '/' );
				foreach( @files ) {
					if( defined $_ ) {
						my @ext = split /\./, $_->{filename};
						$extention = pop( @ext );
						$path = ( $_->{path} eq '' ) ? $_->{path} : $_->{path}.'/';
						my $link = 'ftp://' . $account .'/'.$path. $_->{filename};
						print DB "$_->{'filename'}#:#:#$link#:#:#$_->{'size'}#:#:#$extention#:#:#$_->{'date'}#:#:#$username#:#:#$password#:#:#$srv#:#:#$port#:#:#$_->{'path'}\n";
						undef $_;
					}
				}
				&dbg( "everything's fine\n" );

			} else { &dbg( "failed\n" ); }
			$ftp->quit;
		}
		$line_count++;
	} else {
		die 'Wrong syntax in ', $path, $info{LIST}, ' near "', $line, "\" at line $line_count\n";
	}
}

close DB;
$time = time - $time_start;
&dbg( "\nFound $i files and finished in $time seconds\n" );
