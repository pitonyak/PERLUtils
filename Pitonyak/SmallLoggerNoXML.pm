package Pitonyak::SmallLoggerNoXML;

#************************************************************

=head1 NAME

Pitonyak::SmallLoggerNoXML - File andE<sol>or screen logging with message types

=head1 SYNOPSIS

=begin html

<p><code>
use Pitonyak::SmallLoggerNoXML;              <br/>
                                             <br/>
my $log = new Pitonyak::SmallLoggerNoXML();  <br/>
# Do not use any time/date in the file name  <br/>
$log->log_name_date('');                     <br/>
# send debug output to the screen            <br/>
$log->screen_output('D', 1);                 <br/>
$log->debug("Debug 1");                      <br/>
$log->warn("Hello I Warn you");              <br/>
$log->debug("Hello I debug you");            <br/>
$log->info("Hello I info you");              <br/>
$log->error("Hello I error you");            <br/>
</code></p>

=end html

=head1 DESCRIPTION

=cut

#************************************************************

require Exporter;
$VERSION = '1.01';
@ISA     = qw(Exporter);
@EXPORT  = qw(
);

@EXPORT_OK = qw(
  build_name
  copy
  new
  close_log
  debug
  error
  file_output
  get_class_attribute
  hold_log_open
  info
  is_log_open
  is_ok
  log_ext
  log_path
  log_name
  log_name_date
  log_path
  log_primary_name
  message_front
  message_loc_format
  message_time_format
  open_append
  open_log
  rebuild_name
  screen_output
  set_log_primary_name
  trace
  warn
  write_log_type
  write_string_to_log
);

use Carp;
use IO::File;
use File::Basename;
use strict;
use Pitonyak::DeepCopy qw(deep_copy);
use Pitonyak::DateUtil;
use Pitonyak::StringUtil;

my %initial_attributes = (
    'is_log_open'   => 0,    # Is the file open or not
    'hold_log_open' => 1,    # If 0, will close log after each write
    'open_append'   =>
      1,    # If true, files will be opened in append mode, overwrite otherwise.
    'is_ok'               => 1,    # Has an error occured?
    'message_time_format' =>
      'YYYYMMDD.hhmmss',           # How is the date portion formatted
    'message_front' => 'log',      # Front part of the written lines
    'message_loc_format' => '(file):(sub):(line)'
    ,    # Although I can use (package), I do not because it is in the sub name
    'log_name'      => '',
    'log_name_date' =>
      '.YYYYMMDD.hhmmss',    # file name will include this in its name
    'log_path'   => './',
    'name_built' => 0,         # Set to one after the name has been built.
    'log_ext'    => '.log',    # Extension to use for the log file
    'screen_output' => { 'E' => 1, 'W' => 1, 'I' => 1, 'D' => 0 },
    'file_output' => { 'E' => 1, 'W' => 1, 'I' => 1, 'D' => 1, 'T' => 1 },
);

my %ignore_attributes_on_read = (
    'is_log_open' => 0,        # Is the file open or not
    'is_ok'       => 1,        # Has an error occured?
    'log_name'    => '',
    'name_built'  => 0,        # Set to one after the name has been built.
);

#************************************************************

=pod

=head2 new

=over 4

=item new()

Note that this is written in such a manner
that it can be inherited. Also note that it
is written such that $obj2 = $obj1->new()
is valid!

=back

=cut

#************************************************************

