#! /usr/bin/perl -w 
# server0.pl 
#-------------------- 

use strict; 
use Socket; 
use IPC::SysV qw(IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR);

# use port 7890 as default 
my $port = shift || 7890; 
my $proto = getprotobyname('tcp'); 
my $id = msgget(IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR);

my $sent = "message";
my $type_sent = 1234;
my $rcvd;
my $type_rcvd;

die "# msgsnd failed\n" unless defined $id;

#create a socket, make it reusable 
socket(SERVER, PF_INET, SOCK_STREAM, $proto) or die "socket: $!"; 
setsockopt(SERVER, SOL_SOCKET, SO_REUSEADDR, 1) or die "setsock: $!"; 

# grab a port on this machine 
my $paddr = sockaddr_in($port, INADDR_ANY);

# bind to a port, then listen 
bind(SERVER, $paddr) or die "bind: $!"; 
listen(SERVER, SOMAXCONN) or die "listen: $!"; 
print "SERVER started on port $port "; 
my $add_type = 1;
my $send_type = 2;
# accepting a connection 
my $client_addr; 
if(my $pid = fork()){
		my $mygid = 10;
		while ($client_addr = accept(CLIENT, SERVER)){ 
			last if fork();
			$mygid++;
		}
		my $line = <CLIENT>;
		my ($rpid, $rid, $rhost) = split($line, ":");
		my $buf;
		undef $buf;
		undef $line;
		msgsnd($id, pack("l! l! l! l!", $add_type, $mygid, $rpid, $rid), 0));
		while ($line = <CLIENT> or msgrcv($id, $buf, 1024, $mygid, 0)){
			if(defined $line){
				chomp $line;
				msgsnd($id, pack("l! l! a*", $send_type, $mygid, $line), 0));
			}
			if(defined $buf){
				my ($type_rcvd, $text) = unpack("l! a*", $buf);
				print CLIENT $text;
				last if($text eq "quit");
			}
			undef $buf;
			undef $line;
		}
	
	}
} else {
	my $abuf;
	my $tbuf;
	my $line;
	my %nodes = {};
	undef $line;
	undef $abuf;
	undef $tbuf;
	while(my $line = <STDIN> or msgrcv($id, $abuf, 1024, $add_typ, 0) or msgrcv($id, $tbuf, 1024, $send_type, 0)){
		if(defined $line){
			($mach, $text) =  split(//, $line, 2);
			print " '$mach' is not a valid host!\n " unless $mach =~ /(a|\d+)/;
			if($mach eq "a"){
				while ( my ($host, $h) = each(%nodes) ){
					msgsnd($id, pack("l! a*", $h->{gid}, $text), 0);
				} 	
			} else {
				$h = %hosts->{$mach};
				msgsnd($id, pack("l! a*", $h->{gid}, $text), 0);
			}
		}
		if(defined $abuf){
			my($t, $gid, $rpid, $rid) = unpack("l! l! l! l!", $abuf);
			my %h = {"gid" => $gid, "rpid" => $rpid, "rid" => $rid};	
			%nodes->{$rid} = \&h;
		}
		if(defined $tbuf){
			my($t, $gid, $msg) = unpack("l! l! a*", $abuf);
			print "$gid $msg\n";
		}
		
		undef $abuf;
		undef $tbuf;
		undef $line;
	}
}

wait();
close CLIENT; 
msgctl($id, IPC_RMID, 0) || die "# msgctl failed: $!\n";
