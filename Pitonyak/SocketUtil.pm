package Pitonyak::SocketUtil;

require Exporter;
$LogFile::VERSION = '1.02';

#************************************************************

=head1 NAME

Pitonyak::SocketUtil - Automates the process of using sockets.

=head1 SYNOPSIS

Automates the process of using sockets.

=head1 DESCRIPTION

Automates the process of using sockets.

=cut

#************************************************************

@ISA       = qw(Exporter);
#@EXPORT    = qw(is_ok is_connected local_port local_host remote_host remote_port socket_type is_open open close is_ready read_socket write_socket);

use Carp;
use strict;
use IO::Select;
use Sys::Hostname;
use IO::Socket;

my %initial_attributes = (
   'local_port'  => 0,        # Port on my end
   'local_host'  => '',       # My host
   'remote_host' => '',       # Host to which I am connected (if any)
   'remote_port' => 0,        # Port on out side host on which I am connected (if any)
   'socket_type' => 'tcp',    # Connection type such as udp (for datagrams)
   'last_host_ip'=> '0.0.0.0',
   'last_host'   => '',       # From whom did I last recieve a message (remote host)
   'last_port'   => 0,        # From where did I last receive a message (remote port)
   'is_connected'=> 0,        # Is this socket currently connected
   'is_ok'       => 0,        #
   'is_open'     => 0,        #
   'stack_trace' => 1,        # Include a stack trace with errors
);

#************************************************************
#**
#**  Input : connection type such as tcp or udp
#**          local port (0 for no local port specified)
#**          optional remote host port (0 for none or skip)
#**          optional remote host name (defaults to local host)
#**
#**  Output: A new Object
#**
#**  Notes : Note that this is written in such a manner
#**          that it can be inherited. Also note that it
#**          is written such that $obj2 = $obj1->new()
#**          is valid, although in general this means
#**          little in practice.
#**
#************************************************************

