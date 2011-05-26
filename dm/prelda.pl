#!/usr/bin/perl
#
# Usage: prelda.pl [topic_site_id] [output file]
# ./prelda.pl 1 test_data.txt
#
#############################################################################

use strict;
use utf8;

# Database connectivity
use DBI;

# For utf8 encoding
use Encode qw(encode decode from_to encode_utf8 decode_utf8 is_utf8);
use Encode::CN;
use Encode::HanConvert;
use Encode::HanExtra;

my $topic_site_id      = shift @ARGV;
my $output_data        = shift @ARGV;

die "Missing topic_site_mine id argument." unless (defined $topic_site_id);
die "Missing output_data string argument." unless (defined $output_data);

my $driver   = "mysql"; 
my $database = "mocminer";
my $dsn      = "DBI:$driver:database=$database";
my $userid   = "mocminer";
my $password = "mocminer";
my $dbh      = "";
my $sth;
my $sth_o;
my $temp;
my %dictionary;
my @document;
my $document_line;
my $id;

sub InitDB {
  $dbh = DBI->connect($dsn, $userid, $password) or die $DBI::errstr;

  # Use utf8 encoding for queries and connection.
  $sth = $dbh->prepare("set character_set_client=?");
  $sth->execute("utf8");
  $sth = $dbh->prepare("set character_set_connection=?");
  $sth->execute("utf8");
  $sth->finish();

  # Required to pull data out using utf8
  $dbh->{'mysql_enable_utf8'} = 1;
  $dbh->do('SET NAMES utf8');

  print "Connected to database.\n";

}

#############################################################################

sub GetRecord {
  my $lid = shift;
  $sth    = $dbh->prepare('select en_translation from mm_topic_site_mine where id=?');
  $sth->execute($lid);
  my @result = $sth->fetchrow_array();
  $temp   = $result[0];

  if (! utf8::is_utf8($temp)) {
    utf8::encode($temp);
    print "temp flagged as utf8.\n";
  }
}

#############################################################################

sub SaveData {
  print "Creating data file:\n";
  open(FH, ">$output_data");
  foreach (@document) {
    print FH $_ . "\n";
  }
  close(FH);
  print "File data saved.\n";
}

#############################################################################

sub BuildDocumentDictionary {
  my @tokens = split ' ', $temp;
  undef %dictionary;
  foreach (@tokens) {
    # Pruning here is important, and unique to certain mined data.
    $_ = lc($_);
    $_ =~ s/[^\w]//gi;
    $_ =~ s/^[0-9]+$//gi;
    $_ =~ s/bbcode//gi;

    if (length($_) > 0) {
      $dictionary{$_}++;
    }
  }

  $document_line = "";

  foreach (sort keys %dictionary) {
    $document_line .= $_ . " " . $dictionary{$_} . " ";
  }

  push(@document, $document_line);
}

#############################################################################

sub CloseDB {
  print "Ending session.\n";
  my $rc = $dbh->disconnect or warn $dbh->errstr;
  close(FH);
}

#############################################################################

InitDB();

# For each record with topic_site_id = ...
$sth_o = $dbh->prepare('select id from mm_topic_site_mine where topic_site_id=?');
$sth_o->execute($topic_site_id);
$sth_o->bind_columns(undef, \$id);

while ($sth_o->fetch()) {
  GetRecord($id);
  BuildDocumentDictionary();
}

$sth_o->finish();

SaveData();
CloseDB();

return 1;
