#!/usr/bin/perl -w
require Net::FTP;
require POSIX;
use IO::Socket;
use Cwd;
use Term::ReadLine;
$_ = $0;
$_ =~ s/[^\/]*$/pftpfse.common.pl/;
require;
use vars qw( %info $path $DBG $FTP_DEBUG $FTP_PASSIVE $Config );
my $into = $Config->{downloads_dir};

my $term = new Term::ReadLine 'pftpfse';
my( $errstr );

sub kilobytes {
	$size = shift;	
	return POSIX::ceil( $size / 1024 );
}

sub server_list {
	undef @list;
	open LIST, "$path$info{LIST}";
	my $c = 0;
	foreach( <LIST> ) {
		s/\s*#.*?$//;
		chomp;
		if( $_ ne '' ) {
			$list[$c] = $_;
			$c++;
		}
	}
	close LIST;
	return @list;
}

sub help {
	$cmd = shift;
	my $cmd_n = 0;
	$commands[$cmd_n++] = [ 'find', 'f', 'search for file', "\tfind filename\n\tfind --ext extention\n\tfind filename --ext extention\n\tfind filename --since\tyesterday\n\t\t\t\tpast n [ hours | days | weeks | months | years ]\n\t\t\t\tlast [ week | month | year ]\n\t\t\t\t[ yyyy.mm.dd | yyyy/mm/dd | yyyy-mm-dd ]\n\t\t\t\t[ mm.dd | mm/dd | mm-dd ]\n\tfind filename --links\n\tfind --dir dirname\n\nFull Syntax: find [ filename | --dir dirname ] --ext extention --since yesterday --links\n\t # all the elements are optional but order is necessary to use them together", "\tfind crap\n\tfind --ext mp3\n\tfind crap --ext mp3\n\tfind crap --since past 5 days\n\tfind crap --since yesterday\n\tfind crap --since last week\n\tfind crap --links\n\tfind --dir dirname" ];
	$commands[$cmd_n++] = [ 'results', 'r', 'view last results', "\tresults\n\tresults --links" ];
	$commands[$cmd_n++] = [ 'get', 'g', 'get file(s)', "\tget int\n\tget --whole-dir int\n\tget from_int-to_int\n\tget int, int, int", "\tget 3\n\tget --whole-dir 3\n\tget 1-15\n\tget 1, 3, 5, 7" ];
	$commands[$cmd_n++] = [ 'update', 'u', 'update database' ];
	$commands[$cmd_n++] = [ 'empty', 'e', 'empty database' ];
	$commands[$cmd_n++] = [ 'last', 'l', 'last database update' ];
	$commands[$cmd_n++] = [ 'server', 's', 'add/delete/empty/list servers in server.list', "\tserver add user:password\@host:port/dir # skip username and password if anonymous and skip port if default (21)\n\tserver del int\n\tserver empty\n\tserver list", "\tserver add root:love\@fbi.gov:666\n\tserver del 1\n\tserver empty\n\tserver list" ];
	$commands[$cmd_n++] = [ 'scan', '', 'scan for ftp servers in LAN', "\tscan ip", "\tscan 10.1-3.1-5,7,9-13.x" ];
	$commands[$cmd_n++] = [ 'conf', '', 'view/edit configuration', "\tconf\n\tconf set key value\n\tconf unset key\n\tconf get key\n\tconf default key", "\tconf\n\tconf set prompt  -> \n\tconf unset crap\n\tconf get downloads_dir\n\tconf default prompt" ];
	$commands[$cmd_n++] = [ 'prompt', 'p', 'manage prompt', "\tprompt\n\tprompt set string\n\tprompt default", "\tprompt\n\tprompt set \%T \%/ > \n\tprompt default\n\nKeys:\n\t\%T - long time format [hh:mm:ss]\n\t\%t - short time format [hh:mm]\n\t\%/ - current working dir\n\t\%p - package name [pftpfse]\n\t\%v - version" ];
	$commands[$cmd_n++] = [ 'pwd', '', 'current working directory' ];
	$commands[$cmd_n++] = [ 'lcd', '', 'change local working directory' ];
	$commands[$cmd_n++] = [ 'check', 'c', 'check for new releases' ];
	$commands[$cmd_n++] = [ 'version', 'v', 'print out current version' ];
	$commands[$cmd_n++] = [ 'help', 'h', 'see this help' ];
	$commands[$cmd_n++] = [ 'quit', 'q', 'just get out of here (more alieses: bye, exit)' ];

	if( defined $cmd ) {
		for( my $i = 0; $i < @commands; $i++ ) {
			if( $cmd eq $commands[$i][0] or $cmd eq $commands[$i][1] ) {
				$out = "\n$commands[$i][0], $commands[$i][1] - $commands[$i][2]\n";
				$out .= "\nSyntax:\n$commands[$i][3]\n" if $commands[$i][3];
				$out .= "Examples:\n$commands[$i][4]\n" if $commands[$i][4];
				$out .= "\n";
			}
		}
		if( $out ) {
			print $out;
			undef $out;
		} else {
			print "$cmd: No such command ..\n";
		}
	} else {
		print "\n";
		print "\tcommand\talias\tmeaning\n";
		foreach( @commands ) {
			print "\t$_->[0]\t$_->[1]\t- $_->[2]\n";
		}
		print "\nFor more info type: help command\n";
	}
}

