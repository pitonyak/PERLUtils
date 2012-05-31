#!/usr/bin/perl -w

#
# Write a few log messages into a local log.
#

use strict;
use Pitonyak::SmallLogger;

my $log = new Pitonyak::SmallLogger();

sub blah()
{
  $log->debug("Debug 2");
}



# Do not use any time/date in the file name
$log->log_name_date('');
# send debug output to the screen
$log->screen_output('D', 1);
$log->debug("Debug 1");
$log->warn("Hello I Warn you");
$log->debug("Hello I debug you");
$log->info("Hello I info you");
$log->error("Hello I error you");
blah();
