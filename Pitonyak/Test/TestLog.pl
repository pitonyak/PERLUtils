#!/usr/bin/perl -w

#
# Simple test program to write a configuration file for an empty logger.
#

use strict;
use Pitonyak::SmallLogger;
my $log = new Pitonyak::SmallLogger();
$log->write_to_file("log_cfg.xml");