sub filesize {
	$file = shift;
	
	if( defined $file ) {
		return -s $file or die "$file: $!\n";
	}
}

sub dateFormat {
	return @_;
}

sub percents {
	my( $local, $remote ) = @_;
	
	if( defined $local and defined $remote ) {
		return POSIX::ceil( ( 100 * $local ) / $remote );
	}
}

my @results;

sub download {
	my( $a, $sleep ) = @_;
	sleep( 1 ) if $sleep;
	my $filename = $results[$a]{'file'};
	if( -e "$Config->{'downloads_dir'}$results[$a]{'file'}" ) {
		print "File '$results[$a]{'file'}' allready exists.\n\n\t[O]verwrite? [R]ename? : ";
		my $answer = <STDIN>;
		chomp( $answer );
		return if( $answer !~ /^\s*(o|r)\s*$/i );
		print "\n";
		if( $answer =~ /^\s*r\s*$/i ) {
			print "New filename: ";
			my $answer2 = <STDIN>;
			chomp $answer2;
			$filename = $answer2 if $answer2 !~ /^\s*$/;
			until( $answer2 !~ /^\s*$/ ) {
				print "New filename: ";
				$answer2 = <STDIN>;
				chomp $answer2;
				$filename = $answer2;
			}
		}
		print "\n";
	}
	if( $Config->{download_manager} =~ /^Net::FTP$/i ) {
		print $results[$a]{link}, "\n\t=> ", $Config->{downloads_dir}, $filename, "\n\n";
		print "Connecting to $results[$a]{'server'}:$results[$a]{'port'} .. ";
		$ftp = Net::FTP->new( $results[$a]{server}, Debug => $Config->{ftp_debug}, Port => $results[$a]{port}, Passive => $FTP_PASSIVE ) or return "can't connect\n";
		print "connected.\nLogging in as $results[$a]{'user'} .. ";
		$ftp->login( $results[$a]{user}, $results[$a]{pass} ) or return "can't login\n";
		print "Logged in!\n";
		if( $results[$a]{dir} ne '' ) {
			print "==> CWD $results[$a]{'dir'} .. ";
			$ftp->cwd( $results[$a]{dir} ) or return "can't cwd\n";
			print "done\n==> RETR $results[$a]{'file'} .. done\n";
		}
		my $size = kilobytes( $results[$a]{size} );
		print "Length: $size KB\n\n";
		$download_start = time;
		$ftp->binary();
		$ftp->get( $results[$a]{file}, "$Config->{'downloads_dir'}$filename" ) or return "can't get file\n";
		$downloaded_in = time - $download_start;
		$ftp->quit;
		print "`$Config->{'downloads_dir'}$filename' saved [$size KB] in $downloaded_in seconds!\n";
	} elsif( $Config->{download_manager} =~ /^\s*wget\s*$/i ) {
		my $url = join '', 'ftp://', $results[$a]{user}, ':', $results[$a]{pass}, '@', $results[$a]{server}, ':', $results[$a]{port}, '/', $results[$a]{dir}, '/', $results[$a]{file};
		my $manager = $Config->{download_manager};
		print `$Config->{$manager} $Config->{'downloads_dir'}$filename $url`;
	} else {
		print "Bad download_manager: $Config->{'download_manager'}\nValid: wget, Net::FTP. Type `help conf` for more info how to set `download_manager` or use `conf default download_manager`.\n";
	}
	return undef;
}

sub last_update {
	my $file = shift;
	$s = ( stat( $file ) )[9];
    	printf "database last updated at %s\n", scalar localtime $s;
}

