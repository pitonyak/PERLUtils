package Pitonyak::XMLUtil;

#************************************************************

=head1 NAME

Pitonyak::XMLUtil - Convert Objects to and from XML.

=head1 DESCRIPTION

A few simple XML utilities that will convert arbitrary objects to XML and back again.
These routines have not been extensively tested.

=cut

require Exporter;
$VERSION   = '1.02';
@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw(
  convert_entity_references_to_characters
  convert_xml_characters_to_entity_references
  object_to_xml
  xml_to_object
);

use Carp;
use strict;
use XML::Parser;

#************************************************************

=pod

=head2 convert_entity_references_to_characters

=over 4

=item convert_entity_references_to_characters(@strings_with_entity_refs)

=back

Change '&amp;' to '&', '&lt;' to '<', '&gt;' to '>', '&quot;' to '"', and '&apos;' to "'".

The calling parameters are modfied

=cut

#************************************************************

my %s2x = (
  '&amp;'  => '&',
  '&lt;'   => '<',
  '&gt;'   => '>',
  '&quot;' => '"',
  '&apos;' => "'",
);

sub convert_entity_references_to_characters
{
  return undef if $#_ < 0;
  for (@_)
  {
    s/(&apos;|&quot;|&gt;|&lt;|&amp;)/"$s2x{$1}"/igeos;
  }
  return wantarray ? @_ : $_[0];
}

#************************************************************

=pod

=head2 convert_xml_characters_to_entity_references

=over 4

=item convert_xml_characters_to_entity_references(@strings_needing_entity_refs)

=back

Change '&' to '&amp;', '<' to '&lt;', '>' to '&gt;', '"' to '&quot;', and "'" to '&apos;',

The calling parameters are modfied.

This is used to render a string safe to send as XML.
Existing entity referenes will have their leading ampersand transformed.

=cut

#************************************************************

my %x2s = (
  '&' => '&amp;',
  '<' => '&lt;',
  '>' => '&gt;',
  '"' => '&quot;',
  "'" => '&apos;',
);

