#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Git::Sub;
use Text::Diff;

# 'ssh' or 'sshd'
my $side = shift // 'ssh';

chdir 'openssh';

# Hard coded commit where the file appears in a way we are able to parse
# Basically: git --pretty=oneline $file | sed -n '$s/ .*$//p'
# Patch welcome to avoid this!
my %files = (
    ssh  => [ 'ssh_config.5'  => '479b476af623835b551ace88463665e6be7c8873' ],
    sshd => [ 'sshd_config.5' => '9f04903c50089acde55ef3ea7edd35161c5eac0c' ],
);

die "usage: $0 <ssh|sshd>" unless exists $files{$side};

my $file = $files{$side}[0];

# The first commit where $file appeared
my $first_commit = $files{$side}[1];

my @tags = git::tag '--contain' => $first_commit, -l => 'V_*';

my %tags =
    map {
	my @t = /V_([0-9]+)_([0-9]+)(?:_([0-9])+)?_P([0-9]+)/;
	($_ => [
	    ($t[0] << 12) | ($t[1] << 8) | (($t[2] // 0) << 4) | $t[3]
	])
    }
    @tags;

@tags = sort { $tags{$a}[0] <=> $tags{$b}[0] } @tags;

#say for @tags;

foreach my $v (keys %tags) {
    my $line = git::ls_tree $v, $file;
    #say $v, ' ', $line;
    my $obj = ($line =~ /^\d+ \S+ (\S+)/)[0];
    my @opts;
    open my $f, '-|', qw<git cat-file blob>, $obj;
    while (<$f>) {
	push @opts, $1 if /^.It Cm ([A-Z]\S+)/;
    }
    close $f;
    $tags{$v}[1] = \@opts;
    $tags{$v}[2] = [ map { "$_\n" } @opts ];
}

say "$tags[0]:";
say " $_" for @{ $tags{$tags[0]}[1] };

{
    package _Diff;
    use parent -norequire => 'Text::Diff::Unified';
    sub hunk_header { }
}

for(my $i=1; $i<@tags; $i++) {
    say "$tags[$i]:";
    say diff $tags{ $tags[$i-1] }[2],
	     $tags{ $tags[$i  ] }[2],
	     { CONTEXT => 0, STYLE => _Diff:: };
}

