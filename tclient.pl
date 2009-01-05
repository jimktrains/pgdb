#! /usr/bin/perl -w 
use strict; 
use Socket; 
use FileHandle;

my $host = shift || 'localhost'; 
my $port = shift || 7890; 

socket(SOCKET, PF_INET, SOCK_STREAM, getprotobyname('tcp')) or die "socket: $!"; 
connect(SOCKET, sockaddr_in($port, inet_aton($host)) ) or die "connect: $!"; 
SOCKET->autoflush(1);

print SOCKET "JIM:TEST:".`hostname`."\n";
print SOCKET "WHOOO\n";
print <SOCKET>;
close SOCKET or die "close: $!"
