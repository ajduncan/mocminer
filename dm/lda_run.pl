#!/usr/bin/perl -w

use strict;

my $path          = "/var/www/development/mocminer/dm/";
my $test_data     = $path . shift @ARGV;
my $lda_path      = $path . "plda/";

my $lda_app       = $lda_path . "lda --num_topics 53 --alpha 0.1 --beta 0.01 --training_data_file " . $test_data . " --model_file /tmp/lda_model.txt --burn_in_iterations 100 --total_iterations 150";
my $viewmodel_app = $lda_path . "view_model.py /tmp/lda_model.txt viewable.txt > " . $path . "viewable.txt";

open(PIPE, "$lda_app |");
while(<PIPE>) {
  print $_;
}
close(PIPE);

open(PIPE, "$viewmodel_app |");
while(<PIPE>) {
  print $_;
}
close(PIPE);

open(MODEL, "$path" . "viewable.txt");
while(<MODEL>) {
  print $_;
}
close(MODEL);