sub convert_xml_characters_to_entity_references {

  # If called from an XMLUtil object, then discard "this" and keep going.
  if ( $#_ >= 0 && UNIVERSAL::isa( $_[0], 'XMLUtil' ) ) {
    shift;
  }
  return undef if $#_ < 0;
  for (@_) {
    s/([&<>"'])/$x2s{$1}/geo;
  }
  return wantarray ? @_ : $_[0];
}

#*********************************************************************
#**                                                                 **
#**  Input : left indentation                                       **
#**          One object to convert                                  **
#**                                                                 **
#**  Output: Objects converted to XML                               **
#**                                                                 **
#**  Notes : Each parameter is a single XML string                  **
#**          The element name identifies the type                   **
#**          Objects are usually converted to a HASH                **
#**                                                                 **
#*********************************************************************

sub internal_object_to_xml {
  return undef if $#_ < 1;
  my $left           = shift;
  my $thing_to_print = shift;
  my $txt;
  if ( !defined($thing_to_print) )
  {
    $txt = '<NULL/>';
  }
  else
  {
    my $ref_type = ref $thing_to_print;
    if ( !$ref_type )
    {
      $txt = convert_xml_characters_to_entity_references($thing_to_print);
    }
    elsif ( $ref_type eq 'SCALAR' )
    {
      # If the referenced item cannot be converted
      # then it will not be
      my $internal = internal_object_to_xml( "$left  ", $$thing_to_print );
      if ( defined($internal) && length($internal) > 0 )
      {
        $txt = "<REF>\n$internal\n$left</REF>";
      }
      else
      {
        $txt = "<REF/>";
      }
    }
    elsif ( $ref_type eq 'ARRAY' )
    {
      my $internal_txt = '';
      foreach my $temp_thing (@$thing_to_print)
      {
        my $internal = internal_object_to_xml( "$left  ", $temp_thing );
        if ( length($internal) == 0 )
        {
          $internal_txt .= "$left  <Value/>\n";
        }
        elsif ( index( $internal, '<' ) >= $[ )
        {
          $internal_txt .= "$left  <Value>\n$left    $internal\n$left  </Value>\n";
        }
        else
        {
          $internal_txt .= "$left  <Value>$internal</Value>\n";
        }
      }
      if ( length($internal_txt) > 0 )
      {
        $txt = "<ARRAY>\n$internal_txt$left</ARRAY>";
      }
      else
      {
        $txt = '<ARRAY/>';
      }
    }
    elsif ( UNIVERSAL::isa( $thing_to_print, 'HASH' ) )
    {
      #
      # Remember that each hash has one universal iterator
      # recursive nesting will therefore cause stranger
      # results than a simple infinite loop.
      #
      my $hash_txt = "\n";
      my ( $key, $value );
      while ( ( $key, $value ) = each %$thing_to_print )
      {
        my $value_xml;
        my $key_xml;
        if ( defined($value) )
        {
          $value_xml = internal_object_to_xml( "$left      ", $value );
        }
        if ( defined($key) )
        {
          $key_xml = internal_object_to_xml( "$left      ", $key );
        }
        if ( defined($key) )
        {
          if (
              index( $key_xml, '<' ) >= $[
              || ( defined($value_xml)
                  && index( $value_xml, '<' ) >= $[ )
            )
          {
            $hash_txt .= "$left  <Pair>\n$left    ";
            if ( index( $key_xml, '<' ) >= $[ )
            {
              $hash_txt .= "<Key>\n$left      $key_xml\n$left    </Key>\n";
            }
            elsif ( length($key_xml) > 0 )
            {
              $hash_txt .= "<Key>$key_xml</Key>\n";
            }
            else
            {
              $hash_txt .= "<Key/>\n";
            }
            if ( defined($value_xml) )
            {
              if ( index( $value_xml, '<' ) >= $[ )
              {
                $hash_txt .= "$left    <Value>\n$left      $value_xml\n$left    </Value>\n";
              }
              elsif ( length($value_xml) > 0 )
              {
                $hash_txt .= "$left    <Value>$value_xml</Value>\n";
              }
              else
              {
                $hash_txt .= "$left    <Value/>\n";
              }
            }
            $hash_txt .= "$left  </Pair>\n";
          }
          elsif ( defined($key_xml) )
          {
            $hash_txt .= "$left  <Pair>";
            if ( length($key_xml) > 0 )
            {
              $hash_txt .= "<Key>$key_xml</Key>";
            }
            else
            {
              $hash_txt .= "<Key/>";
            }
            if ( defined($value_xml) )
            {
              if ( length($value_xml) > 0 )
              {
                $hash_txt .= "<Value>$value_xml</Value>";
              }
              else
              {
                $hash_txt .= "<Value/>";
              }
            }
            $hash_txt .= "</Pair>\n";
          }
        }
      }
      if ( defined($hash_txt) && index( $hash_txt, '<' ) >= $[ )
      {
        $txt = "<HASH>$hash_txt$left</HASH>";
      }
      else
      {
        $txt = '<HASH/>';
      }
    }
  }
  return $txt;
}

#************************************************************

=pod

=head2 object_to_xml

=over 4

=item object_to_xml(@objects_to_transform)

=back

Transform an object into XML.
An attempt is made to make this object human readable.
Note that if the object is a package object that is referenced as a HASH
it is still embedded as a HASH.

Each object in the array is returned as a separate XML string.


An object that is not defined is returned as C<E<lt>NULLE<sol>E<gt>>>

A SCALAR is rendered XML safe by converting special characters to entity references.
It is otherwise left unchanged.

A Reference to a SCALAR is encoded as C<E<lt>REFE<sol>E<gt>> for a zero length SCALAR and as
C<E<lt>REFE<gt>valueE<lt>E<sol>REFE<gt>>

An ARRAY reference is encoded as either C<E<lt>ARRAYE<sol>E<gt>> or something similar to
C<E<lt>ARRAYE<gt>E<lt>VALUEE<gt>valueE<lt>E<sol>VALUEE<gt>E<lt>E<sol>ARRAYE<gt>>.

A HASH reference is encoded as
C<E<lt>HASHE<gt>E<lt>PAIRE<gt>E<lt>KEYE<gt>valueE<lt>E<sol>KEYE<gt>E<lt>VALUEE<gt>valueE<lt>VALUEE<gt>E<lt>E<sol>PAIRE<gt>E<lt>E<sol>HASHE<gt>>
A PAIR may be missing a C<VALUE> which means that it is undefined.

If a value is really the intended value, then it is rendered XML safe by using entity references
and no extra space is used. If the value is a reference to something else then the object is converted
to XML using extra white space and indentation for easier reading.


=cut

#************************************************************

sub object_to_xml
{
  return undef if $#_ < 0;
  my @object_xmls = ();
  foreach my $thing_to_print (@_)
  {
    my $txt = internal_object_to_xml( '', $thing_to_print );
    push @object_xmls, $txt if defined($txt) && length($txt) > 0;
  }
  return wantarray ? @object_xmls : $object_xmls[0];
}

#*********************************************************************
#**                                                                 **
#**  Input : Array reference of an XML object                       **
#**          Index into the array from which to start               **
#**                                                                 **
#**  Output: XML converted back to objects                          **
#**                                                                 **
#**  Notes : This takes the string from object_to_xml               **
#**                                                                 **
#*********************************************************************

sub internal_xml_to_object
{
  return undef if $#_ < 0;
  if ( ref( $_[0] ) ne 'ARRAY' )
  {
    carp( "Array reference expected as the first parameter, not"
        . ref( $_[0] ) );
    return undef;
  }
  my $array_ref = shift;
  my $tag_start = 0;
  $tag_start = shift unless $#_ < 0;
  if ( $tag_start > $#$array_ref )
  {
    confess(
    "Requested an index of $tag_start when the array is not large enough"
    );
    return undef;
  }
  my $obj;
  my $element_name = $array_ref->[$tag_start];
  my $element;
  $element = $array_ref->[ $tag_start + 1 ] if $tag_start < $#$array_ref;
  if ( $element_name eq '0' )
  {
    if ( defined($element) )
    {
      $obj = convert_entity_references_to_characters($element);
    }
    else
    {
      $obj = '';
    }
  }
  elsif ( $element_name eq 'NULL' )
  {
    # $obj is already undefined
  }
  elsif ( defined($element) && ref($element) ne 'ARRAY' )
  {
    carp( "The element $element_name is not followed by an array, it is an "
          . ref($element) );
  }
  elsif ( $element_name eq 'REF' )
  {
    my $temp = internal_xml_to_object( $element, 1 );
    $obj = \$temp;
  }
  elsif ( $element_name eq 'ARRAY' )
  {
    my @my_array  = ();
    my $array_len = 0;
    if ( defined($element) )
    {
      $array_len = $#$element;
    }
    for ( my $i = 1 ; $i < $array_len ; $i += 2 )
    {
      if ( $element->[$i] eq 'Value' )
      {
        my $val_array           = $element->[ $i + 1 ];
        my $length_of_val_array = $#$val_array;
        if ( $length_of_val_array == 0 )
        {
          push @my_array ,'';
        }
        else
        {
          my $idx_to_use = 1;
          for (my $k = 1 ;$k < $length_of_val_array ;$k += 2)
          {
            $idx_to_use = $k if $val_array->[$k] ne '0';
          }
          push @my_array, internal_xml_to_object( $val_array, $idx_to_use );
        }
      }
    }
    $obj = \@my_array;
  }
  elsif ( $element_name eq 'HASH' )
  {
    my %my_hash   = ();
    my $array_len = 0;
    if ( defined($element) )
    {
      $array_len = $#$element;
    }
    for ( my $i = 1 ; $i < $array_len ; $i += 2 )
    {
      # skip white space
      if ( $element->[$i] eq 'Pair' )
      {
        my ( $key, $val );
        my $internal_array     = $element->[ $i + 1 ];
        my $internal_array_len = $#$internal_array;
        for ( my $j = 1 ; $j < $internal_array_len ; $j += 2 )
        {
          if ( $internal_array->[$j] eq 'Key' )
          {
            my $key_array           = $internal_array->[ $j + 1 ];
            my $length_of_key_array = $#$key_array;
            if ( $length_of_key_array == 0 )
            {
              $key = '';
            }
            else
            {
              my $idx_to_use = 1;
              for (my $k = 1 ;$k < $length_of_key_array ; $k += 2)
              {
                $idx_to_use = $k if $key_array->[$k] ne '0';
              }
              $key = internal_xml_to_object( $key_array, $idx_to_use );
            }
          }
          elsif ( $internal_array->[$j] eq 'Value' )
          {
            my $val_array           = $internal_array->[ $j + 1 ];
            my $length_of_val_array = $#$val_array;
            if ( $length_of_val_array == 0 )
            {
              $val = '';
            }
            else {
              my $idx_to_use = 1;
              for (my $k = 1 ;$k < $length_of_val_array ;$k += 2)
              {
                $idx_to_use = $k if $val_array->[$k] ne '0';
              }
              $val = internal_xml_to_object( $val_array, $idx_to_use );
            }
          }
        }
        $my_hash{$key} = $val;
      }
    }
    $obj = \%my_hash;
  }
  return $obj;
}

#************************************************************

=pod

=head2 xml_to_object

=over 4

=item xml_to_object(@xml_strings_to_convert_to_objects)

=back

Convert XML strings back into objects.

=cut

#************************************************************

sub xml_to_object
{
  # If called from a logger object, then simply discard
  if ( $#_ >= 0 && UNIVERSAL::isa( $_[0], 'XMLUtil' ) )
  {
    shift;
  }
  return undef if $#_ < 0;
  my @objects    = ();
  my $xml_parser = new XML::Parser( Style => 'Tree' );
  NEXT_XML_STRING: foreach my $xml_string (@_)
  {
    my $obj;
    my $tree = $xml_parser->parsestring($xml_string);
    $obj = internal_xml_to_object( $tree, 0 );
    push @objects, $obj;
  }
  return wantarray ? @objects : $objects[0];
}

#************************************************************

=pod

=head1 COPYRIGHT

Copyright 2009-2012, Andrew Pitonyak (perlboy@pitonyak.org)

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

=head2 September 10, 2002

Version 1.00 Initial release

=head2 July 13, 2009

Version 1.01 Fixed conversion from XML back to an array.

=cut

#************************************************************

1;
