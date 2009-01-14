#! /usr/bin/perl -w 
#    pgdb is a wrapper allowing the output of multiple programs to be recieved
#      and used at a single terminal
#    Copyright (C)  2009 Jim Keener
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    You can contact the author via email at jkeener@psc.edu or snail mail at:
#	  James Keener
#	  Pittsburgh Supercomputing Center
#	  300 S. Craig St.
#	  Pittsburgh, Pa 15312

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
