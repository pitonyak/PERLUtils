#!/usr/bin/perl -w
use strict;

#
# I wrote these tests as quick and dirty tests to see how things looked visually.
# Would be better to write these as normal unit tests to report pass / fail rather than requiring a visual inspection.
#

use Pitonyak::StringUtil qw(smart_printer_default);
my %hash2 = ('a' => 'A', 'b' => 'B');
my @strings = ('123456789', '123', \%hash2);
my %hash1 = ('one' => 1, 'two' => 2, 'ary' => \@strings);
print smart_printer_default(\%hash1);
print "*****\n";
use Pitonyak::StringUtil qw(array_width right_fmt);
@strings = ('one', 'two', 'three', 'four');
foreach (right_fmt(array_width(@strings), @strings)) {
  print "$_\n";
}
print "*****\n";
use Pitonyak::StringUtil qw(center_fmt);
my $long_str = 'I am really long';
@strings = ('one', 'two', 'three', 'four');
foreach (center_fmt(8, @strings, $long_str)) {
  print "$_\n";
}
print "*****\n";
use Pitonyak::StringUtil qw(compact_space);
my $test_str = '  one  two  ';
compact_space($test_str);
print "($test_str)\n";

print "*****\n";
use Pitonyak::StringUtil qw(hash_key_width right_fmt);
my %map = ('one'=>1, 'two'=> 2, 'three'=>3, 'four'=>4);
my $width = hash_key_width(%map);
while ( my ($key, $value) = each(%map) ) {
  print right_fmt($width, $key)." => $value\n";
}

print "*****\n";
use Pitonyak::StringUtil qw(hash_key_width left_fmt);
%map = ('one'=>1, 'two'=> 2, 'three'=>3, 'four'=>4);
$width = hash_key_width(%map);
while ( my ($key, $value) = each(%map) ) {
  print left_fmt($width, $key)." => $value\n";
}

print "*****\n";
use Pitonyak::StringUtil qw(num_int_digits right_fmt);
my @numbers = (7, '00554', '+32', '-677', '123.456', 3.1415, 1.9e23);
foreach my $num (@numbers) {
  print right_fmt(9, $num)." = ".num_int_digits($num)." = ".right_fmt(9, 0+$num)." = ".right_fmt(4, sprintf( "%d", $num ))."\n"; <br/>
}

print "*****\n";
use Pitonyak::StringUtil qw(num_with_leading_zeros);
@numbers = (7, '00554', '+32', '-677', '123.456', 3.1415, 1.9e23, 1234567);
foreach my $num (@numbers) {
  print num_with_leading_zeros(-5, $num)." <= $num\n";
}
print "*****\n";

print "*****\n";
