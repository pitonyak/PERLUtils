#!/usr/bin/perl -w

use strict;

use Pitonyak::SafeGlob;

my @full_specs = ('c:\*.txt', 'C:\Andy\Dev\Perl\Pitonyak\*.p?');
my @file_specs = ('*.pl', '*.pm');
my @file_regs  = ('.*\.pl$', '.*\.pm$');
my @files;

my $g = new Pitonyak::SafeGlob;

$g->case_sensitive(1);
$g->return_dirs(0);
$g->return_files(1);
foreach ($g->glob_spec_from_path(@full_specs))
{
  # Full path to file returned.
  print "spec from path => $_\n";
}

foreach ($g->glob_spec('c:\Andy\Dev\Perl\Pitonyak', @file_specs))
{
  print "glog_spec => $_\n";
}

foreach ($g->glob_regex('c:\Andy\Dev\Perl\Pitonyak', @file_regs))
{
  print "glog_regex => $_\n";
}
