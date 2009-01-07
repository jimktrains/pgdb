#! /usr/bin/perl -w 
use strict; 
use Socket; 
use IO::Handle;

my $port = shift || 7890; 

socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp')) or die "socket: $!"; 
setsockopt(SERVER, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsock: $!"; 
bind(SERVER, sockaddr_in($port, INADDR_ANY)) or die "bind: $!"; 
listen(SERVER, SOMAXCONN) or die "listen: $!"; 
print "SERVER started on port $port\n"; 

while(not accept(CLIENT, SERVER)){}
if(fork()){
	CLIENT->autoflush(1);
	print CLIENT "Who is this?\n";
	my $line = <CLIENT>;
	print $line;
	my ($rpid, $rid, $rhost) = split(/:/, $line, 3);
	print CLIENT "Hello, $rid\n";
} else {
	while(<> ne "quit"){}
}

wait();
close CLIENT; 