package Pitonyak::DeepCopy;

#************************************************************

=head1 NAME

Pitonyak::DeepCopy - Copy an object reference with new copies, even if it contains references.

=head1 SYNOPSIS

C<use Pitonyak::DeepCopy;>
C<my $new_hash_ref = Pitonyak::DeepCopy::deep_copy(\%original_hash);>

=head1 DESCRIPTION

Assume the hash A% contains a hash.
Now, copy the elements from A% into B%.

The obvious solution enumerates the keys and assigns the value from
A% to B%. Something like this:

C<foreach (keys A%) $B{$_} = $A{$_};>

Unfortunately, the contained hash is a reference, %A and %B both reference
the same hash. In other words, if you modify the contained hash in %A or %B,
you change it in both.

The proper solution is obtained using

C<my $hash_ref = Pitonyak::DeepCopy::deep_copy(\%A);>

=head1 Methods

=cut

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION   = '1.04';
@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw(deep_copy);

use strict;

#************************************************************

=pod

=head2 deep_copy

=over 4

=item C<< deep_copy(ref_to_object) >>

Accept a reference to an object and return a reference to a new copy of the object.

C<$copy_ref = deep_copy(\%hash_ref);>

=back

=cut

#************************************************************

sub deep_copy
{
  # if not defined then return it
  return undef if $#_ < 0 || !defined( $_[0] );

  # if not a reference then return the parameter
  return $_[0] if !ref( $_[0] );
  my $obj = shift;
  if ( UNIVERSAL::isa( $obj, 'SCALAR' ) )
  {
    my $temp = deepcopy($$obj);
    return \$temp;
  }
  elsif ( UNIVERSAL::isa( $obj, 'HASH' ) )
  {
    my $temp_hash = {};
    foreach my $key ( keys %$obj )
    {
      if ( !defined( $obj->{$key} ) || !ref( $obj->{$key} ) )
      {
        $temp_hash->{$key} = $obj->{$key};
      }
      else
      {
        $temp_hash->{$key} = deep_copy( $obj->{$key} );
      }
    }
    return $temp_hash;
  }
  elsif ( UNIVERSAL::isa( $obj, 'ARRAY' ) )
  {
    my $temp_array = [];
    foreach my $array_val (@$obj)
    {
      if ( !defined($array_val) || !ref($array_val) )
      {
        push ( @$temp_array, $array_val );
      }
      else
      {
        push ( @$temp_array, deep_copy($array_val) );
      }
    }
    return $temp_array;
  }
  # ?? I am uncertain about this one
  elsif ( UNIVERSAL::isa( $obj, 'REF' ) )
  {
    my $temp = deepcopy($$obj);
    return \$temp;
  }
  # I guess that it is either CODE, GLOB or LVALUE
  else
  {
    return $obj;
  }
}

#************************************************************

=pod

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

=head1 Modification History

=head2 September 01, 2002

Version 1.00 First release

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD documentation. Added parameter checking.

=head2 January 18, 2007

Version 1.02 Updated POD and reformatted.

=head2 January 18, 2007

Version 1.03 Removed reference to Carp library, because it is not used.

=head2 January 18, 2007

Version 1.04 Copyright and moved POD around.

=cut

#************************************************************


1;
