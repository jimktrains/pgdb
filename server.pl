#!/usr/bin/perl -w 
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
use IPC::SysV qw(IPC_NOWAIT IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR);
use IO::Handle;
use Fcntl;
use Getopt::Std;

my %options=();
getopts("dp:",\%options);
my $DEBUG = defined $options{d};
# use port 7890 as default 
my $port = defined $options{p} ? $options{p} :  7890; 
my $proto = getprotobyname('tcp'); 
my $id = msgget(IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR);

my $sent = "message";
my $type_sent = 1234;
my $rcvd;
my $type_rcvd;
my $buf;
die "message queue id not defined\n" unless defined $id;

print "    pgdb  Copyright (C) 2009  James Keener
    This program comes with ABSOLUTELY NO WARRANTY; for details type `p warranty'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type `p copywrite' for details.\n";

if($DEBUG){
	print "message queue id: $id\n";
	print "Testing message queue\n";
	msgsnd($id, pack("l! l!", $type_sent, $type_sent), 0) or die "Send failed";
	print "Sent OK\n";
	msgrcv($id, $buf, 1024, $type_sent, 0) or die "Recieve Failed";
	my ($t1, $t2) = unpack("l! l!", $buf);
	print "Message queue " . ($t1 eq $t2 ? "OK"  : "BAD") . "\n";
}

