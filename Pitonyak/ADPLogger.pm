package Pitonyak::ADPLogger;

#************************************************************

=head1 NAME

Pitonyak::ADPLogger - Generate simple log messages to the screen and/or a log file.

The ADPLogger is wrtten such that it can be inherited.

Messages contain date and time information, a text string identifying the type,
the line number from which the message was logged, and the text of the message itself.

YYYY.MM.DD hh:mm:ss <type>:<line> <message>

Supported message types include ERR, WARN, INFO, DEBUG, and TRACE.

=head1 SYNOPSIS

=begin html
<p><code>
use Pitonyak::ADPLogger;              <br/><br/>
my $log = new Pitonyak::ADPLogger();  <br/>
# send debug output to the screen     <br/>
$log->log_path('./logs/');            <br/>
$log->log_name('TestLog');            <br/>
$log->max_size(10000);                <br/>
$log->max_logs(9);                    <br/>
# send debug output to the screen     <br/>
$log->screen_output('DEBUG', 1);      <br/>
$log->debug("Debug 1");               <br/>
$log->warn("Hello I Warn you");       <br/>
$log->debug(3, "Hello I debug you");  <br/>
$log->info("Hello I info you");       <br/>
$log->error("Hello I error you");     <br/>
</code></p>

=end html

=head1 DESCRIPTION

=cut

#************************************************************

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '1.02';
@ISA     = qw(Exporter);
@EXPORT  = qw(
);

@EXPORT_OK = qw(
  configure
  copy
  debug
  error
  fatal
  file_output
  get_class_attribute
  get_log_full_name
  info
  is_ok
  log_name
  log_path
  max_logs
  max_size
  new
  screen_output
  trace
  warn
  write_string_to_log
);

use Carp;
use IO::File;
use File::Basename;
use File::stat;
use strict;
use Pitonyak::DeepCopy qw(deep_copy);
use Pitonyak::ConfigFileParser;

my %initial_attributes = (
    'is_log_open'   => 0,    # Is the file open or not
    'is_ok'         => 1,    # Has an error occured?
    'log_name'      => 'logfile',
    'log_path'      => './',
    'max_size'      => 100000,
    'max_logs'      => 9,
    'screen_output' => { 'ERR' => 1, 'WARN' => 1, 'INFO' => 1, 'DEBUG' => 0, 'TRACE' => 0, 'FATAL' => 1 },
    'file_output' => { 'ERR' => 1, 'WARN' => 1, 'INFO' => 1, 'DEBUG' => 1, 'TRACE' => 0, 'FATAL' => 1 },
);

#************************************************************

=pod

=head2 configure

=over 4

=item C<< $log->configure(ConfigFileParser) >>

Configure the log object using a ConfigFileParser. A typical
configuration section to configure a ADPLogger is:

=begin html

<p><code>
log_name = FtpPoller&nbsp;&nbsp;&nbsp;&nbsp;    # The extension .log is appended automatically  <br/>
max_size = 100000&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;       # Limit the size to 100,000 characters          <br/>
max_logs = 9&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;            # Allow 9 rolling logs                          <br/>
log_path = ./logs/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;     # Assuming a relative path can be dangerous     <br/>
                                                                        <br/><br/>
# Send everything to the screen except trace messages                   <br/>
log_screen_output_err&nbsp;&nbsp;   = 1                                 <br/>
log_screen_output_fatal;   = 1                                          <br/>
log_screen_output_warn&nbsp;  = 1                                       <br/>
log_screen_output_info&nbsp;  = 1                                       <br/>
log_screen_output_debug = 0                                             <br/>
log_screen_output_trace = 0                                             <br/>
                                                                        <br/><br/>
# Send all messages except debug to the log file.                       <br/>
log_file_output_err&nbsp;&nbsp;&nbsp;&nbsp;     = 1                     <br/>
log_file_output_fatal&nbsp;&nbsp;     = 1                               <br/>
log_file_output_warn&nbsp;&nbsp;&nbsp;    = 1                           <br/>
log_file_output_info&nbsp;&nbsp;&nbsp;    = 1                           <br/>
log_file_output_debug&nbsp;&nbsp;   = 0                                 <br/>
log_file_output_trace&nbsp;&nbsp;   = 0                                 <br/>
</code></p>

