#!/usr/bin/perl
#
# Usage: nlp.pl [topic_site_id] [topic] [output file]
# ./nlp.pl 1 technology sentiment.txt
#
# See;
# http://www.foo.be/docs/tpj/issues/vol5_3/tpj0503-0010.html
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

# For NLP
use Lingua::LinkParser;
use Lingua::EN::Sentence qw ( get_sentences add_acronyms );

my $topic_site_id      = shift @ARGV;
my $topic              = shift @ARGV;
my $output_data        = shift @ARGV;

die "Missing topic_site_mine id argument." unless (defined $topic_site_id);
die "Missing topic string argument." unless (defined $topic);
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
my $id;

my $parser;
my $linkage;

sub InitNLP {
  $parser = new Lingua::LinkParser;
}

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
#   open(FH, ">$output_data");
#   close(FH);
  print "File data saved.\n";
}

#############################################################################

sub FindSentiment {
  # We'll pretend that there might be sentences (hoo boy)
  # $temp =~ s/^[0-9]+$//gi;
  # $temp =~ s/bbcode//gi;
  # $temp =~ s/&amp;//gi;


  print "Parsing sentences.\n";
  my $sentences = get_sentences($temp);
  print "Parsed sentences.\n";

  my $sentence;
  foreach (@$sentences) {
    print "Structuring sentence: $_\n";
    $sentence = $parser->create_sentence($_);
    print "Creating linkage.\n";
    $linkage = $sentence->linkage(1);
    print "Diagram: \n";
    print $parser->get_diagram($linkage);
  }
}

#############################################################################

sub CloseDB {
  print "Ending session.\n";
  my $rc = $dbh->disconnect or warn $dbh->errstr;
  close(FH);
}

#############################################################################

InitDB();
InitNLP();

# For each record with topic_site_id = ...
$sth_o = $dbh->prepare('select id from mm_topic_site_mine where id=?');
$sth_o->execute($topic_site_id);
$sth_o->bind_columns(undef, \$id);

while ($sth_o->fetch()) {
  GetRecord($id);
  FindSentiment();
  die("Only doing this once.");
}

$sth_o->finish();

# SaveData();
CloseDB();

return 1;
