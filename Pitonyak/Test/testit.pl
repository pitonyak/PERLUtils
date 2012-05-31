#!/usr/bin/perl -w
#************************************************************

=head1 NAME

Generate file lists

=head1 SYNOPSIS

=head1 COPYRIGHT

Copyright 1998-2012, Andrew Pitonyak

I Andrew Pitonyak wrote this code for my own use and I own it.
That said, you may do as you desire with this code. Use it,
change it, whatever, just don't claim that it is your own.

Also, what ever you do with the code is your own problem.
Although many of my libraries are in production use, I make
no claims to usability, suitability, or reliability.

Although you may do as you desire with the code, I do
appreciate knowing what was done with my code and
interesting changes made by you may be incorporated into
my own copies if you provide them to me.

=head1 DESCRIPTION

Test the command line processor. This file, testit.pl, assumes that the file testit.cfg is in the same diretory.
The file testit.cfg specifies the arguments that can be used with this program.
The argument "s" has an associated method attached to it named "set_recursion", so, C<< perl -w tesit.pl -s=1 >> causes set_recursion to be called with the value 1.

=cut

#************************************************************

use strict;
use IO::File;
use File::Basename;
use File::stat;
use Pitonyak::ConfigFileParser;
use Pitonyak::CommandLineProcessor;
use Pitonyak::ADPLogger;

my $cfg = new Pitonyak::ConfigFileParser();
my $log = new Pitonyak::ADPLogger();
my $cmd = new Pitonyak::CommandLineProcessor();

my %global_args = (
    's'      => 0,
    'docs'   => 0,
    'html'   => 0,
);

sub initialize_global_variables
{
  my @suffixlist = ('.pl', '.PL', '.pm', '.PM');
  my $dir_name = File::Basename::dirname($0);
  my $base_name = File::Basename::basename($0);
  my $name = fileparse($0, @suffixlist);
  my $property_file_name = "$dir_name/$name.cfg";

  if (not -f $property_file_name)
  {
    die "Unable to find $property_file_name";
  }
  $cfg->read_config_file($property_file_name);
  $log->configure($cfg);
  $log->log_name($name);
  $log->info("starting $0 with configuration $property_file_name");
  $cmd->configure($cfg);
}

sub parse_argument
{
  my $arg_name = shift;
  my $method_name = shift;
  my $arg_value = shift;

  #podchecker.bat
  if (defined($arg_value) && (-f $arg_value))
  {
  }

}

sub set_recursion
{
  my $arg_name = shift;
  my $method_name = shift;
  my $arg_value = shift;
  print "Processing $arg_name in $method_name and argument value '$arg_value'\n";
}

sub parse_arguments
{
  $cmd->process_args($log, @_);
  my ($arg_name, $arg_value, $call_name);
  foreach my $arg_ref ($cmd->get_processed_args())
  {
    ($arg_name, $arg_value, $call_name) = @{$arg_ref};
    if (defined($call_name) && $call_name ne '')
    {
      print "call name = $call_name\n";
      no strict 'refs';
      if (!defined(*$call_name{CODE}))
      {
        $log->error("Routine not found $call_name");
      }
      else
      {
          #
          # Not only is the code defined, but it is defined in parms
          # so I know that the section is not turned off
          # Call the code with the name held in $_
          # Note that this is only called if the name of the routine
          # contains the text 'log' or if the paramter 'part_log_only'
          # is not set.
          #
          &$call_name($arg_name, $call_name, $arg_value);
      }
      use strict 'refs';
    }
  }
}

sub CallMePlease()
{
  print "I am in the subroutine named CallMePlease\n";
}

my $callName = 'CallMePlease';

initialize_global_variables();
parse_arguments(@ARGV);

#foreach my $arg (@ARGV)
#Never finished writing the code past this point, so, ignore it.

no strict 'refs';
if (!defined(*$callName{CODE})) {

  #print "As expected, Routine not found $callName \n";

}
else
{
    #
    # Not only is the code defined, but it is defined in parms
    # so I know that the section is not turned off
    # Call the code with the name held in $_
    # Note that this is only called if the name of the routine
    # contains the text 'log' or if the paramter 'part_log_only'
    # is not set.
    #
    &$callName;
}

# $cmd->parse_args($callName, 'abc', @ARGV);