=end html

Supported properties include:

=over 4

=item log_path

Passes the value associated with 'log_path' to C<< $log->log_path() >>.

=item log_name

Passes the value associated with 'log_name' to C<< $log->log_name() >>.

=item log_file_output_debug

Passes the configuration value associated with 'log_file_output_debug'
to C<< $log->file_output('DEBUG', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_file_output_err

Passes the configuration value associated with 'log_file_output_err'
to C<< $log->file_output('ERR', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_file_output_fatal

Passes the configuration value associated with 'log_file_output_fatal'
to C<< $log->file_output('FATAL', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_file_output_info

Passes the configuration value associated with 'log_file_output_info'
to C<< $log->file_output('INFO', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_file_output_trace

Passes the configuration value associated with 'log_file_output_trace'
to C<< $log->file_output('TRACE', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_file_output_warn

Passes the configuration value associated with 'log_file_output_warn'
to C<< $log->file_output('WARN', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_screen_output_debug

Passes the configuration value associated with 'log_screen_output_debug'
to C<< $log->screen_output('DEBUG', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_screen_output_err

Passes the configuration value associated with 'log_screen_output_err'
to C<< $log->screen_output('ERR', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_screen_output_fatal

Passes the configuration value associated with 'log_screen_output_fatal'
to C<< $log->screen_output('FATAL', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_screen_output_info

Passes the configuration value associated with 'log_screen_output_info'
to C<< $log->screen_output('INFO', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_screen_output_trace

Passes the configuration value associated with 'log_screen_output_trace'
to C<< $log->screen_output('TRACE', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item log_screen_output_warn

Passes the configuration value associated with 'log_screen_output_warn'
to C<< $log->screen_output('WARN', $value) >>.
The requested logging level, must be less than this value for a message
to be printed.

=item max_logs

Passes the value associated with 'max_logs' to C<< $log->max_logs() >>.

=item max_size

Passes the value associated with 'max_size' to C<< $log->max_size() >>.

=back

=back

=cut

#************************************************************

sub configure()
{
  my %arg_map = (
      'log_name'     => 'log_name',
      'max_log_size' => 'max_size',
      'max_logs'     => 'max_logs',
  );

  my %level_map = (
      'err'   => 'ERR',
      'fatal' => 'FATAL',
      'warn'  => 'WARN',
      'info'  => 'INFO',
      'debug' => 'DEBUG',
      'trace' => 'TRACE',
  );

  if ($#_ > 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ADPLogger' ) && UNIVERSAL::isa( $_[1], 'Pitonyak::ConfigFileParser' ))
  {
    my $key;
    my $value;
    my $full_key;
    my $log = shift;
    my $cfg = shift;
    foreach $key (keys %arg_map)
    {
      $value = $arg_map{$key};
      $log->{$value} = $cfg->get_value($key) if $cfg->contains_key($key);
    }

    $key = 'log_path';
    $log->log_path($cfg->get_value($key)) if $cfg->contains_key($key);

    foreach $key (keys %level_map)
    {
      $value = $level_map{$key};
      $full_key = 'log_screen_output_'.$key;
      $log->screen_output($value, $cfg->get_value($full_key)) if $cfg->contains_key($full_key);
      $full_key = 'log_file_output_'.$key;
      $log->file_output($value, $cfg->get_value($full_key)) if $cfg->contains_key($full_key);
    }

  }
  else
  {
    carp('ADPLogger::configure() must be called as $log->configure($cfg), where $cfg is of type ConfigFileParser');
  }
}

#************************************************************

=pod

=head2 copy

=over 4

=item C<< $log1->copy($log2) >>

Copy one ADPLogger into another

C<< $log1->copy($log2) >> is the same as C<< $log1 = $log2 >>.

Open file handels are closed before the copy is performed, and the file handle itself is not copied.

=back

=cut

#************************************************************

sub copy
{
  $_[0]->close_log();
  foreach my $key ( keys %initial_attributes )
  {
    if ( UNIVERSAL::isa( $_[1]->{$key}, 'HASH' ) )
    {
      # If I simply copy it over then we both reference the same thing!
      $_[0]->{$key} = deep_copy( $_[1]->{$key} );
    }
    else
    {
      $_[0]->{$key} = $_[1]->{$key};
    }
  }
}

#************************************************************

=pod

=head2 file_output

Each message has a type.
Supported message types include ERR, WARN, INFO, DEBUG, and TRACE.

=over 4

=item C<< ADPLogger::file_output() >>

Return the default hash of values used for logging output to a file.

=item C<< $log->file_output() >>

Return the current hash of values used for logging output to a file.
For example:
C<< $log->file_output('ERR') >> returns 1 if ERR output is logged to the file,
and 0 if it is not. This is the same as C<< $log->file_output()->{'ERR'} >>.

=item C<< $log->file_output(\%hash) >>

Use the hash reference to configure logging output to a file.

=item C<< $log->file_output($message_type) >>

Returns the output value for the specified C<$message_type>. For example:
C<< $log->file_output('ERR') >> returns 1 if ERR output is logged to the file,
and 0 if it is not. This is the same as C<< $log->file_output()->{'ERR'} >>.

=item $obj->file_output($message_type, $message_value)

Sets and then returns the output value for the specified C<$message_type>.
For example:
C<< $log->file_output('ERR', 1) >> causes ERR output to be logged to the file and
it returns the value 1 because the value was set to 1. The same can be accomplished
using C<< $log->file_output()->{'ERR'} = 1 >>.

=back

=cut

#************************************************************

sub file_output
{
  return $initial_attributes{'file_output'} if $#_ < 0;
  return $_[0]->{'file_output'} if $#_ == 0;
  if ( UNIVERSAL::isa( $_[1], 'HASH' ) )
  {
    $_[0]->{'file_output'} = deep_copy( $_[1] );
    return $_[1];
  }
  else
  {
    if ( $#_ > 1 )
    {
      $_[0]->{'file_output'}->{ $_[1] } = $_[2];
    }
    return $_[0]->{'file_output'}->{ $_[1] };
  }
}

#************************************************************

=pod

=head2 get_class_attribute

The get_class_attribute method utilizes the fact that
C<< $obj->method(@parms) >> is the same as
C<< method($obj, @parms) >>. This method does not perform type checking
to verify that this is true.

The C<get_class_attribute> method is rarely called directly.

=over 4

=item C<< ADPLogger::get_class_attribute($attribute_name) >>

With only one paramter, the first parameter is
assumed to be an attribute name and the default attribute value
is returned.

=item C<< $obj->get_class_attribute($attribute_name) >>

With two arguments, the first is assumed
to be a C<ADPLogger> object and the second is
assumed to be an attribute name.
The attribute value for the object is returned.


=item C<< $obj->get_class_attribute($attribute_value, $attribute_name) >>

With three arguments, the first is assumed to be the object,
the second is a new attribute value, and the third is the attribute
name to set. Although the order seems odd, this is intentional.

Consider the method C<< is_ok >> defined as C<< return get_class_attribute( @_, 'is_ok' ); >>

Remember that C<@_> refers to the argument list passed to the method. In all cases, the last argument
passed to C<get_class_attribute> is the attribute name. If the method is called directly,
this is the only argument.

=back

=cut

#************************************************************

sub get_class_attribute
{
  return $initial_attributes{ $_[0] } if $#_ == 0;
  return $_[0]->{ $_[1] } if $#_ == 1;
  $_[0]->{ $_[2] } = $_[1];
  return $_[1];
}

#************************************************************

=pod

=head2 get_log_full_name

=over 4

=item C<< $log->get_log_full_name() >>

Build and return the full path to the log file. Remember that C<< $log->log_path() >>
returns a string with a trailing '/', so the value returned is equivalent to:

C<< $log->log_path().$log->log_name().'.log'  >>

=back

=cut

#************************************************************

sub get_log_full_name()
{
  return $_[0]->{'log_path'}.$_[0]->{'log_name'}.'.log';
}

#************************************************************

=pod

=head2 is_ok

=over 4

=item C<< $log->is_ok() >>

Return 1 if the log file is considered OK, and 0 otherwise.
If a value of 0 is returned, then no output will be sent to
the file.

=item C<< $log->is_ok(0|1) >>

Set the state of the log file to OK (1), or not OK (0).
The value is usually not set externally, but rather, it is set
automatically when the file is opened or closed.

=back

=cut

#************************************************************

sub is_ok
{
  return get_class_attribute( @_, 'is_ok' );
}

#************************************************************

=pod

=head2 Log Methods

All output methods accept a single string argument,
which is written to the log file or the screen depending
on the type and configuration. In all cases, a 1 is returned
if the method is successful, and 0 otherwise.

=head3 debug

=over 4

=item C<< $log->debug($message) >>

Write a message with log level one of type 'DEBUG' using C<< write_log() >>.

=item C<< $log->debug($log_level, $message) >>

Write a message with the specified log level of type 'DEBUG' using C<< write_log() >>.

=back

=cut

#************************************************************

sub debug
{
  my $obj = shift;
  return $obj->write_log( 'DEBUG', 1, @_ ) if $#_ <= 0;
  return $obj->write_log( 'DEBUG', @_ );
}

#************************************************************

=pod

=head3 error

=over 4

=item C<< $log->error($message) >>

Write a message with log level one of type 'ERR' using C<< write_log() >>.

=item C<< $log->error($log_level, $message) >>

Write a message with the specified log level of type 'ERR' using C<< write_log() >>.

=back

=cut

#************************************************************

sub error
{
  my $obj = shift;
  return $obj->write_log( 'ERR', 1, @_ ) if $#_ <= 0;
  return $obj->write_log( 'ERR', @_ );
}

#************************************************************

=pod

=head3 fatal

=over 4

=item C<< $log->fatal($message) >>

Write a message with log level one of type 'FATAL' using C<< write_log() >> and then die.

=item C<< $log->fatal($log_level, $message) >>

Write a message with the specified log level of type 'FATAL' using C<< write_log() >>.

=back

=cut

#************************************************************

sub fatal
{
  my $obj = shift;
  if ($#_ <= 0)
  {
    $obj->write_log( 'FATAL', 1, @_ );
  }
  else
  {
    $obj->write_log( 'FATAL', @_ );
  }
  exit -1;
}



#************************************************************

=pod

=head3 info

=over 4

=item C<< $log->info($message) >>

Write a message with log level one of type 'INFO' using C<< write_log() >>.

=item C<< $log->info($log_level, $message) >>

Write a message with the specified log level of type 'INFO' using C<< write_log() >>.

=back

=cut

#************************************************************

sub info
{
  my $obj = shift;
  return $obj->write_log( 'INFO', 1, @_ ) if $#_ <= 0;
  return $obj->write_log( 'INFO', @_ );
}


#************************************************************

=pod

=head3 trace

=over 4

=item C<< $log->trace($message) >>

Write a message with log level one of type 'TRACE' using C<< write_log() >>.

=item C<< $log->trace($log_level, $message) >>

Write a message with the specified log level of type 'TRACE' using C<< write_log() >>.

=back

=cut

#************************************************************

sub trace
{
  my $obj = shift;
  return $obj->write_log( 'TRACE', 1, @_ ) if $#_ <= 0;
  return $obj->write_log( 'TRACE', @_ );
}

#************************************************************

=pod

=head3 warn

=over 4

=item C<< $log->warn($message) >>

Write a message with log level one of type 'WARN' using C<< write_log() >>.

=item C<< $log->warn($log_level, $message) >>

Write a message with the specified log level of type 'WARN' using C<< write_log() >>.

=back

=cut

#************************************************************

sub warn
{
  my $obj = shift;
  return $obj->write_log( 'WARN', 1, @_ ) if $#_ <= 0;
  return $obj->write_log( 'WARN', @_ );
}

#************************************************************

=pod

=head3 write_string_to_log

Write a string directly to the log file and do not format the string in any
way. One might argue that this is dangerous.

=over 4

=item C<< $log->write_string_to_log($to_screen, $to_file, $message) >>

Write the C<$message> to the screen if C<$to_screen> evaluates to true.

Write the C<$message> to the file if C<$to_file> evaluates to true.

Return 1 if successful, 0 otherwise.

=back

=cut

#************************************************************

sub write_string_to_log
{
  my $rv = 1;

  # Write the message (arg 3) to the screen if arg 1 is 1.
  print "$_[3]\n" if $_[1];

  # If the second argument is 1, then write to the file.
  if ( $_[2] && $_[0]->{'is_ok'})
  {
    if ( $_[0]->open_log() )
    {
      $_[0]->{'log_handle'}->print("$_[3]\n");
      $_[0]->close_log();
    }
    else
    {
      $rv = 0;
    }
  }

  return $rv;
}

#************************************************************

=pod

=head2 log_name

The log_name is the base log name without the '.log' file extension.
The full log name is built by concatinating log_path, log_name, and '.log';

=over 4

=item C<< log_name() >>

Return the default base log file name.

=item C<< $log->log_name() >>

Return the base log file name for the log object.

=item C<< $log->log_name(base_name) >>

Set the base log file name, used for the next log output.
Do not include a file extension, because '.log' is automatically added.

=back

=cut

#************************************************************

sub log_name
{
  return get_class_attribute( @_, 'log_name' );
}

#************************************************************

=pod

=head2 log_path

The log_path identifies the directory containing the log file.
The full log name is built by concatinating log_path, log_name, and '.log';

=over 4

=item C<< log_path() >>

Return the default path during initialization, which is './'.

=item C<< $log->log_path() >>

Return the the path to the current log file.

=item C<< $log->log_path(path) >>

Set the path for the log file, which will be used for the next log output.
If the provided path does not contain '/' or '\', then '/' is appended to
to the path. The path itself is not checked for validity.

If the provided path is an empty string, then the path is set to the
default value.

=back

=cut

#************************************************************

sub log_path
{
  # If zero arguments, return the initial value.
  return $initial_attributes{ 'log_path' } if $#_ < 0;

  # If one argument, assume the object is correct and return
  # the current path.
  return $_[0]->{ 'log_path' } if $#_ == 0;

  my $obj = shift;
  my $value = shift;

  if ($value =~ /[\/\\]$/)
  {
    $obj->{ 'log_path' } = $value;
  }
  elsif ($value eq '')
  {
    $obj->{ 'log_path' } = $initial_attributes{ 'log_path' };
  }
  else
  {
    $obj->{ 'log_path' } = $value.'/';
  }

  return $obj->{ 'log_path' };
}

#************************************************************

=pod

=head2 max_logs

When the maximum log file size is exceeded, filename.log is
renamed to filename.log.1 before more text is written to filename.log.
The max_logs argument sets the maximum number of "rolled" log files.
So, setting this to 2 allows for filename.log.1 and filename.log.2.

=over 4

=item C<< $log->max_logs() >>

Return the maximum number of logs when the log files are rolled.

=item C<< $log->max_logs(max number of rolled logs) >>

Set the maximum number of logs when the log files are rolled.

=back

=cut

#************************************************************

sub max_logs
{
  return get_class_attribute( @_, 'max_logs' );
}

#************************************************************

=pod

=head2 max_size

Maximum size for each log file. This value is checked before
a new message is written to the file. If the file is too large,
then the file is rolled into filename.log.1 and a new file is started.

=over 4

=item C<< $log->max_size() >>

Return the current maximum size.

=item C<< $log->max_size(max desired log size) >>

Set the maximum file size.

=back

=cut

#************************************************************

sub max_size
{
  return get_class_attribute( @_, 'max_size' );
}

#************************************************************

=pod

=head2 new

=over 4

=item C<< $log2 = $log1->new() >>

Generate a new copy of a log object.

=back

=cut

#************************************************************

sub new
{
  my $self = shift;
  my $objref = bless {}, ref($self) || $self;
  $objref->initialize();
  if ( ref($self) )
  {
    $objref->copy($self);
  }
  return $objref;
}

#************************************************************

=pod

=head2 screen_output

Each message has a type.
Supported message types include ERR, WARN, INFO, DEBUG, and TRACE.

=over 4

=item C<< ADPLogger::screen_output() >>

Return the default hash of values used for logging output to a file.

=item C<< $log->screen_output() >>

Return the current hash of values used for logging output to a file.
For example:
C<< $log->screen_output('ERR') >> returns 1 if ERR output is logged to the file,
and 0 if it is not. This is the same as C<< $log->screen_output()->{'ERR'} >>.

=item C<< $log->screen_output(\%hash) >>

Use the hash reference to configure logging output to a file.

=item C<< $log->screen_output($message_type) >>

Returns the output value for the specified C<$message_type>. For example:
C<< $log->screen_output('ERR') >> returns 1 if ERR output is logged to the file,
and 0 if it is not. This is the same as C<< $log->screen_output()->{'ERR'} >>.

=item $obj->screen_output($message_type, $message_value)

Sets and then returns the output value for the specified C<$message_type>.
For example:
C<< $log->screen_output('ERR', 1) >> causes ERR output to be logged to the file and
it returns the value 1 because the value was set to 1. The same can be accomplished
using C<< $log->screen_output()->{'ERR'} = 1 >>.

=back

=cut

#************************************************************

sub screen_output
{
  return $initial_attributes{'screen_output'} if $#_ < 0;
  return $_[0]->{'screen_output'} if $#_ == 0;
  if ( UNIVERSAL::isa( $_[1], 'HASH' ) )
  {
    $_[0]->{'screen_output'} = deep_copy( $_[1] );
    return $_[1];
  }
  else
  {
    if ( $#_ > 1 )
    {
      $_[0]->{'screen_output'}->{ $_[1] } = $_[2];
    }
    return $_[0]->{'screen_output'}->{ $_[1] };
  }
}

#************************************************************

=pod

=head1 Private Methods

=head2 initialize

=over 4

=item C<< initialize() >>

The C<< initialize() >> method is called automatically when an object is created.
The new method also calls C<< initialize() >> directly

Initialize the data structure by copying values from the initial attributes hash
into the newly created object. An IO File handle is created and added to the object
if it does not already exist.

=back

=cut

#************************************************************

sub initialize()
{
  foreach my $key ( keys %initial_attributes )
  {
    if ( UNIVERSAL::isa( $initial_attributes{$key}, 'HASH' ) )
    {
      # If I simply copy it over then we both reference the same thing!
      $_[0]->{$key} = deep_copy( $initial_attributes{$key} );
    }
    else
    {
      $_[0]->{$key} = $initial_attributes{$key};
    }
  }

  if ( !exists( $_[0]->{'log_handle'} )
      || !UNIVSERAL::isa( $_[0]->{'log_handle'}, 'IO::File' ) )
  {
    my $handle = new IO::File;
    $handle->autoflush(1);
    $_[0]->{'log_handle'} = $handle;
  }
}

#************************************************************

=pod

=head2 close_log

=over 4

=item close_log()

Close the open file handle if the file handle exists and is open.

=back

=cut

#************************************************************

sub close_log
{
  my $obj = shift;
  if ( $obj->{'is_log_open'} )
  {
    if (   exists( $obj->{'log_handle'} )
            && defined( $obj->{'log_handle'} )
            && UNIVERSAL::can( $obj->{'log_handle'}, 'close' ) )
    {
      if ( !$obj->{'log_handle'}->close() )
      {
        print "Failed to close file ".$obj->get_log_full_name()." in close_log() because $!\n";
        $obj->is_ok(0);
      }
    }
    else
    {
      #print "Invalid handle, unable to close file ".$obj->log_name()." in close_log() \n";
      $obj->is_ok(0);
    }
    $obj->{'is_log_open'} = 0;
  }
  return $obj->{'is_ok'};
}

#************************************************************

=pod

=head2 is_log_open

=over 4

=item C<< $log->is_log_open() >>

Returns non-zero if the log is open and zero if it is closed.

=back

=cut

#************************************************************

sub is_log_open
{
  return $_[0]->{'is_log_open'};
}

#************************************************************

=pod

=head2 open_log

=over 4

=item C<< $log->open_log() >>

Open the logfile. returns non-zero on success and zero on failure.
If the log file is already open, as checked by C<< $log->is_log_open() >>,
then the file is assumed to already be open.

=back

=cut

#************************************************************

sub open_log()
{
  if ( !$_[0]->{'is_log_open'} )
  {
    $_[0]->check_log_length();
    my $file_name = '>>'.$_[0]->get_log_full_name();
    if ( $_[0]->{'log_handle'}->open($file_name) )
    {
      $_[0]->{'is_log_open'} = 1;
    }
    else
    {
      print "Failed to open file $file_name in open_log() because $!\n";
      $_[0]->is_ok(0);
    }
  }
  return $_[0]->{'is_log_open'};
}

#************************************************************
=pod

=head2 check_log_length

=over 4

=item C<< $log->check_log_length() >>

C<< check_log_length() >> is called before the log file is opened by
C<< open_log() >>.
If the current log file has size greater than C<< max_size() >>,
then the log files are rolled.

=back

=cut

#************************************************************

sub check_log_length()
{
  my $file_name = $_[0]->get_log_full_name();
  if (-f $file_name && stat($file_name)->size() > $_[0]->{'max_size'})
  {
    my $i = $_[0]->{'max_logs'};
    if ($i < 1)
    {
      unlink($file_name);
    }
    else
    {
      # Although rename should over-write this file,
      # remove it anyway.
      unlink($file_name.".$i") if (-f $file_name.".$i");
      while (--$i > 0)
      {
        rename($file_name.".$i", $file_name.".".($i+1)) if (-f $file_name.".$i");
      }
      rename($file_name, $file_name.".1");
    }
  }
}

#************************************************************

=pod

=head2 write_log

=over 4

=item C<< $log->write_log($message_type, $log_level, $message) >>

The message type is immediately checked to see if the
message should be written to the file or the screen.
The message is logged if if the stated log_level is less or equal to
the configured log level.
If the message will not be written, then C<write_log()>
immediately returns.

The line number of the calling function is obtained and
the current date and time is determined. Finlly, the
message text to write is created in the form:

YYYY.MM.DD hh:mm:ss <type>:<line> <message>

C<< $log->write_string_to_log() >> is used to perform the actual write.

Returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub write_log {
  my $write_to_screen = $_[0]->{'screen_output'}->{ $_[1] };
  my $write_to_file   = $_[0]->{'file_output'}->{ $_[1] };

  $write_to_screen = (defined($write_to_screen) && ($_[2] <= $write_to_screen)) ? 1 : 0;
  $write_to_file   = (defined($write_to_file) && ($_[2] <= $write_to_file)) ? 1 : 0;
  return 1 unless $write_to_screen || $write_to_file;

  my $obj       = shift;
  my $log_type  = shift;
  my $log_level = shift;

  my ( $tmp, $rc );
  my (
    $package,   $filename, $line,       $subroutine, $hasargs,
    $wantarray, $evaltext, $is_require, $hints,      $bitmask
     )
     = caller(1);
#  (
#    undef,      undef,     undef,       $subroutine, $hasargs,
#    $wantarray, $evaltext, $is_require, $hints,      $bitmask
#  )
#   = caller(2);

  my $current_time = time();
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = (localtime(time()));
  ++$mon;
  ++$wday;
  $year += 1900;
  my $output_message = join('.', $year, sprintf('%02d', $mon), sprintf('%02d', $mday)).' '.join(':', sprintf('%02d', $hour), sprintf('%02d', $min), sprintf('%02d',$sec ))." $log_type:$line ".join(' ', @_ );

  $rc = $obj->write_string_to_log( $write_to_screen, $write_to_file, $output_message );

  return $rc;
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Not really needed since the destructor for    **
#**          the file handle will cleanup after itself!    **
#**                                                        **
#************************************************************

sub DESTROY
{
  $_[0]->close_log();
}



#************************************************************

=pod

=head1 COPYRIGHT

Copyright 1998-2012, Andrew Pitonyak (perlboy@pitonyak.org)

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

=head1 Modification History

ADPLogger is taken from Pitonyak::SmallADPLogger, but
significant funcationality has been removed.

=head2 March 13, 1998

First release of Pitonyak::SmallADPLogger.

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD

=head2 January 18, 2006

Version 1.02 Gutted the original code to create ADPLogger.
The ADPLogger can use a Properties file for configuration, but
there are also fewer options for configuration.

=cut

#************************************************************

1;