sub new
{
   my $self   = shift;
   my $objref = bless {}, ref($self) || $self;
   $objref->initialize();
   if (ref($self))
   {
       $objref->copy($self);
   }
   $objref->{'socket_type'} = shift if $#_ >= 0;
   $objref->{'local_port'} = shift if $#_ >= 0;
   $objref->{'remote_port'} = shift if $#_ >= 0;
   $objref->{'remote_host'} = shift if $#_ >= 0;
   if (defined($objref->{'remote_host'}) && $objref->{'remote_host'} ne '')
   {
      my $ip_addr = inet_aton($objref->{'remote_host'});
      if (defined($ip_addr))
      {
         $objref->{'remote_host_packed_ip'} = $ip_addr;
         $objref->{'remote_host_ip'} = join('.', unpack('C4', $ip_addr));
      }
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

sub DESTROY
{
   $_[0]->close();
}

sub copy
{
   my ($obj, $obj2) = @_;
   foreach (keys %initial_attributes)
   {
      $obj->{$_} = $obj2->{$_};
   }
   $obj->{'is_connected'} = 0;
   $obj->{'is_ok'} = 0;
   $obj->{'is_open'} = 0;
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

sub initialize
{
   my $obj = shift;
   foreach (keys %initial_attributes)
   {
      $obj->{$_} = $initial_attributes{$_};
   }
   $obj->{'socket'} = 0;
   $obj->{'local_host'} = hostname();
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: Value of is_ok                                **
#**                                                        **
#**  Notes : This verifies that the type is ok             **
#**          and nothing more. You probably really want to **
#**          check and see if an error occurred.            **
#**                                                        **
#************************************************************

sub is_ok
{
   $_[0]->{'is_ok'} = 0 if $_[0]->{'is_ok'} && exists($_[0]->{'socket'}) && defined($_[0]->{'socket'}) && !UNIVERSAL::isa($_[0]->{'socket'}, 'IO::Socket');
   return $_[0]->{'is_ok'};
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: Value of is_open                              **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub is_open
{
   return $_[0]->{'is_open'};
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for local_port          **
#**                                                        **
#**  Output: Value of local_port                           **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub local_port
{
   return get_attribute(@_, "local_port");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for local_host          **
#**                                                        **
#**  Output: Value of local_host                           **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub local_host
{
   return get_attribute(@_, "local_host");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for remote_host         **
#**                                                        **
#**  Output: Value of remote_host                          **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub remote_host
{
   if ($#_ > 0)
   {
      $_[0]->{'remote_host'} = $_[1];
      $_[0]->{'remote_host'} = shift if $#_ >= 0;
      delete $_[0]->{'remote_host_packed_ip'};
      delete $_[0]->{'remote_host_ip'};
      if (defined($_[0]->{'remote_host'}) && $_[0]->{'remote_host'} ne '')
      {
         my $ip_addr = inet_aton($_[0]->{'remote_host'});
         if (defined($ip_addr))
         {
            $_[0]->{'remote_host_packed_ip'} = $ip_addr;
            $_[0]->{'remote_host_ip'} = join('.', unpack('C4', $ip_addr));
         }
      }
   }
   return $_[0]->{'remote_host'};
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for remote_port         **
#**                                                        **
#**  Output: Value of remote_port                          **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub remote_port
{
   return get_attribute(@_, "remote_port");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for socket_type         **
#**                                                        **
#**  Output: Value of socket_type                          **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub socket_type
{
   return get_attribute(@_, "socket_type");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for last_host           **
#**                                                        **
#**  Output: Value of last_host                            **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub last_host
{
   return get_attribute(@_, "last_host");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for last_host_ip        **
#**                                                        **
#**  Output: Value of last_host_ip                         **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub last_host_ip
{
   return get_attribute(@_, "last_host_ip");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set for last_port           **
#**                                                        **
#**  Output: Value of last_port                            **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub last_port
{
   return get_attribute(@_, "last_port");
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: Value of is_connected                         **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub is_connected
{
   my $ok = 0;
   if ($_[0]->is_ok() && $_[0]->{'is_connected'})
   {
      if (defined($_[0]->{'socket'}) && UNIVERSAL::isa($_[0]->{'socket'}, 'IO::Socket') && defined($_[0]->{'socket'}->peername()))
      {
         $ok = 1;
      }
      else
      {
         $_[0]->{'is_connected'} = 0;
         close();
      }
   }
   return $ok;
}

#************************************************************
#**                                                        **
#**  Input : $name  : Name of the attribute to set         **
#**          $value : Optional value to set for $name      **
#**                                                        **
#**  Output: State of the mentioned attribute              **
#**                                                        **
#**  Notes : No value is required, in which case, only     **
#**          the value is returned and the value is not    **
#**          changed.                                      **
#**                                                        **
#************************************************************

sub get_attribute
{
   my $obj = shift;
   my ($name, $value);
   if (scalar(@_) == 2)
   {
      $value = shift;
      $name  = shift;
      $obj->{$name} = $value;
   }
   else
   {
      $name  = shift;
   }
   return $obj->{$name};
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: 1 if the obj is open, 0 otherwise             **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub open()
{
   if (!$_[0]->{'is_open'})
   {
      $_[0]->{'last_host_ip'} = '0.0.0.0';
      $_[0]->{'last_host'}    = '';
      $_[0]->{'last_port'}    = '';
      $_[0]->{'is_connected'} = ($_[0]->{'remote_port'} > 0) ? 1 : 0;
      $_[0]->{'is_ok'}        =  1;
      $_[0]->{'is_open'}      =  0;
      $_[0]->{'errors'}       = ();
      $_[0]->{'socket'}       =  0;

      my $socket_type = $_[0]->{'socket_type'};
      my $local_port  = $_[0]->{'local_port'};
      my $remote_port = $_[0]->{'remote_port'};
      my $remote_host = $_[0]->{'remote_host'};
      $remote_host = $_[0]->{'local_host'} if $remote_host eq '';
      #
      # Build the command which is evaluated to create the handle
      #
      my $cmd = '$handle = IO::Socket::INET->new(Proto => $socket_type,';
      $cmd .= 'PeerAddr  => $remote_host, PeerPort  => $remote_port,' if $remote_port > 0;
      $cmd .= 'LocalPort => $local_port,' if $local_port > 0;
      $cmd .= ');';
      #
      # If creating the socket fails, then the program may die.
      # This is not acceptable so I use eval!
      # I do, however, use tricky code here!
      #
      my $handle;
      #
      # If An attempt is made to connect to a non-existant socket, then a warning
      # is issued. I will trap this warning by writing my own "warning" handler as done below.
      # This then pushed the warnings onto a local stack that I can check.
      #
      my @local_errors = ();
      local $SIG{__WARN__} = sub { push @local_errors, @_; };
      eval $cmd;
      #
      # Are there any other errors for which I should look?
      #
      if ($#local_errors >= 0 && $local_errors[0] =~ /connection\s+refused/i)
      {
         $_[0]->add_errors(@local_errors);
         $handle = 0;
      }
      $_[0]->{'socket'} = $handle;
      #
      # If an error occurred in the eval, then $@ was set.
      #
      if ($@)
      {
         $_[0]->add_errors("Unable to create a $socket_type socket on $local_port to $remote_host:$remote_port because $@");
         $handle = 0;
      }
      elsif (!$_[0]->is_ok())
      {
         $_[0]->add_errors(@local_errors) if $#local_errors >= 0;
         $_[0]->add_errors("Invalid $socket_type socket created on $local_port to $remote_host:$remote_port because $!");
         $handle = 0;
      }
      elsif ($remote_port > 0 && !$_[0]->is_connected())
      {
         $_[0]->add_errors(@local_errors) if $#local_errors >= 0;
         $_[0]->add_errors("Unconnected, but valid, $socket_type socket created on $local_port to $remote_host:$remote_port because $!");
         $handle = 0;
      }
      else
      {
         $handle->timeout(1);
         $handle->autoflush();     # in case using an older version of IO::Socket which does not do this
         select($handle); $| = 1;  # Turn off I/O buffering on the TCP handle.
         select(STDERR);  $| = 1;  # Turn off I/O buffering on STDERR.
         select(STDOUT);  $| = 1;  # Turn off I/O buffering on STDOUT.
         $_[0]->{'is_open'} = 1;
      }
      $_[0]->{'socket'} = $handle;
   }
   return $_[0]->{'is_open'};
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: A stack trace to this point                   **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub get_stack_trace
{
   my $obj = shift;
   my $i = 1;
   my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = ('', '', '', '', '', '', '', '', '', '', '', '', '', '', '');

   my $rc = '';
   #
   # Crawl the stack. Note that if I made the call within a "Package DB" context
   # then I would also have the arg list. This would look something like
   # while (do { { package DB; @a = caller($i++) } } ) { process here }
   # but I just do not care about the parameters at this time.
   #
   while (($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller($i++))
   {
      #
      # Build a string, $subroutine, which names the sub-routine called.
      # This may also be "require ...", "eval '...' or "eval {...}"
      # So if things were done with an eval of sorts then make $subroutine
      # what we desire.
      #
      if (defined $evaltext)
      {
         #
         # Were we in a require statement?
         #
         if ($is_require)
         {
            $subroutine = "require $evaltext";
         }
         else
         {
            #
            # Render the eval string safe and then chop it if it is too long.
            #
            $evaltext =~ s/([\\\'])/\\$1/g;
            if (length($evaltext) > 20)
            {
               substr($evaltext, 20) = '...';
            }
            $subroutine = "eval '$evaltext'";
         }
      }
      elsif ($subroutine eq '(eval)')
      {
         $subroutine = 'eval {...}';
      }
      #
      # here's where the error message, $mess, is constructed
      #
      $rc .= "$subroutine called at $filename line $line";
      #
      # Was this multi-threaded?
      #
      if (defined &Thread::tid)
      {
         my $tid = Thread->self->tid;
         $rc .= " thread $tid" if $tid;
      }
      $rc .= "\n";
   }
   return $rc;
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: 1 if the file is open and ok, 0 otherwise.    **
#**                                                        **
#**  Notes:  This will open the socket if it can.          **
#**          Well, it will if auto_connect is true.        **
#**          In this case then you must manually open it.  **
#**                                                        **
#************************************************************

sub verify_open
{
   return ($_[0]->{'is_open'} || (!$_[0]->error_occurred() && $_[0]->{'auto_connect'} && $_[0]->open())) ? $_[0]->is_ok() : 0;
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes:                                                **
#**                                                        **
#************************************************************

sub close
{
   if ($_[0]->is_open())
   {
      my $handle = $_[0]->{'socket'};
      if (defined($handle) && UNIVERSAL::can($handle, 'close'))
      {
         my $cmd = '$handle->close()';
         eval $cmd;
      }
      $_[0]->{'is_connected'} = 0;
      $_[0]->{'is_ok'}        = 0;
      $_[0]->{'is_open'}      = 0;
      $_[0]->{'socket'}       = 0;
   }
}

#************************************************************
#**                                                        **
#**  Input : Optional timeout value, defaults to one sec   **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**   Notes: Will connect automatically                    **
#**                                                        **
#************************************************************

sub read_socket
{
   my $obj = shift;
   my $line = '';
   my $time_out = ($#_ >= 0) ? $_[0] : 1;
   if ($obj->verify_open())
   {
      my $handle = $obj->{'socket'};
      my($rmask, $emask) = ('', '');
      vec($rmask, fileno($handle), 1) = 1;
      vec($emask, fileno($handle), 1) = 1;
      my ($nfound, $timeleft) = select($rmask, undef, $emask, $time_out);
      if ($nfound < 0)
      {
         $obj->add_errors("Socket error in read_socket(), socket probably closed by remote host: $!");
         $obj->close();
      }
      elsif ($nfound > 0)
      {
         #
         # Is this a Datagram?
         #
         if ($obj->{'socket_type'} eq 'udp')
         {
            my $from_addr = recv($handle, $line, 34096, 0);
            if ($from_addr)
            {
               my ($family, $fromport, $fromipaddr) = unpack('S n a4 x8',$from_addr);
               $obj->{'last_port'} = $fromport;
               $obj->{'last_host_ip'} = join('.', unpack('C4', $fromipaddr));
               $obj->{'last_host'} = gethostbyaddr($fromipaddr,AF_INET);
               $obj->{'last_host'} = $obj->{'last_host_ip'} if !defined($obj->{'last_host'});
            }
            else
            {
               $line = '';
            }
         }
         #
         # Standard tcp connection
         #
         elsif ($obj->{'socket_type'} eq 'tcp')
         {
            if (sysread($handle, $line, 4096))
            {
               $obj->{'last_host'} = $obj->{'remote_host'};
               $obj->{'last_port'} = $obj->{'remote_port'};
            }
            else
            {
               $obj->add_errors("Socket error in read_socket(), socket probably closed by remote host: $!");
               $obj->close();
            }
         }
      }
   }
   return $line;
}

#************************************************************
#**                                                        **
#**  Input : Arbitrary list of lines to print              **
#**                                                        **
#**  Output: 1 on success, 0 on failure                    **
#**                                                        **
#**  Notes : If the socket is not currently open and no    **
#**          errors have yet occurred, then the socket is   **
#**          opened automatically.                         **
#**                                                        **
#************************************************************

sub write_socket
{
   my $obj = shift;
   #
   # Make certain that I can open this thing
   #
   if ($obj->verify_open())
   {
      my $handle = $obj->{'socket'};
      if ($obj->{'socket_type'} eq 'udp')
      {
         if (!exists($obj->{'remote_host_packed_ip'}))
         {
            $obj->add_errors("Socket is type udp and remote_host_packed_ip is not set for host ".$obj->{'remote_host'});
            $obj->close();
         }
         else
         {
            my $hispaddr = sockaddr_in($obj->{'remote_port'}, $obj->{'remote_host_packed_ip'});
            while ($#_ >= 0 && $obj->is_ok())
            {
               my $line = shift;
               if (!defined(send($handle, $line, 0, $hispaddr)))
               {
                  $obj->add_errors("Error sending ($line) because:$!");
                  $obj->close();
               }
            }
         }
      }
      #
      # Standard tcp connection
      #
      elsif ($obj->{'socket_type'} eq 'tcp')
      {
         while ($#_ >= 0 && $obj->is_connected())
         {
            my $line = shift;
            #
            # If the $handle is not good then print may simply exit.
            # I have not been able to stop this even by using eval!
            #
            my $ret = print $handle $line;
            if ( $ret )
            {
               # No error occurred
            }
            else
            {
               $obj->add_errors("Error printing to handle in write_socket: $!");
               $obj->close();
            }
         }
      }
   }
   else
   {
      $obj->add_errors("Error, unable to open the socket");
   }
   return $obj->{'is_open'};
}

#************************************************************
#**                                                        **
#**  Input : List of error numbers desired                 **
#**                                                        **
#**  Output: Requested errors.                             **
#**                                                        **
#**  Notes : If a list of numbers is given then these      **
#**          errors are used as the desired list of errors.**
#**          If not, then the entire list of errors is     **
#**          used. If an array is desired for return then  **
#**          the entire list is returned. If a scalar is   **
#**          desired for return then only the last error   **
#**          is returned.                                  **
#**                                                        **
#************************************************************

sub get_errors
{
   my $obj = shift;
   my $num = $obj->num_errors_occurred();
   if ($#_ >= 0)
   {
      my @errors;
      foreach (@_)
      {
         push @errors, $obj->{'errors'}[$_] if $_ < $num;
      }
      return wantarray ? @errors : ($#errors >= 0) ? $errors[-1] : '';
   }
   else
   {
      return wantarray ? @{$obj->{'errors'}} : ($num > 0) ? $obj->{'errors'}->[$num-1] : '';
   }
}

sub get_errors_as_one_string
{
   return join("\n", @{$_[0]->{'errors'}});
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: 1 if an error has occurred, 0 otherwise.       **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub error_occurred
{
   return $#{$_[0]->{'errors'}} >= 0 ? 1 : 0;
}

#************************************************************
#**                                                        **
#**  Input : None                                          **
#**                                                        **
#**  Output: Number of errors that have occurred.           **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub num_errors_occurred
{
   return $#{$_[0]->{'errors'}} + 1;
}

#************************************************************
#**                                                        **
#**  Input : List of errors to add                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Pushes errors onto the end of the list.       **
#**          If too many errors exist, then older errors   **
#**          are discarded.                                **
#**          If stack_trace is true then a stack trace     **
#**          will be added before the error.               **
#**                                                        **
#************************************************************

sub add_errors
{
   my $obj = shift;
   if ($#_ >= 0)
   {
      push(@{$obj->{'errors'}}, $obj->get_stack_trace()) if $obj->{'stack_trace'};
      push @{$obj->{'errors'}}, @_;
      splice(@{$obj->{'errors'}}, 0, $#{$obj->{'errors'}} - 20) if $#{$obj->{'errors'}} > 20;
   }
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set                         **
#**                                                        **
#**  Output: Value for the attribute                       **
#**                                                        **
#**  Notes : If stack trace is set then all errors will    **
#**          include a complete stack trace to the error.  **
#**                                                        **
#************************************************************

sub stack_trace
{
   return get_attribute(@_, "stack_trace");
}

#************************************************************
#**                                                        **
#**  Input : Optional value to set                         **
#**                                                        **
#**  Output: Value for the attribute                       **
#**                                                        **
#**  Notes : If true, then will automatically connect when **
#**          an operation occurres such as write or read    **
#**                                                        **
#************************************************************

sub auto_connect
{
   return get_attribute(@_, "auto_connect");
}


#************************************************************

=pod

=head1 COPYRIGHT

Copyright 2000-2012, Andrew Pitonyak (andrew@pitonyak.org)

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

=head2 Sept 14, 2000

Version 1.00 First release

=cut

#************************************************************

1;