sub catch_keyword {
	my $keyword = shift;
	my $time = time;
	my @date = localtime;
	if( $keyword =~ /^([\w\s]+)$/ ) {
		my $kwd = $1;
		if( $kwd =~ /^yesterday$/i ) {
			$time = $time - 86400;
		} elsif( $kwd =~ /^last month$/i ) {
			$time = $time - 2592000;
		} elsif( $kwd =~ /^last week$/i ) {
			$time = $time - 604800;
		} elsif( $kwd =~ /^last year$/i ) {
			$time = $time - 31536000;
		} elsif( $kwd =~ /^past \d+/i ) {
			my $seconds;
			if( $kwd =~ /^past (\d+) days$/i ) {
				$seconds = $1 * 24 * 60 * 60;
			} elsif( $kwd =~ /^past (\d+) months$/i ) {
				$seconds = $1 * 30 * 24 * 60 * 60;
			} elsif( $kwd =~ /^past (\d+) years$/i ) {
				$seconds = $1 * 356 * 24 * 60 * 60;
			} elsif( $kwd =~ /^past (\d+) hours$/i ) {
				$seconds = $1 * 60 * 60;
			} elsif( $kwd =~ /^past (\d+) weeks$/i ) {
				$seconds = $1 * 7 * 24 * 60 * 60;
			}
			$time = $time - $seconds if $seconds;
			undef $seconds;
		} else {
			return undef;
		}
		@date = localtime $time if $time;
	} elsif( $keyword =~ /^(\d{4})[\.\-\/](\d{1,2})[\.\-\/](\d{1,2})$/ ) { $date[5] = $1 - 1900; $date[4] = $2 - 1; $date[3] = $3; $date[2] = 0; $date[1] = 0; }
	elsif( $keyword =~ /^(\d{1,2})[\.\-\/](\d{1,2})$/ ) { $date[4] = $1 - 1; $date[3] = $2; $date[2] = 0; $date[1] = 0; }
	else { return undef; }
	undef $time;
	my( $year, $month, $day, $hours, $minutes );
	$year = $date[5] + 1900;
	$month = $date[4] + 1; $month = "0$month" if length $month == 1;
	$day = $date[3]; $day = "0$day" if length $day == 1;
	$hours = $date[2]; $hours = "0$hours" if length $hours == 1;
	$minutes = $date[1]; $minutes = "0$minutes" if length $minutes == 1;
	$since = "$year$month$day$hours$minutes";
	return $since;
}

sub find {
	my( $args, $print, $get ) = @_;
	open DB, "$path$info{DB}" or die "$path$info{DB}: ", $!;
	my $i = 0;
	@results = 0;
	my $find_all = 0;
	foreach $r ( <DB> ) {
		$find_all++;
		my( $file, $link, $size, $extention, $date, $username, $password, $server, $port, $dir ) = split /#:#:#/, $r, 10;
		chomp( $dir );
		my $s = ( defined $args->{file} ) ? $args->{file} : $file;
		my $e = ( defined $args->{ext} ) ? $args->{ext} : $extention;
		my $d = ( defined $args->{dir} ) ? $args->{dir} : $dir;
		my $find_dir = ( $args->{d} ) ? $args->{d} : $dir;
		$since = ( $args->{since} ) ? $args->{since} : $date;
		if( $file =~ /\Q$s\E/i and lc $extention eq lc $e and $dir eq $d and $date >= $since and $dir =~ /\Q$find_dir\E/i ) {
			$results[$i] = {
				user => $username,
				pass => $password,
				server => $server,
				port => $port,
				dir => $dir,
				file => $file,
				size => $size,
				ext => $extention,
				link => $link
			};
			if( $print ) { 
				my $what = ( $args->{type} eq 'link' ) ? $link : $file;
				print "[$i] $what (", kilobytes( $size ), " KB)\n";
			}
			if( $get ) { $errstr = download( $i, 1 ); print $errstr if $errstr; }
			$i++;
		}
	}
	close DB;
	if( $i > 0 ) {
		if( $print ) { print "\nFound $i files from $find_all. Now you can get file by typing i.e. get 1\nFor more info type 'help get'\n"; }
	}
}

sub releaseCheck {
	$remote = IO::Socket::INET->new(
		Proto => 'tcp',
		PeerAddr => 'pftpfse.sourceforge.net',
		PeerPort => 'http(80)'
	) or die "Can't connect ..\n";
	$remote->autoflush( 1 );
	print $remote "GET /release HTTP/1.0\nHost: pftpfse.sourceforge.net\n\n";
	while( <$remote> ) {
		if( $_ !~ /^([\w\-]+:)|(^\n)/ ) {
			$rel = $_;
		}
	}
	chomp $rel;
	my $remote = $rel;
	my $local = $info{VERSION};
	$remote =~ s/(\d+)\.(\d+)\.(\d+)/$1$2$3/;
	$local =~ s/(\d+)\.(\d+)\.(\d+)/$1$2$3/;
	$remote =~ s/^0+//;
	$local =~ s/^0+//;
	if( $local < $remote ) {
		print "New $rel release is avaible at http://pftpfse.sf.net/ !\n";
	} else {
		print "$info{'VERSION'} is still newest release..\n";
	}
}