#create a socket, make it reusable 
socket(SERVER, PF_INET, SOCK_STREAM, $proto) or die "socket: $!"; 
setsockopt(SERVER, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsock: $!"; 

# grab a port on this machine 
my $paddr = sockaddr_in($port, INADDR_ANY);

# bind to a port, then listen 
bind(SERVER, $paddr) or die "bind: $!"; 
listen(SERVER, SOMAXCONN) or die "listen: $!"; 
print "SERVER started on port $port\n"; 
my $add_type = 1;
my $send_type = 2;
my $stdin_type = 3; 
my $kill_type = 4;
my $add_viewer_type = 5;
my $stdin_viewer_type = 6;
# accepting a connection 
my $client_addr; 
if(not fork()){
	my $mygid = 10;
	my $dead = 0;

	if($DEBUG){
		print "Testing Sending\n";
		msgsnd($id, pack("l! l!", $type_sent, $type_sent), 0) or die "Send failed";
		print "Sent OK\n";
	}
	#http://www.bearcave.com/unix_hacks/perl/perl.htm
	#"however, apparently last cannot be used to exit while loops in perl" my experience too:(

	my $kbuf;
	 if(fork()){
	 	my $line = "";
	 	for(;not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT); $line = <>){
			msgsnd($id, pack("l! a*", $stdin_type, $line), 0) if length $line;
		}
	 }else{
		my $w = 0; 
		my $buf;
		my	($line, $node_type, $rpid, $rid, $rhost);

		for(;
				not ($dead = msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT))
				and accept(CLIENT, SERVER) 
			;$mygid++){ 

			CLIENT->autoflush(1);
			print CLIENT "VER 1 PGDB-JK\n";

			my $line = <CLIENT>;
			print "ID String: $line" if $DEBUG;
			#remote pid : remote mpi id : remote hostname
			($node_type, $rpid, $rid, $rhost) = split(/:/, $line);
			print "sent greeting to client\n" if $DEBUG;
			print CLIENT "Hello, $rid\n";
			if($node_type eq "D"){
				print "sending add debugger request to other proc\n" if $DEBUG;
				msgsnd($id, pack("l! l! l! l!", $add_type, $rpid, $rid, $mygid), 0);
			} elsif ($node_type eq "V"){
				print "sending add viewer request to other proc\n" if $DEBUG;
				msgsnd($id, pack("l! l! l! l!", $add_viewer_type, $rpid, $rid, $mygid), 0);
			}
			last if fork();
			$w = 1;
			last if fork();
			$w = 0;
		}
		if(not $dead){
			if($node_type eq "D"){
				if($w){
					undef $buf;
					undef $line;

					while(not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT)){
						#print "Waiting for a message to $mygid\n";
						msgrcv($id, $buf, 1024, $mygid,0);
						my ($type_rcvd, $txt) = unpack("l! a*", $buf);
						print CLIENT $txt;
						print "Sent $txt to the client ($mygid)\n" if $DEBUG;
					}
				}else{
					my $line;

					while(not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT)){
						$line = <CLIENT>;
						if(defined $line and length $line){
							msgsnd($id, pack("l! l! a*", $send_type, $mygid, $line), 0);
						}
					}
				}
			} elsif ($node_type eq "V"){
				if($w){
					undef $buf;
					undef $line;

					while(not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT)){
						#print "Waiting for a message to $mygid\n";
						msgrcv($id, $buf, 1024, $mygid,0);
						my ($type_rcvd, $txt) = unpack("l! a*", $buf);
						print CLIENT $txt;
						print "Sent $txt to the client ($mygid)\n" if $DEBUG;
					}
				}else{
					my $line;

					while(not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT)){
						$line = <CLIENT>;
						if(defined $line and length $line){
							msgsnd($id, pack("l! l! a*", $stdin_viewer_type, $mygid, $line), 0);
						}
					}
				}
			}
		}
		print "bye\n";
	}
} else {

	if($DEBUG){
		print "Testing receiving\n";
		msgrcv($id, $buf, 1024, $type_sent, 0) or die "Recieve Failed";
		my ($t1, $t2) = unpack("l! l!", $buf);
		print "Message queue " . ($t1 eq $t2 ? "OK"  : "BAD") . "\n";
	}
	my $abuf;
	my $tbuf;
	my $vabuf;
	my $vrbuf;
	my $lbuf;
	my %nodes;
	my %nodes2;
	my %viewers;
	my %viewers2;
	my $im_done = 0;
	my %output;
sub stdin_parse {
			my $out = "";
			my $line =shift;
			print "GOT: $line" if $DEBUG;
			if($line =~ /^p\s+(.*)/){
				$line = $1;
				if($line =~ /list_hosts/){
					$out .= "Count: " . (length keys %nodes) . "\n";
					foreach my $n (keys %nodes){
						$out .= "rid: $n\n";
					}
				}elsif($line =~ /quit/){
					$im_done = 1;
				} elsif($line =~ /copy/){
					open(COPYF, "gpl-3.0.txt");
					$out .= join "", <COPYF>;
					close(COPYF);
				} elsif($line =~ /warranty/){
					$out = "  15. Disclaimer of Warranty.

  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM \"AS IS\" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. Limitation of Liability.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.\n";
				}
			} else {
				my ($mach, $text) =  split(/ /, $line, 2);
				if(not $mach =~ /(a|\d+)/){
					$out .= " $mach is not a valid host!\n ";
					$out .= (length $mach)."\n";
				}else{
					if($mach eq "a"){
						foreach my $k (keys %nodes){
							print "Sending  $text  to " . $nodes{$k} . "\n" if $DEBUG;
							msgsnd($id, pack("l! a*", $nodes{$k}, $text), 0);
						} 	
					} else {
						my $h = $nodes{$mach};
						msgsnd($id, pack("l! a*", $h, $text), 0);
					}
				}
			}
	return $out;
}

	for(;not $im_done;
		msgrcv($id, $abuf, 1024, $add_type, IPC_NOWAIT),
		msgrcv($id, $vabuf, 1024, $add_viewer_type, IPC_NOWAIT),
		msgrcv($id, $vrbuf, 1024, $stdin_viewer_type, IPC_NOWAIT),
		msgrcv($id, $tbuf, 1024, $send_type, IPC_NOWAIT),
		msgrcv($id, $lbuf, 1024, $stdin_type, IPC_NOWAIT),
	){
		if(defined $lbuf and length $lbuf){
			my($t, $line) = unpack("l! a*", $lbuf);
			print stdin_parse($line);
			undef $lbuf;
		}
		if(defined $vrbuf and length $vrbuf){
			my($t, $viewer, $line) = unpack("l! l! a*", $vrbuf);
			$line = $viewers2{$viewer} . " ".  $line if not $line =~ /^[p|a|\d+]\s+/ ;
			my $out = stdin_parse($line);
			msgsnd($id, pack("l! a*", $viewer, $out), 0);
			undef $vrbuf;
		}
		if(defined $abuf and length $abuf){
			my($t, $rpid, $rid, $mygid) = unpack("l! l! l! l!", $abuf);
			my %h;
			$h{"mygid"}=$mygid;
			$h{"rpid"}=$rpid;
			$h{"rid"}=$rid;	
			print "Adding node: $rid ($mygid)\n";
			$nodes{$rid} = $mygid;#\&h;
			$nodes2{$mygid} = $rid;#\&h;
			undef $abuf;
		}
		if(defined $vabuf and length $vabuf){
			my($t, $rpid, $rid, $mygid) = unpack("l! l! l! l!", $vabuf);
			my %h;
			$h{"mygid"}=$mygid;
			$h{"rpid"}=$rpid;
			$h{"rid"}=$rid;	
			print "Adding viewer: $rid ($mygid)\n";
			$viewers{$rid} = $mygid;#\&h;
			$viewers2{$mygid} = $rid;#\&h;
			undef $vabuf;
		}
		if(defined $tbuf and length $tbuf){
			my($t, $rid, $msg) = unpack("l! l! a*", $tbuf);
			$rid = $nodes2{$rid};
			if( not defined $output{$rid}){
				$output{$rid}[0] = $msg;
			} else {
				push @{$output{$rid}}, $msg;
			}
			if(defined $viewers{$rid}){
				msgsnd($id, pack("l! a*", $viewers{$rid}, $msg), 0);
			}
			print "$rid $msg";
			undef $tbuf;
		}
		
	}
	msgsnd($id, pack("l!", $kill_type), 0);
	print "Bye2\n";
}

wait();
close CLIENT; 
msgctl($id, IPC_RMID, 0) || die "# msgctl failed: $!\n";
