#!/usr/bin/perl
#
# Usage: translator.pl [topic_site_id]
#
# Translates all records with the corresponding topic_site_id by taking the text
# column data, translating, and storing into the en_translation column.
#
# ./translator.pl 1 
#
# See: http://cpanratings.perl.org/dist/Lingua-Translate-Google
#
#############################################################################

use strict;
use utf8;

# Database connectivity
use DBI;

# Translation service (Google) using Lingua::Translate::Google.
# see: http://cpanratings.perl.org/dist/Lingua-Translate-Google
use Lingua::Translate; 
Lingua::Translate::config(back_end => 'Google', format => 'text'); 
my $translator = Lingua::Translate->new(src => 'zh-CN', dest => 'en'); 

# Translation must be broken into chunks (100 characters, but 5000 UTF-8?)
# http://code.google.com/p/google-ajax-apis/issues/detail?id=273
my $subsets    = 100;

# For utf8 encoding
use Encode qw(encode decode from_to encode_utf8 decode_utf8 is_utf8);
use Encode::CN;
use Encode::HanConvert;
use Encode::HanExtra;

my $topic_site_id = shift @ARGV;
my $id; # mapped to mm_topic_site_mine's id column

# Used to prepare db insertion.
my $dbtext        = "";

my $driver   = "mysql"; 
my $database = "mocminer";
my $dsn      = "DBI:$driver:database=$database";
my $userid   = "mocminer";
my $password = "mocminer";
my $dbh;
my $sth;
my $sth_o;
my $english_text;
my @result;
my $temp;

sub OpenDB {
  $dbh      = DBI->connect($dsn, $userid, $password) or die $DBI::errstr;

  # Use utf8 encoding for queries and connection.
  $sth = $dbh->prepare("set character_set_client=?");
  $sth->execute("utf8");
  $sth = $dbh->prepare("set character_set_connection=?");
  $sth->execute("utf8");

  # Required to pull data out using utf8
  $dbh->{'mysql_enable_utf8'} = 1;
  $dbh->do('SET NAMES utf8');

  print "Connected to database.\n";
}

#############################################################################

sub GetRecord {
  my $lid = shift;
  $sth    = $dbh->prepare('select text from mm_topic_site_mine where id=?');
  $sth->execute($lid);
  @result = $sth->fetchrow_array();
  $temp   = $result[0];
  $sth->finish();

  if (! utf8::is_utf8($temp)) {
    utf8::encode($temp);
    print "temp flagged as utf8.\n";
  }
}

#############################################################################

sub GetTranslation {
  my $max   = length($temp) - $subsets;
  my @list  = ();
  my $i     = 0;
  my $count = 0;
  my $t1    = "";

  @list = split /(.{99})/, $temp;

  # reset english text;
  $english_text = "";

  foreach (@list) {
    $count = $count + 1;
    print "Translating chunk \#" . $count . "\n";
    eval {
      $t1 = $translator->translate($_);
    } or do {
      # $t1 = "CHUNK ERROR: " . $@ . "\n";
      $t1 = ""; # no data is better than error data.
      print "Error in translation: " . $@ . "\n";
    };
    $english_text .= $t1;
    print "Finished chunk \#" . $count . "\n";
  }
}

#############################################################################

sub SaveDB {
  my $lid = shift;

  print "Saving data to database.\n";
  $sth = $dbh->prepare("update mm_topic_site_mine set en_translation=? where id=?");
  $sth->execute($english_text, $lid) or die $DBI::errstr;
  $sth->finish();
}


#############################################################################

sub CloseDB {
  print "Ending session.\n";
  my $rc = $dbh->disconnect or warn $dbh->errstr;
}

OpenDB();

# For each record with topic_site_id = ...
$sth_o = $dbh->prepare('select id from mm_topic_site_mine where topic_site_id=?');
$sth_o->execute($topic_site_id);
$sth_o->bind_columns(undef, \$id);

while ($sth_o->fetch()) {
  GetRecord($id);
  GetTranslation();
  SaveDB($id);
}

$sth_o->finish();

CloseDB();

# return 1;
