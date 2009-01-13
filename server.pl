#!/usr/bin/perl -w 

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
