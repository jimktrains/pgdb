#!/usr/bin/perl -w 

use strict; 
use Socket; 
use IPC::SysV qw(IPC_NOWAIT IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR);
use IO::Handle;
use Fcntl;

# use port 7890 as default 
my $port = shift || 7890; 
my $proto = getprotobyname('tcp'); 
my $id = msgget(IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR);

my $sent = "message";
my $type_sent = 1234;
my $rcvd;
my $type_rcvd;
my $buf;
die "message queue id not defined\n" unless defined $id;

print "message queue id: $id\n";
print "Testing message queue\n";
msgsnd($id, pack("l! l!", $type_sent, $type_sent), 0) or die "Send failed";
print "Sent OK\n";
msgrcv($id, $buf, 1024, $type_sent, 0) or die "Recieve Failed";
my ($t1, $t2) = unpack("l! l!", $buf);
print "Message queue " . ($t1 eq $t2 ? "OK"  : "BAD") . "\n";


#create a socket, make it reusable 
socket(SERVER, PF_INET, SOCK_STREAM, $proto) or die "socket: $!"; 
setsockopt(SERVER, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsock: $!"; 

# grab a port on this machine 
my $paddr = sockaddr_in($port, INADDR_ANY);

# bind to a port, then listen 
bind(SERVER, $paddr) or die "bind: $!"; 
listen(SERVER, SOMAXCONN) or die "listen: $!"; 
print "SERVER started on port $port\n"; 
# Add's the node to the list
my $add_type = 1;

# Node is sending a message
my $send_type = 2;
my $stdin_type = 3; 
my $kill_type = 4;
# accepting a connection 
my $client_addr; 
if(not fork()){
	my $mygid = 10;
	my $dead = 0;
	print "Testing Sending\n";
	msgsnd($id, pack("l! l!", $type_sent, $type_sent), 0) or die "Send failed";
	print "Sent OK\n";
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
		for(;
				not ($dead = msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT))
				and accept(CLIENT, SERVER) 
			;$mygid++){ 
			last if fork();
			$w = 1;
			last if fork();
			$w = 0;
		}
		if(not $dead){
			if($w){
				print "Testing Sending\n";
				msgsnd($id, pack("l! l!", $type_sent, $type_sent), 0) or die "Send failed";
				print "Sent OK\n";

				CLIENT->autoflush(1);
				print CLIENT "VER 1 PGDB-JK\n";

				my $line = <CLIENT>;
				print $line;
				print "huh\n";
				#remote pid : remote mpi id : remote hostname
				my ($rpid, $rid, $rhost) = split(/:/, $line);

				my $buf;
				undef $buf;
				undef $line;
				print "sending add\n";
				msgsnd($id, pack("l! l! l! l!", $add_type, $rpid, $rid, $mygid), 0);
				print CLIENT "Hello, $rid\n";
				print "sent greeting\n";
				$line = <CLIENT>;
			#	print "First line: $line";
			#	$line = <CLIENT>;
			#	print $line;
				my $flags = 0;
				#fcntl(CLIENT, F_GETFL, $flags) || die $!; # Get the current flags on the filehandle
				#$flags |= O_NONBLOCK; # Add non-blocking to the flags
				#fcntl(CLIENT, F_SETFL, $flags) || die $!; # Set the flags on the filehandle
				while(not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT)){
					$line = <CLIENT>;
					if(defined $line and length $line){
						msgsnd($id, pack("l! l! a*", $send_type, $rid, $line), 0);
					}
				}
			}else{
				while(not msgrcv($id, $kbuf, 24, $kill_type, IPC_NOWAIT)){
					print "Waiting for a message to $mygid\n";
					msgrcv($id, $buf, 1024, $mygid,0);
					my ($type_rcvd, $txt) = unpack("l! a*", $buf);
					print CLIENT $txt;
					print "Sent $txt to the client ($mygid)\n";
				}
			}
		}
		print "bye\n";
	}
} else {
	
	print "Testing receiving\n";
	msgrcv($id, $buf, 1024, $type_sent, 0) or die "Recieve Failed";
	my ($t1, $t2) = unpack("l! l!", $buf);
	print "Message queue " . ($t1 eq $t2 ? "OK"  : "BAD") . "\n";


	print "Testing receiving\n";
	msgrcv($id, $buf, 1024, $type_sent, 0) or die "Recieve Failed";
	($t1, $t2) = unpack("l! l!", $buf);
	print "Message queue " . ($t1 eq $t2 ? "OK"  : "BAD") . "\n";

	my $abuf;
	my $tbuf;
	my $lbuf;
	my %nodes;
	#while(defined($line = <>) or msgrcv($id, $abuf, 1024, $add_type, 0) or msgrcv($id, $tbuf, 1024, $send_type, 0)){
	#while(msgrcv($id, $tbuf, 1024, $send_type, 0) or msgrcv($id, $abuf, 1024, $add_type, 0)){
	for(;1;
		msgrcv($id, $abuf, 1024, $add_type, IPC_NOWAIT),
		msgrcv($id, $tbuf, 1024, $send_type, IPC_NOWAIT),
		msgrcv($id, $lbuf, 1024, $stdin_type, IPC_NOWAIT),
	){
	#while(defined($line = <>) or msgrcv($id, $abuf, 1024, $add_type, 0) or msgrcv($id, $tbuf, 1024, $send_type, 0)){
		if(length $lbuf){
			my($t, $line) = unpack("l! a*", $lbuf);
			print "GOT: $line";
			if($line =~ /^pgdb_/){
				if($line =~ /pgdb_list_hosts/){
					print "Count: " . (length keys %nodes) . "\n";
					foreach my $n (keys %nodes){
						print "rid: $n\n";
					}
				}
			} else {
				my ($mach, $text) =  split(/ /, $line, 2);
				if(not $mach =~ /(a|\d+)/){
					print " $mach is not a valid host!\n " 
				}else{
					if($mach eq "a"){
						foreach my $k (keys %nodes){
							print "Sending  $text  to " . $nodes{$k} . "\n";
							msgsnd($id, pack("l! a*", $nodes{$k}, $text), 0);
						} 	
					} else {
						my $h = $nodes{$mach};
						msgsnd($id, pack("l! a*", $h, $text), 0);
					}
				}
			}
			undef $lbuf;
		}
		if(length $abuf){
			my($t, $rpid, $rid, $mygid) = unpack("l! l! l! l!", $abuf);
			my %h;
			$h{"mygid"}=$mygid;
			$h{"rpid"}=$rpid;
			$h{"rid"}=$rid;	
			print "Adding node: $mygid\n";
			$nodes{$rid} = $mygid;#\&h;
			undef $abuf;
		}
		if(length $tbuf){
			my($t, $rid, $msg) = unpack("l! l! a*", $tbuf);
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
