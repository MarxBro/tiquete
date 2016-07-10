#!/usr/bin/perl
#use Data::Uniqid "luniqid";
#print luniqid();

use strict;
use v5.10;
use YAML;
use Data::Dumper;
use File::Slurp;

my $d = read_file "config.yml";

my $h = Load($d);

say Dumper($h);
say foreach sort(keys(%{$h}));
