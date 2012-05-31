#!/usr/bin/perl -w
use strict;

use Pitonyak::XMLUtil qw(
  convert_entity_references_to_characters
  convert_xml_characters_to_entity_references
  object_to_xml
  xml_to_object
);

use Pitonyak::SafeGlob qw(glob_spec_from_path);
my $glob    = new Pitonyak::SafeGlob();
my %hash1 = (
  'tens' => {'10' => 'ten'},
  '1' => 'one',
  '2' => [0, 1, 2, 3],
);

$glob->new();

my $xml = Pitonyak::XMLUtil::object_to_xml(\%hash1);
print $xml."\n\n";
my $hash_ref = Pitonyak::XMLUtil::xml_to_object($xml);
my $xml_2 = Pitonyak::XMLUtil::object_to_xml($hash_ref);
print $xml_2."\n";
print Pitonyak::XMLUtil::object_to_xml([1, \%hash1])."\n";
my $x = Pitonyak::XMLUtil::xml_to_object(Pitonyak::XMLUtil::object_to_xml([1, \%hash1]));
print $x->[1]->{'1'};


my $x = "hello";
my $y = \$x;
print ref($y) || $y;

my @a;
print "empty array ".scalar(@a)."\n";
push @a, 1;
print "array with 1 element ".scalar(@a)."\n";
push @a, 1;
print "array with 2 elements ".scalar(@a)."\n";