sub new {
    my $self = shift;
    my $objref = bless {}, ref($self) || $self;
    $objref->initialize();
    if ( ref($self) ) {
        $objref->copy($self);
    }
    return $objref;
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

sub DESTROY {
    $_[0]->close_log();
}

#************************************************************

=pod

=head2 copy

=over 4

=item copy($small_logger_object)

Make a copy of one SmallLoggerNoXML into another

C<<$obj1->copy($obj2)>> is the same as C<$obj1 = $obj2>.
The file handle is not copied and the
the receiving SmallLoggerNoXML is closed first.

=back

=cut

#************************************************************

sub copy {
    $_[0]->close_log();
    foreach my $key ( keys %initial_attributes ) {
        if ( UNIVERSAL::isa( $_[1]->{$key}, 'HASH' ) ) {

            # If I simply copy it over then we both reference the same thing!
            $_[0]->{$key} = deep_copy( $_[1]->{$key} );
        }
        else {
            $_[0]->{$key} = $_[1]->{$key};
        }
    }
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Initialize the data structure.                **
#**                                                        **
#************************************************************

sub initialize {
    foreach my $key ( keys %initial_attributes ) {
        if ( UNIVERSAL::isa( $initial_attributes{$key}, 'HASH' ) ) {

            # If I simply copy it over then we both reference the same thing!
            $_[0]->{$key} = deep_copy( $initial_attributes{$key} );
        }
        else {
            $_[0]->{$key} = $initial_attributes{$key};
        }

    }
    my $handle;

    my $tmp = File::Basename::basename($0);
    ($tmp) = ( $tmp =~ /(.*)\..*?/ );

    $_[0]->{'message_front'} = $tmp;

    if (   !exists( $_[0]->{'log_handle'} )
        || !UNIVSERAL::isa( $_[0]->{'log_handle'}, 'IO::File' ) )
    {
        $handle = new IO::File;
        $handle->autoflush(1);
        $_[0]->{'log_handle'} = $handle;
    }
    my $use_dir =
      defined( $ENV{'CARLOG'} ) ? $ENV{'CARLOG'} : $_[0]->{'log_path'};
    $_[0]->build_name(
        $use_dir, $tmp,
        $_[0]->{'log_name_date'},
        $_[0]->{'log_ext'}
    );
    $_[0]->{'name_built'} = 0;
}

#************************************************************

=pod

=head2 build_name

=over 4

=item $obj->build_name($path, $base_file_name, $time_format, $extension)

Returns non-zero on success.

The complete log file name will be named as
C<"$path$base_file_name$time_format$extension">
with some caveats.

The C<$time_format> is converted to a time date string and is used
as part of the file name if it does not have a zero length.
A popular format for this is '.YYYYMMDD.hhmmss' to have a log file
that contains the date and time included as part of the file name.
This is a good way to have a unique log file every time you run
and yet still know the application to which it is attached.
This should contain a leading '.' if one is desired.

The C<$path> indicates where the log file will exist.

The C<$extension> should contain a leading '.' if one is desired.

If the file is open, it will be closed before the name is changed.

=back

=cut

#************************************************************

sub build_name {
    my $obj = shift;
    my ( $len, $last_char );
    my $rv = 1;

    #
    # Make certain that $path.$front has a \ or a /
    # between them.
    #
    if ( $_[0] ne "" ) {
        $last_char = substr( $_[0], $[ + length( $_[0] ) - 1 );
        if ( $last_char ne "/" && $last_char ne "\\" && $_[1] ne "" ) {
            $last_char = substr( $_[1], $[, 1 );
            if ( $last_char ne "/" && $last_char ne "\\" ) {
                $_[0] .= "/";
            }
        }
    }

    #
    # Now make certain that nothing has changed...
    #
    my @arg_names =
      ( 'log_path', 'log_primary_name', 'log_name_date', 'log_ext' );
    my $something_changed = 0;
    for ( my $i = 0 ; $i <= $#arg_names ; ++$i ) {
        if ( !exists( $obj->{ $arg_names[$i] } )
            || $obj->{ $arg_names[$i] } ne $_[$i] )
        {
            $something_changed = 1;
            $obj->{ $arg_names[$i] } = $_[$i];
        }
    }
    if (   $something_changed
        || !$obj->is_log_open()
        || $obj->{'log_name'} eq '' )
    {
        if ( $obj->close_log() ) {
            $obj->{'log_name'} = $_[0] . $_[1] . time_date_str( $_[2] ) . $_[3];
            $rv = 1;
        }
        else {
            $rv = 0;
        }
    }
    $obj->{'name_built'} = 1;
    return $rv;
}

#************************************************************

=pod

=head2 close_log

=over 4

=item close_log()

If the file is open, it is closed.

=back

=cut

#************************************************************

sub close_log {
    my $obj = shift;
    if ( $obj->{'is_log_open'} ) {
        if (   exists( $obj->{'log_handle'} )
            && defined( $obj->{'log_handle'} )
            && UNIVERSAL::can( $obj->{'log_handle'}, 'close' ) )
        {
            if ( !$obj->{'log_handle'}->close() ) {
                print "Failed to close file "
                  . $obj->log_name()
                  . " in close_log() because $!\n";
                $obj->is_ok(0);
            }
        }
        else {

            #print "Invalid handle, unable to close file ".$obj->log_name()." in close_log() \n";
            $obj->is_ok(0);
        }
        $obj->{'is_log_open'} = 0;
    }
    return 1;
}

#************************************************************

=pod

=head2 debug

=over 4

=item debug($message)

This is used as an abreviation for C<write_log_type('D', $message);>

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub debug {
    my $obj = shift;
    return $obj->write_log( 'D', @_ );
}

#************************************************************

=pod

=head2 error

=over 4

=item error($message)

This is used as an abreviation for C<write_log_type('E', $message);>

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub error {
    my $obj = shift;
    return $obj->write_log( 'E', @_ );
}

#************************************************************

=pod

=head2 file_output

When a message is written, a message type is included.
I use one character to indicate the message type.
The screen output hash is then checked to see if
that message type should be logged.
This is similar to how log4j does things.

=over 4

=item SmallLoggerNoXML::file_output()

Return the default hash of values.

=item $obj->file_output()

Return the current hash of values.

=item $obj->file_output(HASH)

Sets the hash to use for output.

=item $obj->file_output($message_type)

Returns the output value for the specified C<$message_type>.

C<$o-E<gt>file_output('E')> is the same as
C<$o-E<gt>file_output()-E<gt>{'E'}>.

=item $obj->file_output($message_type, $message_value)

Sets and then returns the output value for the specified C<$message_type>.

C<$o-E<gt>file_output('E', 1)> is the same as
C<$o-E<gt>file_output()-E<gt>{'E'} = 1>.

=back

=cut

#************************************************************

sub file_output {
    return $initial_attributes{'file_output'} if $#_ < 0;
    return $_[0]->{'file_output'} if $#_ == 0;
    if ( UNIVERSAL::isa( $_[1], 'HASH' ) ) {
        $_[0]->{'file_output'} = deep_copy( $_[1] );
        return $_[1];
    }
    else {
        if ( $#_ > 1 ) {
            $_[0]->{'file_output'}->{ $_[1] } = $_[2];
        }
        return $_[0]->{'file_output'}->{ $_[1] };
    }
}

#************************************************************

=pod

=head2 get_class_attribute

Remember that the call C<$obj-E<gt>method(@parms)> is the same as
C<method($obj, @parms)>.

=over 4

=item SmallLoggerNoXML::get_class_attribute($attribute_name)

If there is only one paramter, the first parameter is
assumed to be an attribute name and the default attribute value
is returned.

=item $obj->get_class_attribute($attribute_name)

If there are two parameters, then the first parameter is assumed
to be a C<SmallLoggerNoXML> object and the second parameter is
assumed to be an attribute name.
The attribute value for the object is returned.

=item $obj->get_class_attribute($attribute_name, $attribute_value)

If three parameters are given, then the first parameter is the object,
the second parameter
is used to set a new value for the attribute,
and the third parameter is the attribute name,
The attribute value is then returned.

=back

=cut

#************************************************************

sub get_class_attribute {
    return $initial_attributes{ $_[0] } if $#_ == 0;
    return $_[0]->{ $_[1] } if $#_ == 1;
    $_[0]->{ $_[2] } = $_[1];
    return $_[1];
}

#************************************************************

=pod

=head2 hold_log_open

=over 4

=item hold_log_open([0|1])

If a message is written to the log and it is not yet open,
it is opened.
If the I<hold_log_open> attribute is non-zero (the default value)
then the file
is left open, otherwise, it is closed after writing.
Note write_log() will only close
the log if it opened the log, so you can
clear hold_log_open and then manually open the
the log before a lot of writing and then
manually close the log.

No value is required, in which case, only
the status is returned and the value is not
changed.

If hold_log_open is set to true, you probably want open_append set to true as well.
See open_append() for more details.

=back

=cut

#************************************************************

sub hold_log_open {
    my $obj = shift;
    if ( scalar(@_) > 0 ) {
        $obj->close_log();
        $obj->{'hold_log_open'} = shift;
    }
    return $obj->{'hold_log_open'};
}

#************************************************************

=pod

=head2 info

=over 4

=item info($message)

This is used as an abreviation for C<write_log_type('I', $message);>

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub info {
    my $obj = shift;
    return $obj->write_log( 'I', @_ );
}

#************************************************************

=pod

=head2 is_log_open

=over 4

=item is_log_open()

Returns non-zero if the log is open and zero if it is closed.

Do not attempt to set this directly, use the open_log() or close_log()
methods instead.

=back

=cut

#************************************************************

sub is_log_open {
    return $_[0]->{'is_log_open'};
}

#************************************************************

=pod

=head2 is_ok

=over 4

=item is_ok([0|1])

Returns non-zero if the log object is ok and zero otherwise.

Although you may set this, there is no real reason to do so.
This will be set if there is a problem opening the file, for example.

=back

=cut

#************************************************************

sub is_ok {
    return get_class_attribute( @_, 'is_ok' );
}

#************************************************************

=pod

=head2 log_ext

=over 4

=item log_ext([$log_extension])

The default extension is '.log'. You can set a new one with this method.
The current value is returned.

If the log is currently open, it will be closed when the name changes.

=back

=cut

#************************************************************

sub log_ext {
    my $obj = shift;
    my $value;
    if ( scalar(@_) > 0 ) {
        $value = shift;
        $obj->build_name(
            $obj->log_path(),
            $obj->log_primary_name(),
            $obj->{'log_name_date'}, $value
        );
        $_[0]->{'name_built'} = 0;
    }
    return $obj->{'log_ext'};
}

#************************************************************

=pod

=head2 log_name

=over 4

=item log_name()

Returns Full path to and name of log file being used.

=back

=cut

#************************************************************

sub log_name {
    return $_[0]->{'log_name'};
}

#************************************************************

=pod

=head2 log_name_date

=over 4

=item log_name_date([$new_date_format])

The file name used for a log file contains a date format.
This sets the date format portion to use.
This may be an empty string.

=back

=cut

#************************************************************

sub log_name_date {
    if ( $#_ > 0 ) {
        if ( $_[0]->{'log_name_date'} ne $_[1] ) {
            $_[0]->{'log_name_date'} = $_[1];
            $_[0]->{'name_built'}    = 0;
        }
    }
    return $_[0]->{'log_name_date'};
}

#************************************************************

=pod

=head2 log_path

=over 4

=item log_path([$new_log_path])

This will optionally set a new location for the logfile.
The current value is returned.

If the log is currently open, it will be closed when the name changes.

=back

=cut

#************************************************************

sub log_path {
    my $obj = shift;
    my $value;
    if ( scalar(@_) > 0 ) {
        $value = shift;
        my $old_name       = $obj->{'log_name'};
        my $old_name_built = $obj->{'name_built'};
        $obj->build_name(
            $value,
            $obj->log_primary_name(),
            $obj->{'log_name_date'},
            $obj->{'log_ext'}
        );
        $obj->{'name_built'} =
          ( $old_name ne $obj->{'log_name'} ) ? 0 : $old_name_built;
    }
    return $obj->{'log_path'};
}

#************************************************************

=pod

=head2 log_primary_name

=over 4

=item log_primary_name([$new_primary_name])

This is the primary name for the logfile.
Logs are assumed to be made of a primary name,
date portion, and an extension.

If the logfile is currently open, then the
file is closed before changing the name.
The default value is the base name of $0 with
the extension removed. This is what is used
if set_log_primary_name() is used.

No value is required, in which case, only
the primary name is returned and the value is not
changed.

=back

=cut

#************************************************************

sub log_primary_name {
    my $obj = shift;
    if ( scalar(@_) > 0 ) {
        my $value = shift;
        $obj->build_name( $obj->log_path(), $value, $obj->{'log_name_date'},
            $obj->{'log_ext'} );
        $_[0]->{'name_built'} = 0;
    }
    return $obj->{'log_primary_name'};
}

#************************************************************

=pod

=head2 message_front

=over 4

=item message_front([$front_string])

Returns the front lne used to write messages to the logs.

A message is printed as
C<$mesage_type message_front() message_time_format() message_loc_format()>

=back

=cut

#************************************************************

sub message_front {
    return get_class_attribute( @_, "message_front" );
}

#************************************************************

=pod

=head2 message_loc_format

=over 4

=item message_loc_format([$location_format])

Returns the output format used to write message location information to the logs.

This determines the format of the location
information, if any, that is printed to the
log file. The text with fields replaced will
be used.
The default value for the location format is C<'(file):(sub):(line)'>.
The I<(package)> token is not used because the sub
name contains the package.

A message is printed as
C<$mesage_type message_front() message_time_format() message_loc_format()>

=back

=cut

#************************************************************

sub message_loc_format {
    return get_class_attribute( @_, 'message_loc_format' );
}

#************************************************************

=pod

=head2 message_time_format

=over 4

=item message_time_format([$time_format])

Returns the output format for the time information used to write messages to the logs.

When a line is printed, it contains the message type,
message_front() formatted time/date stamp as stored by message_time_format(),
this location format string, and then finally the message.

A message is printed as
C<$mesage_type message_front() message_time_format() message_loc_format()>

=back

=cut

#************************************************************

sub message_time_format {
    return get_class_attribute( @_, 'message_time_format' );
}

#************************************************************

=pod

=head2 open_append

=over 4

=item open_append([0|1])

If the open_append attribute is set then log files are opened in append mode.
If not, then the log file will over-write any existing file.
If the hold_log_open attribute is set, you really probably
want open_append set as well.

Returns the current value of the attribute.

=back

=cut

#************************************************************

sub open_append {
    return get_class_attribute( @_, 'open_append' );
}

#************************************************************

=pod

=head2 open_log

=over 4

=item open_log()

Open the logfile. returns non-zero on success and zero on failure.

=back

=cut

#************************************************************

sub open_log() {
    my $file_name;
    if ( !$_[0]->{'is_log_open'} ) {
        $_[0]->rebuild_name() if !$_[0]->{'name_built'};
        if ( $_[0]->{'open_append'} ) {
            $file_name = '>>' . $_[0]->{'log_name'};
        }
        else {
            $file_name = '>' . $_[0]->{'log_name'};
        }
        if ( $_[0]->{'log_handle'}->open($file_name) ) {
            $_[0]->{'is_log_open'} = 1;
        }
        else {
            print "Failed to open file $file_name in open_log() because $!\n";
            $_[0]->is_ok(0);
        }
    }
    return $_[0]->{'is_log_open'};
}

#************************************************************

=pod

=head2 rebuild_name

=over 4

=item rebuild_name()

Causes the name of the log file to be rebuilt.
Any date/time stamp portion is also redone.
This calls build_name() with appropriate parameters.

This value is then returned.

=back

=cut

#************************************************************

sub rebuild_name {
    my $obj = shift;
    return $obj->build_name(
        $obj->log_path(),        $obj->{'log_primary_name'},
        $obj->{'log_name_date'}, $obj->{'log_ext'}
    );
}

#************************************************************

=pod

=head2 screen_output

When a message is written, a message type is included.
I use one character to indicate the message type.
The screen output hash is then checked to see if
that message type should be logged.
This is similar to how log4j does things.
See file_output().

=over 4

=item SmallLoggerNoXML::screen_output()

Return the default hash of values.

=item $obj->screen_output()

Return the current hash of values.

=item $obj->screen_output(HASH)

Sets the hash to use for output.

=item $obj->screen_output($message_type)

Returns the output value for the specified C<$message_type>.

C<$o-E<gt>screen_output('E')> is the same as
C<$o-E<gt>screen_output()-E<gt>{'E'}>.

=item $obj->screen_output($message_type, $message_value)

Sets and then returns the output value for the specified C<$message_type>.

C<$o-E<gt>screen_output('E', 1)> is the same as
C<$o-E<gt>screen_output()-E<gt>{'E'} = 1>.

=back

=cut

#************************************************************

sub screen_output {
    return $initial_attributes{'screen_output'} if $#_ < 0;
    return $_[0]->{'screen_output'} if $#_ == 0;
    if ( UNIVERSAL::isa( $_[1], 'HASH' ) ) {
        $_[0]->{'screen_output'} = deep_copy( $_[1] );
        return $_[1];
    }
    else {
        if ( $#_ > 1 ) {
            $_[0]->{'screen_output'}->{ $_[1] } = $_[2];
        }
        return $_[0]->{'screen_output'}->{ $_[1] };
    }
}

#************************************************************

=pod

=head2 set_log_primary_name

=over 4

=item set_log_primary_name([$new_primary_name])

This will always set a new primary name. If
a parameter is included, then it is used.
If the parameter is not included, then the basename
is take from $0 and then the portion before the last
period is used. The log_primary_name() method
is then used to set the primary name.

=back

=cut

#************************************************************

sub set_log_primary_name {
    my $obj = shift;
    my $new_front;
    if ( scalar(@_) > 0 ) {
        $new_front = $_[0];
    }
    else {
        my (
            $package,   $filename, $line,       $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, $hints,      $bitmask
          )
          = caller(0);
        $new_front = File::Basename::basename($filename);
        ($new_front) = ( $new_front =~ /(.*)\..*?/ );
    }
    return $obj->log_primary_name($new_front);
}

#************************************************************

=pod

=head2 trace

=over 4

=item trace($message)

This is used as an abreviation for C<write_log_type('T', $message);>

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub trace {
    my $obj = shift;
    return $obj->write_log( 'T', @_ );
}

#************************************************************

=pod

=head2 warn

=over 4

=item warn($message)

This is used as an abreviation for C<write_log_type('W', $message);>

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub warn {
    my $obj = shift;
    return $obj->write_log( 'W', @_ );
}

#************************************************************

=pod

=head2 write_log

=over 4

=item write_log($message_type, $message)

This builds the log message to actually write (including time stamps and such)
and then calls write_string_to_log().

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub write_log {
    my $write_to_screen = $_[0]->{'screen_output'}->{ $_[1] };
    my $write_to_file   = $_[0]->{'file_output'}->{ $_[1] };

    $write_to_screen = 0 unless defined($write_to_screen);
    $write_to_file   = 0 unless defined($write_to_file);
    return 1 unless $write_to_screen || $write_to_file;

    my $obj      = shift;
    my $log_type = shift;
    my ( $tmp, $rc );
    my (
        $package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
      )
      = caller(1);
    (
        undef,      undef,     undef,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
      )
      = caller(2);
    $filename   = '' if !defined($filename);
    $package    = '' if !defined($package);
    $subroutine = '' if !defined($subroutine);
    $tmp = File::Basename::basename($filename);
    my $name = $obj->{'message_loc_format'};
    $name =~ s/\(file\)/$tmp/i;
    $name =~ s/\(package\)/$package/i;
    $name =~ s/\(sub\)/$subroutine/i;
    $name =~ s/\(line\)/$line/i;
    $line = join ( ' ',
        $log_type, time_date_str( $obj->message_time_format() ),
        $name, @_ );

    $rc = $obj->write_string_to_log( $write_to_screen, $write_to_file, $line );

    return $rc;
}

#************************************************************

=pod

=head2 write_log_type

=over 4

=item write_log_type($message_type, $message)

The C<$message_type> is usually a single character such as
'D', 'E', 'W', 'T', 'I' etc. representing things such as
debug, error, warning, trace, info, etc.

The C<$message_type> determines if the message should be printed to the file and/or screen.

The C<$message_type> is always printed as the first thing on the line.

returns 1 if successful, 0 otherwise

=back

=cut

#************************************************************

sub write_log_type {
    write_log(@_);
}

#************************************************************

=pod

=head2 write_string_to_log

=over 4

=item write_string_to_log($to_screen, $to_file, $message)

This writes the C<$message> to the screen if C<$to_screen> evaluates to true.
This writes the C<$message> to the file if C<$to_file> evaluates to true.

returns 1 if successful, 0 otherwise

This will open the file if it must.
This will never close the file unless it
opened the file and hold_log_open() is false.

=back

=cut

#************************************************************

sub write_string_to_log {
    my $rv              = 1;
    my $close_when_done = 0;

    print "$_[3]\n" if $_[1];

    if ( $_[2] ) {
        $close_when_done = 1
          if $_[0]->hold_log_open() == 0 && $_[0]->is_log_open() == 0;
        if ( $_[0]->open_log() ) {
            $_[0]->{'log_handle'}->print("$_[3]\n");
        }
        else {
            $rv = 0;
        }
    }

    $_[0]->close_log() if $close_when_done;
    return $rv;
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

=head2 May 13, 2003

Version 1.00 First release branched from SmallLogger to NOT use XML
I needed it rather quickly so here it is!


=cut

#************************************************************

1;

