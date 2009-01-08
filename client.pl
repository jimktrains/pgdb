#! /usr/bin/perl -w 

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
my $line = <SOCKET>;
chomp $line;
print "Preamble: $line\n";
print SOCKET "$progpid:$progid:".`hostname`."\n";
#print "$progpid:$progid:" . `hostname` . "\n";
$line = <SOCKET>;
chomp $line;
print "Greeting: $line\n";

my ($GDBSTDOUT, $GDBSTDIN, $GDBSTDERR);
my $gdbpid = open3($GDBSTDIN, $GDBSTDOUT, $GDBSTDERR, "gdb $progname $progpid");

if(my $mypid = fork()){
	my $cmd = "";
	print  "Waiting for a command\n";
	my $line = <SOCKET>;
	print "LINE: $line";
	while($cmd ne "quit"){
		print "in while\n";
		$cmd = <SOCKET>;
		print "Got: $cmd \n";
		$cmd = "quit" if not defined $cmd;
		print $GDBSTDOUT $cmd; 
	}
	
} else {
	my ($oline, $eline, $line);
	while(defined($oline = <$GDBSTDOUT>) or defined($eline =  <$GDBSTDERR>)){
		$line = defined $oline ? $oline : "";
		$line = $line."E:$eline" if defined $eline;
				
		print $line;
		print SOCKET $line;

		undef $oline;
		undef $eline;
	}
}

wait();
close SOCKET or die "close: $!"
