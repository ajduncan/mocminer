#!/usr/bin/perl
#
# Program wrapper for DM process.
#
# Usage: start.pl [topic_site_id] [URL] [userid]
# ./start.pl 1 http://www.xys.org/cgi-bin/mainpage3.pl ajduncan
#
#############################################################################

use strict;

my $path          = "/var/www/development/mocminer/dm/";

my $topic_site_id = shift @ARGV;
my $url           = shift @ARGV;
my $user          = shift @ARGV;

my $prelda_output = $path . "prelda_output.txt";

my $miner_app      = $path . "miner.pl";
my $translator_app = $path . "translator.pl";
my $prelda_app     = $path . "prelda.pl";
my $prelda_run_app = $path . "lda_run.pl";
my $lda_run_app    = $path . "plda/lda";

print "Starting up.\n";

open(PIPE, "$miner_app $topic_site_id $url $user |");
while(<PIPE>) {
  print $_;
}
close(PIPE);

exit;

open(PIPE, "$translator_app $topic_site_id |");
while(<PIPE>) {
  print $_;
}
close(PIPE);

open(PIPE, "$prelda_app $topic_site_id $prelda_output |");
while(<PIPE>) {
  print $_;
}
close(PIPE);

open(PIPE, "$lda_run_app $prelda_output |");
while(<PIPE>) {
  print $_;
}
close(PIPE);

print "Finished.\n";
