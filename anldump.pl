#!/usr/bin/perl -w

use strict;
use Palm::PDB;
use Palm::ANL;

use Data::Dumper;

my $list_db = new Palm::PDB;
$list_db->Load("ANLListDB.pdb");
#print Dumper($list_db);

my $trans_db = new Palm::PDB;
$trans_db->Load("ANLTransDB.pdb");
$trans_db->MergeListDB($list_db);
#print Dumper($trans_db);

my $writer = new ANLTextAccountWriter(@ARGV);
$writer->write($trans_db);

#------------------------------------------------------------------------------

package ANLWriter;
use strict;
use vars qw( $VERSION @ISA );
$VERSION = "1.0";
@ISA = qw();

sub new
  {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = { @_ };
    bless ($self, $class);
    return $self;
  }

sub write
  {
  };

#------------------------------------------------------------------------------

package ANLTextAccountWriter;
use strict;
use vars qw( $VERSION @ISA );

BEGIN
  {
    $VERSION = "1.0";
    @ISA = qw(ANLWriter);
  }

sub write
  {
    my $self = shift;
    my $db = shift;

    my $balance=0;
    my $printed_balance=0;

    my $record;
    foreach $record ( @{$db->{records}} )
      {
	my $fields = $record->{fields};

	next 
	  if ((exists $self->{account}) &&
	      (lc($fields->{account}) ne lc($self->{account})));
	
	my $old_balance = $balance;
	if(($fields->{type_code} == 1) || ($fields->{type_code} == 2))
	  {
	    $balance -= $fields->{amount} if($fields->{debit});
	    $balance += $fields->{amount} if(not $fields->{debit});
	  }

	my $date = sprintf("%4.4d-%2.2d-%2.2d",
			   $fields->{year}, $fields->{month}, $fields->{day});
	my $time = sprintf("%2.2d:%2.2d",
			   $fields->{hour}, $fields->{min});

	next
	  if((exists $self->{first_date}) &&
	     (($date cmp $self->{first_date}) < 1));

	last
	  if((exists $self->{final_date}) &&
	     (($date cmp $self->{final_date}) > 1));

	next if ($fields->{type_code} != 2);
	
	if(not $printed_balance)
	  {
	    printf("----------  --:--  %-33s                   %9.2f\n",
		   "Balance",$old_balance);
	    $printed_balance = 1;
	  }

	my @add = ();
	push @add, "<".$fields->{transfer_account} #from
	  if(($fields->{transfer_account})&&
	     ($fields->{transfer_account} ne $fields->{account}) &&
	     (not $fields->{debit}));
	push @add, ">".$fields->{transfer_account} #to
 	  if(($fields->{transfer_account})&&
	     ($fields->{transfer_account} ne $fields->{account}) &&
	     ($fields->{debit}));
	push @add, "#".$fields->{cheque_no}
	  if ( $fields->{cheque_no} );
	my $add_text = join(" ",@add);

	my $text = sprintf("%-33s",$fields->{description});
	substr($text,33-length($add_text)-2)="[".$add_text."]" 
	  if ( $add_text );
	
	my $format = "%10s  %5s  %-33s ";

	$format .= "%8.2f          %9.2f\n" if(!$fields->{debit});
	$format .= "         %8.2f %9.2f\n" if($fields->{debit});
	
	printf($format, $date, $time, $text, $fields->{amount}, $balance);
      }
}


