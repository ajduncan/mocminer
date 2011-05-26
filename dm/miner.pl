#!/usr/bin/perl
#
# Usage: miner.pl [topic_site_id] [URL] [userid]
# ./miner.pl 1 http://www.devshed.com/c/a/Perl/Web-Mining-with-Perl/3/ ajduncan
# ./miner.pl 1 http://www.xys.org/cgi-bin/mainpage3.pl ajduncan
#
#############################################################################

use strict;
use utf8;

# Database connectivity
use DBI;

# For obtaining data from the web
use LWP::Simple;
use HTML::Parser;
use Data::Dumper;

# For utf8 encoding
use Encode qw(encode decode from_to encode_utf8 decode_utf8 is_utf8);
use Encode::CN;
use Encode::HanConvert;
use Encode::HanExtra;

# For translation and URL encoding
use URI::Escape;

my $topic_site_id = shift @ARGV;
my $url           = shift @ARGV;
my $user          = shift @ARGV;

# Used to prepare db insertion.
my $dbtext        = encode_utf8("");

# Used to track the document number, or level, from the entry URL.
my $document_level       = 0;
my $document_level_limit = 4;
my %document_links;
my @links;
my @ilinks;
my @scannedLinks;
my $temp;

die "Missing URL argument." unless (defined $url);

my $driver   = "mysql"; 
my $database = "mocminer";
my $dsn      = "DBI:$driver:database=$database";
my $userid   = "mocminer";
my $password = "mocminer";
my $dbh      = "";
my $sth;
my %results;

# Used as index to text between tags.
my $id       = 0;

sub InitDB {
  $dbh = DBI->connect($dsn, $userid, $password) or die $DBI::errstr;
  print "Connected to database.\n";

  # Use utf8 encoding for queries and connection.
  $sth = $dbh->prepare("set character_set_client=?");
  $sth->execute("utf8");
  $sth = $dbh->prepare("set character_set_connection=?");
  $sth->execute("utf8");

  print "Opening file for raw data.\n";
  open(FH, ">>data.txt");
}

#############################################################################

sub GetURLData {
  my $lurl = shift;
  $url = $lurl;
  print "Downloading content from $url:\n";
  my $content = get($lurl); 
  die "Download of URL failed.\n" if (!defined $content); 

  # Parse the web data:
  print "Parsing web data.\n";
  my $hp = HTML::Parser->new(
    api_version => 3,
    start_h     => [\&hp_opentag, 'tag, attr'],
    end_h       => [\&hp_closetag, 'tag'],
    text_h      => [\&hp_text, 'text']
  );

  $id = 0;
  $dbtext = "";

  $hp->parse($content);

  $document_links{$document_level} = \@links;
  push(@scannedLinks, $lurl);

}

sub hp_opentag {
  my ($tag, $attrHash) = @_;
  $id = $id + 1;
  if (lc($tag) eq "a") {
    # filter out based on rules (todo)
    $temp = $attrHash->{'href'};
    if ($temp =~ m/sci_forum\/db\//) {
      $temp = "http://www.xys.org" . $attrHash->{'href'};
      push(@links, $temp);
    }
  }
}

sub hp_closetag {
#  my $tag = shift;
#  print "close tag: $tag\n";
#  print "-----\n";
}

sub hp_text {
  # Get text, assuming input in gb2312
  my $text = shift;
  # print "Text: " . encode_utf8($text) . "\n";

  if (is_utf8($text)) {
    $text = encode_utf8($text);
  } else {
    # from_to($text, "gb2312", "utf8");
    $text = encode_utf8($text);
  }

  # print "-----\n";
  print FH $text . "\n\n";

  # Add to hash
  $dbtext .= $text;
  $results{$id} = $text;
}

# Save to DB

# foreach my $key (keys %results) {
#  # print "$results{$key}\n";
#  $dbtext .= $results{$key};
# }

#############################################################################

# if (! utf8::is_utf8($dbtext)) {
#   utf8::encode($dbtext);
#   print "dbtext flagged as utf8.\n";
# }

sub SaveDB {
  print "Saving document data to database.\n";
  $sth = $dbh->prepare("insert into mm_topic_site_mine (topic_site_id, url, document_level, userid, text) values (?,?,?,?,?)");
  $sth->execute($topic_site_id, $url, $document_level, $user, $dbtext) or die $DBI::errstr;
  $sth->finish();
}

#############################################################################

sub CloseDB {
  print "Ending session.\n";
  my $rc = $dbh->disconnect or warn $dbh->errstr;
  close(FH);
}


InitDB();
GetURLData($url);
SaveDB();

print ":::::::::: Document level " . $document_level . " ::::::::::\n";

# iterate through links if less than limit, increment counter
while ($document_level < $document_level_limit) {
  @ilinks = @{ $document_links{$document_level} };
  $document_level = $document_level + 1;
  foreach (@ilinks) {
    $temp = $_;
    if (!(grep $_ eq $temp, @scannedLinks)) {
      eval {
        GetURLData($temp);
        SaveDB();
      } or do {
        print "Exception trapped: $@\n";
      };
    } else {
      print "Already scanned $temp\n";
    }
  }
  print ":::::::::: Document level " . $document_level . " ::::::::::\n";
}
# close

CloseDB();
