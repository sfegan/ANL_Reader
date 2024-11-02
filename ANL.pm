package Palm::ANLList;

use strict;
use Palm::Raw();
use Palm::StdAppInfo;
use vars qw( $VERSION @ISA );

$VERSION = "1.0";
@ISA = qw( Palm::Raw Palm::StdAppInfo );

sub ParseRecord
  {
    my $self = shift;
    my %record = @_;

    delete $record{offset};

    my %HandlingInstructions =
      ( 0 => { "type_name"   => "account",
	       "unpack_fmt"  => "nNNDNCxzz",
	       "field_names" => [ "record_type_id", "account_catagory_id",
				  "currency_id", "credit_limit", "cheque_no",
				  "overdraft_warning", "name", "notes" ] },
	
	1 => { "type_name"   => "account group",
	       "unpack_fmt"  => "nx2zx",
	       "field_names" => [ "record_type_id", "name" ] },
	
	2 => { "type_name"   => "currency",
	       "unpack_fmt"  => "nxxDDz",
	       "field_names" => [ "record_type_id", "x", "y", "name" ] },

	3 => { "type_name"   => "catagory",
	       "unpack_fmt"  => "nx3z",
	       "field_names" => [ "record_type_id", "name" ] },

	4 => { "type_name"   => "unknown",
	       "unpack_fmt"  => "n",
	       "field_names" => [ "record_type_id" ] } );
		
    my $record_type = unpack("n",$record{data});

    die "Unknown record type ".$record_type
      if ( not exists $HandlingInstructions{$record_type} );

    my $h = $HandlingInstructions{$record_type};

    my @fields_data =
      Palm::ANL::super_unpack($h->{unpack_fmt}, $record{data});

    %{$record{fields}} = Palm::ANL::make_hash($h->{field_names},\@fields_data);
    $record{fields}->{record_type} = $h->{type_name};

    delete $record{data};
	
    return \%record;
}

package Palm::ANLTrans;

use strict;
use Palm::Raw();
use Palm::StdAppInfo;
use vars qw( $VERSION @ISA );

$VERSION = "1.0";
@ISA = qw( Palm::Raw Palm::StdAppInfo );

sub ParseRecord
  {
    my $self = shift;
    my %record = @_;

    delete $record{offset};

    my @fields = ( "day", "month", "year", "hour", "min",
		   "type_code", "account_id", "transfer_account_id",
		   "catagory_id", "currency_id", "foreign_amount", "amount",
		   "debit", "tax", "cleared", "reconciled",
		   "description", "cheque_no", "notes" );
    my $unpack_fmt = "CCnCCnNNNNDDCx7CCCx2zzz";

    my @fields_data =
      Palm::ANL::super_unpack($unpack_fmt, $record{data});

    delete $record{data};

    %{$record{fields}} = Palm::ANL::make_hash(\@fields, \@fields_data);

    return \%record;
  }

sub MergeListDB
  {
    my $self = shift;
    my $list_db = shift;

    my $record;

    my %id_hash;
    foreach $record ( @{$list_db->{records}} )
      {
	$id_hash{$record->{id}} = $record;
      }

    foreach $record ( @{$self->{records}} )
      {
	$record->{fields}->{account} =
	  $id_hash{$record->{fields}->{account_id}}->{fields}->{name};
	$record->{fields}->{transfer_account} =
	  $id_hash{$record->{fields}->{transfer_account_id}}->{fields}->{name};
	use Data::Dumper;
	$record->{fields}->{catagory} =
	  $id_hash{$record->{fields}->{catagory_id}}->{fields}->{name};
	$record->{fields}->{currency} =
	  $id_hash{$record->{fields}->{currency_id}}->{fields}->{name};
      }
  }

package Palm::ANL;
use Config;

sub import
  {
    &Palm::PDB::RegisterPDBHandlers("Palm::ANLList", ["JL02","Dat1"] );
    &Palm::PDB::RegisterPDBHandlers("Palm::ANLTrans", ["JL02","Dat2"] );
  }

sub super_unpack
  {
    my $format = shift;
    my $data = shift;

    my @result;

    while( $format )
      {
 	my $zindex = index $format, "z";
	my $Dindex = index $format, "D";

	if($zindex == 0)
	  {
	    my $str = unpack("Z*",$data);
	    push @result, $str;
	    $format = substr($format,1);
	    $data = substr($data, length($str)+1);
	  }
	elsif($Dindex == 0)
	  {
	    my $str = unpack("a8",$data);
	    push @result, unpack_double($str);
	    $format = substr($format,1);
	    $data = substr($data, 8);
	  }
	else
	  {
	    my $index = $zindex;
	    $index = $Dindex
	      if (($index == -1) || (($Dindex != -1)&&($Dindex < $index)));
	    my $subformat = $format;
	    $subformat = substr($format, 0, $index) if ( $index != -1 );

	    push @result, unpack($subformat, $data);
	    $format = substr($format, length($subformat));
	    $data = substr($data,length(pack($subformat)));
	  }
      }

    return @result;
  }

sub unpack_double
  {
    # This isn't guarenteed to work.
    if($Config{byteorder} == 1234)
      {
	my ($a,$b) = unpack("NN",shift);
	return unpack("d",pack("II",$b,$a));
      }
    elsif($Config{byteorder} == 4321)
      {
	return unpack("d",shift);
      }
    else
      {
	die "Weird byte order ".$Config{byteorder};
      }
  }

sub make_hash
  {
    my $keys = shift;
    my $vals = shift;

    my %hash;

    my $c = 0;
    while ( $c < scalar(@$keys) )
      {
	$hash{$keys->[$c]} = $vals->[$c];
	$c++;
      }

    return %hash;
}

1;
