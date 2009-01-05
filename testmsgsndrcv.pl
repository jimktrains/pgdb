#!/usr/bin/perl -w
use IPC::SysV qw(IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR);

my $id = msgget(IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR);
die ":(" unless defined $id;
my $sent = "message";
my $sent2 = "Hello";
my $type = 1234;
my $type2 = 2345;
my $rcvd;
my $rcvd2;
msgsnd($id, pack("l! a*", $type, $sent), 0);
msgsnd($id, pack("l! a*", $type2, $sent2), 0);
msgrcv($id, $rcvd2, 60, $type, 0);
msgrcv($id, $rcvd, 60, $type2, 0);
($type, $rcvd) = unpack("l! a*", $rcvd);
($type2, $rcvd2) = unpack("l! a*", $rcvd2);
print "$rcvd\n$rcvd2\n";
msgctl($id, IPC_RMID, 0) || die "# msgctl failed: $!\n";
