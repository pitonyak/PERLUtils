#!/usr/bin/perl -w
use strict;

use Pitonyak::DeepCopy qw(deep_copy);

#
# Test to see if deep copy works.
# Assign hash1 to hash2.
# Modify hash2.
# Deep copy hash1 to hash3.
# Modify hash3.
# 
#

# Set $hash1 to reference a hash.
my %hash1;
$hash1{'tens'} = {};
$hash1{'tens'}->{'10'} = 'ten';
$hash1{'1'} = 'one';

my %hash2=%hash1;
$hash2{'1'} = 'ONE';
$hash2{'tens'}->{'10'} = 'TEN';

my %hash3=%{Pitonyak::DeepCopy::deep_copy(\%hash1)};
$hash3{'1'} = 'oNe';
$hash3{'tens'}->{'10'} = 'tEn';

#
# Prints
# ****   1=one or ONE or oNe
# ****  10=TEN or TEN or tEn
#
# This shows that the top level of hash1 is copied by value in all cases.
# Hash1 contains a reference to another hash (in 10).
# On assignment, hash2 and hash1 reference the same hash.
# For the deep copy, however, hash3 references its own copy, so changing it does not the copy referenced in hash1 or hash2.
#
print " 1=$hash1{1} or $hash2{1} or $hash3{1}\n";
print "10=$hash1{tens}->{10} or $hash2{tens}->{10} or $hash3{tens}->{10}\n";

my $x = {};
my %x;

print "test1 ".UNIVERSAL::isa( $x, 'HASH' )."\n";
#print %x->can( 'isa' )."\n";
#print "value = ".HASH->isa( $x, 'HASH' )."\n";