sub prompt {
	my $str = shift;
	my $pwd = getcwd;
	$str =~ s/%\//$pwd/;
	my @date = localtime;
	my $h = $date[2]; $h = "0$h" if length $h == 1;
	my $m = $date[1]; $m = "0$m" if length $m == 1;
	my $s = $date[0]; $s = "0$s" if length $s == 1;
	my $shortTime = "$h:$m";
	my $longTime = "$shortTime:$s";
	$str =~ s/%t/$shortTime/;
	$str =~ s/%T/$longTime/;
	$str =~ s/%v/$info{VERSION}/;
	$str =~ s/%p/$info{PKGNAME}/;
	return $str;
}

while( defined( $_ = $term->readline( &prompt( $Config->{prompt} ) ) ) ) {
	$command = $_;
	chomp( $command );
	print "\n" if( $command ne '' );
	if( $command =~ /^\s*(h(elp)?|\?)(\s+(\w+))?\s*$/i ) {
		if( defined $4 ) {
			help( $4 );
		} else {
			help();
		}
	} elsif( $command =~ /^\s*f(ind)?
		(\s+(([\w\s\.]+[^\-]+)|\-\-dir\s([\w\s\.]+[^\-]+)))?
		(\s+\-\-ext\s+(\w+))?
		(\s+\-\-since\s+
			((\d{4}[\.\-\/]\d{1,2}[\.\-\/]\d{1,2})
			|(\d{1,2}[\.\-\/]\d{1,2})
			|([\w\s]+)))?
			(\s+\-\-links)?\s*$/xi ) {
		my $type = ( $13 ) ? 'link' : 'name';
		my $sin = catch_keyword( $9 ) if $9;
		find( { file => $4, d => $5, ext => $7, since => $sin, type => $type }, 1, 0 );
	} elsif( $command =~ /^\s*e(mpty)?\s*?$/i ) {
		print "ok, database empty\n" if &destroy( "$path$info{'DB'}" );
	} elsif( $command =~ /^\s*f(ind)?\s*?$/i ) {
		print "Usage: find filename\nExample: find crap\n\nFor more type 'help find'\n";
	} elsif( $command =~ /^\s*scan\s+(.+)$/i ) {
		print "Scanning $1 .. \n";
		print `pftpfse.scaner.pl $1`;
	} elsif( $command =~ /^\s*g(et)?/i ) {
		if( $command =~ /^\s*g(et)?\s+(\d+)\s*?$/i ) {
			if( defined $results[$2] ) {
				$errstr = download( $2 );
				print $errstr if $errstr;
			}
		} elsif( $command =~ /^\s*g(et)?\s+\-\-whole\-dir\s+(\d+)\s*?$/i ) {
			$num = $2;
			if( defined $results[$num] ) {
				if( !( -e $results[$num]{dir} ) ) { mkdir $results[$num]{dir}, 0700; }
				chdir $results[$num]{dir};
				find( { file => undef, ext => undef, dir => $results[$num]{dir} }, 0, 1 );
			}
		} elsif( $command =~ /^\s*g(et)?\s+(\d+\-\d+)\s*?$/i ) {
			my @int = split /\-/, $2;
			for( $i = $int[0]; $i <= $int[1]; $i++ ) {
				if( defined $results[$i] ) {
					$errstr = download( $i, 1 );
					print $errstr if $errstr;
				} else {
					print "$i - not in results?\n";
				}
			}
		} elsif( $command =~ /^\s*g(et)?\s+([\d,\s]+)$/i ) {
			my @files = split /\s?,\s?/, $2;
			foreach $file ( @files ) {
				if( $file =~ /\d+/ ) {
					if( defined $results[$file] ) {
						$errstr = download( $file, 1 );
						print $errstr if $errstr;
					} else {
						print "$file - not in results?\n";
					}
				}
			}
		} else {
			print "Not in results?\n";
		}
	} elsif( $command =~ /^\s*l(ast)?\s*$/i ) {
			last_update( "$path$info{'DB'}" );
	} elsif( $command =~ /^\s*g(et)?\s*$/i ) {
		print "Usage: get int\nExample: get 1\n\nFor more type 'help get'\n";
	} elsif( $command =~ /^\s*r(esults)?(\s+(\-\-links))?\s*$/i ) {
		my $count = 0;
		my $what = ( defined $3 ) ? 'link' : 'file';
		foreach $r ( @results ) {
			if( $r ) {
				print "[$count] $r->{$what} (", kilobytes( $r->{size} ), " KB)\n";
				$count++;
			}
		}
	} elsif( $command =~ /^\s*lcd\s(.+)/i ) {
		$ldir = $1;
		if( -e $ldir and -d $ldir ) {
			chdir $ldir;
			print "Current working dir is now ", getcwd, "\n";
		} else {
			print "$ldir isn't dir or doesn't exist at all\n";
		}
	} elsif( $command =~ /^\s*pwd\s*$/i ) {
		print "Current working dir: ", getcwd, "\n";
	} elsif( $command =~ /^\s*s(erver)?/i ) {
		if( $command =~ /^\s*s(erver)?\s+add\s(.+)$/i ) {
			open LIST, ">>$path$info{LIST}";
			print LIST $2, "\n";
			close LIST;
			print "Successfully added $2\n";
		} elsif( $command =~ /^\s*s(erver)?\s+list\s*$/i ) {
			my @srv_list = server_list();
			my $line_num = 0;
			foreach $serv ( @srv_list ) {
				print "[$line_num] ", $serv, "\n";
				$line_num++;
			}
		} elsif( $command =~ /^\s*s(erver)?\s+del\s+(\d+)$/i ) {
			my @list = server_list();
			if( defined $list[$2] ) {
				undef $list[$2];
				my @valid_list;
				foreach $entry ( @list ) {
					if( defined $entry ) {
						push @valid_list, $entry;
					}
				}
				if( !defined( $valid_list[0] ) ) {
					open LIST, ">$path$info{LIST}";
					close LIST;
				} else {
					my $data = join( "\n", @valid_list );
					open LIST, ">$path$info{LIST}" or die "$path$info{LIST}: ", $!;
					print LIST $data."\n";
					close LIST;
				}
			} else {
				print "No such server. See server list first by typing 'server list'. For more type 'help server'\n";
			}
		} elsif( $command =~ /^\s*s(erver)?\s+empty\s*/i ) {
			print "server list is empty now\n" if &destroy( "$path$info{'LIST'}" );
		}
	} elsif( $command =~ /^\s*conf/i ) {
		if( $command =~ /^\s*conf\s+set\s+(\S+)\s(.+)$/i ) {
			$key = lc $1;
			&set( $key, $2 );
			print "\t$key\t$2\n";
		} elsif( $command =~ /^\s*conf\s+unset\s+(\S+)\s*$/i ) {
			&unset( $1 );
		} elsif( $command =~ /^\s*conf\s+get\s+(\S+)\s*$/i ) {
			my $val = &get( $1 );
			print $val, "\n" if $val;
		} elsif( $command =~ /^\s*conf\s*$/i ) {
			print "Current configuration of $path$info{'CFG'} is:\n\n";
			foreach $k ( sort keys %$Config ) {
				printf( "\t%-18s => %s\n", $k, $Config->{$k} );
			}
			print "\n";
		} elsif( $command =~ /^\s*conf\s+default\s+(\S+)$/i ) {
			$def = &default( $1 );
			print "\t", lc $1, "\t", $def, "\n" if defined $def;
		} else {
			print "'help conf' for more info\n";
		}
	} elsif( $command =~ /^\s*p(rompt)?/i ) {
		if( $command =~ /^\s*p(rompt)?\s+set\s(.+)$/i ) {
			&set( 'prompt', $2 );
			print "\tprompt\t$2\n";
		} elsif( $command =~ /^\s*p(rompt)?\s+default\s*$/i ) {
			&default( 'prompt' );
			print "\tprompt\t", $Config->{prompt}, "\n";
		} elsif( $command =~ /^\s*p(rompt)?\s*/i ) {
			print "\tprompt\t", $Config->{prompt}, "\n";
		}
	} elsif( $command =~ /^\s*c(heck)?\s*$/i ) {
		releaseCheck();
	} elsif( $command =~ /^\s*v(ersion)?\s*$/i ) {
		print "You're using $info{'PKGNAME'} v$info{'VERSION'}\n";
	} elsif( $command =~ /^\s*u(pdate)?\s*$/i ) {
		system( 'pftpfse.update.pl' );
	} elsif( $command =~ /^\s*(q(uit)?|bye|exit)\s*$/i ) {
		die "Thanks for using $info{'PKGNAME'} v$info{'VERSION'}!\n";
	} elsif( $command eq '' ) {
		next;
	} else {
		print "What? Type 'help' to get list of available commands.\n";
	}
}
