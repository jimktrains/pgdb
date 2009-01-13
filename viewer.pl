#! /usr/bin/perl -w 

use strict; 
use Socket; 
use FileHandle;

#my $progname = shift or die "Must give program's name";
my $progpid = $$ or die "Must give program's pid";
my $progid = shift; 
die "Must give program an ID" unless defined $progid;

# initialize host and port 
my $host = shift || 'localhost'; 
my $port = shift || 7890; 

my $proto = getprotobyname('tcp'); 

# get the port address 
my $iaddr = inet_aton($host); 
my $paddr = sockaddr_in($port, $iaddr); 
# create the socket, connect to the port 

socket(SOCKET, PF_INET, SOCK_STREAM, $proto) or die "socket: $!"; 
connect(SOCKET, $paddr) or die "connect: $!"; 
SOCKET->autoflush(1);

#remote pid : remote mpi id : remote hostname
my $line = <SOCKET>;
#hostname returns a nl
print SOCKET "V:$progpid:$progid:".`hostname`;
#print "$progpid:$progid:" . `hostname` . "\n";
$line = <SOCKET>;


if(my $mypid = fork()){
	my $cmd = "";
	while($cmd ne "quit"){
		$cmd = <SOCKET>;
		$cmd = "quit" if not defined $cmd;
		print $cmd; 
	}
	print "bye\n";
} else {
	my ($oline, $eline, $line);
	for(;defined($oline = <>);){
		$line = defined $oline ? $oline : "";
				
		#print $line;
		print SOCKET $line;
		last if $line eq "quit\n";
		undef $oline;
	}
	print "bye2\n";
}

wait();
close SOCKET or die "close: $!"
