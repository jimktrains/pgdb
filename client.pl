#! /usr/bin/perl -w 
# client1.pl - a simple client 
#---------------- 

use strict; 
use Socket; 
use IPC::Open3;
use FileHandle;

my $progname = shift or die "Must give program's name";
my $progpid = shift or die "Must give program's pid";
my $progid = shift or die "Must give program an ID";

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
#print <SOCKET>;
print SOCKET "$progpid:$progid:".`hostname`."\n";
#print "$progpid:$progid:" . `hostname` . "\n";
print <SOCKET>;
my $GDBSTDOUT;
my $GDBSTDIN;
my $GDBSTDERR;
my $gdbpid = open3($GDBSTDIN, $GDBSTDOUT, $GDBSTDERR, "gdb $progname $progpid");

if(my $mypid = fork()){
	my $cmd = "";
	while($cmd ne "quit"){
		$cmd = <SOCKET>;
		$cmd = "quit" if not defined $cmd;
		print $GDBSTDOUT $cmd; 
	}
	
} else {
	while(my $line = (<$GDBSTDOUT> ||  <$GDBSTDERR>)){
		print SOCKET $line;
	}
}

wait();
close SOCKET or die "close: $!"
