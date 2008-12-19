#!/usr/bin/perl -w

use IPC::Open2;

my($rdrfh, $wtrfh);
my $pid = open2($rdrfh, $wtrfh, 'cat');
$a = <STDIN>;
print "a: $a\n";

print $wtrfh $a;

$b = <$rdrfh>;

print "b: $b\n";
