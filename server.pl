#! /usr/bin/perl -w 
# server0.pl 
#-------------------- 

use strict; 
use Socket; 
use IPC::SysV qw(IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR);
use IO::Handle;

# use port 7890 as default 
my $port = shift || 7890; 
my $proto = getprotobyname('tcp'); 
my $id = msgget(IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR);

my $sent = "message";
my $type_sent = 1234;
my $rcvd;
my $type_rcvd;

die "# msgsnd failed\n" unless defined $id;
STDOUT->autoflush(1);
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

# accepting a connection 
my $client_addr; 
if(my $pid = fork()){
	my $mygid = 10;
	
	#http://www.bearcave.com/unix_hacks/perl/perl.htm
	#"however, apparently last cannot be used to exit while loops in perl" my experience too:(
	 
	for(;$client_addr = accept(CLIENT, SERVER);	$mygid++){ 
		last if fork();
	}

	print CLIENT "VER 1 PGDB-JK\n";
	CLIENT->autoflush;
	my $line = <CLIENT>;
	print $line;
	#remote pid : remote mpi id : remote hostname
	my ($rpid, $rid, $rhost) = split(/:/, $line);

	#if for some reason there is not mpi id, then set it to the fork's number
	#$rid = $mygid if $rid == -1;
	my $buf;
	undef $buf;
	undef $line;
	msgsnd($id, pack("l! l! l! l!", $add_type, $mygid, $rpid, $rid), 0);
	print CLIENT "Hello, $rid\n";
	while (defined($line = <CLIENT>) or msgrcv($id, $buf, 1024, $mygid, 0)){
		if(defined $line){
			chomp $line;
			msgsnd($id, pack("l! l! a*", $send_type, $mygid, $line), 0);
		}
		if(defined $buf){
			my ($type_rcvd, $text) = unpack("l! a*", $buf);
			print CLIENT $text;
			last if($text eq "quit");
		}
		undef $buf;
		undef $line;
	}
} else {
	my $abuf;
	my $tbuf;
	my $line;
	my %nodes;
	undef $line;
	undef $abuf;
	undef $tbuf;
	while(defined($line = <STDIN>) or msgrcv($id, $abuf, 1024, $add_type, 0) or msgrcv($id, $tbuf, 1024, $send_type, 0)){
		if(defined $line){
			print "% ";
			if($line =~ /^pgdb_/){
				if($line =~ /pgdb_list_hosts/){
					print "" . (length keys %nodes) . "\n";
					foreach (keys %nodes){
						print "gid: $_\n";
					}
				}
			} else {
				my ($mach, $text) =  split(//, $line, 2);
				if(not $mach =~ /(a|\d+)/){
					print " $mach is not a valid host!\n " 
				}else{
					if($mach eq "a"){
						while ( my ($host, $h) = each(%nodes) ){
							msgsnd($id, pack("l! a*", $h->{gid}, $text), 0);
						} 	
					} else {
						my $h = %nodes->{$mach};
						msgsnd($id, pack("l! a*", $h->{gid}, $text), 0);
					}
				}
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
