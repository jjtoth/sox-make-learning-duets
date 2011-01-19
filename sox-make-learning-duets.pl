#!/usr/bin/perl

# Creates duos out of learning tracks
# See usage.
sub usage {
    return <<"EOQ";
Usage: $0
Creates duos out of learning tracks.  You should set up a temporary directory
with symlinks for each part (lead, bari, bass, tenor), and then all 6 duos will
be created when run in that temporary directory.
EOQ
}

# TODO
# Do song names
# This is great for doing lots, but not so good for doing one.

# What this does (for the command line) is like this:
# sox -S lead/03 Lazybones - Lead.mp3 lead-only-03.mp3 mixer 0.4,0.6,0,0
# sox -S bass/03 03 Lazybones - Bass.mp3 bass-only-03.mp3 mixer 0.4,0.6,0,0
# sox -S -m lead-only-03.mp3 bass-only-03.mp3 03-lead-bass.mp3

# THERE IS A BETTER WAY!

# Mix it down:
# sox -S "Songname - Tenor\ Left.mp3" -c1 tenor-only.wav mixer -l
# sox -S "Songname - Lead\ Left.mp3" -c1 lead.wav mixer -l
# -c1 means "reduce to 1 channel", and mixer -l means "left only"
# Then merge via

# Assuming mon *-only.wav's, here:
#
#   my @parts=qw(lead bari bass tenor);
#   for my $i (0 .. $#parts - 1){
#       for my $j ($i+1 .. $#parts){
#           for $cmd ("sox -SM $parts[$i]-only.wav $parts[$j]-only.wav $parts[$i]-$parts[$j].mp3") {
#               print $cmd;system $cmd
#           }
#       }
#   }

use warnings;
use strict;

use Getopt::Long;

my $help;
my $dry_run;
command_line();

# These should be configurable.  They're not, yet.
my @parts = qw(lead bass bari tenor);
my @nums = map { sprintf("%02d",$_) } 1..12;

my @base_command = qw(sox -S);
my @mixer_commands = (
    ["mixer", "0.4,0.6,0,0"],
    ["mixer", "0.6,0.4,0,0"],
);
# 40% into left channel and 60% into the right, then vice versa

sub sys_or_die{
    print "@_\n";
    if (not $dry_run) {
        system(@_) == 0 or exit 1;
    }
}

for my $num (@nums ) {
    for my $i ( 0..$#parts ) {
        my $part1 = $parts[$i];
        for my $j ( ($i+1)..$#parts ) {
            my $part2 = $parts[$j];
            my @files = (
                glob("$part1/$num*.mp3") || glob ("$part1/?-$num*.mp3"),
                glob("$part2/$num*.mp3") || glob ("$part2/?-$num*.mp3"),
            );
            exit 0 if @files == 0;
            next if @files == 1; # There's that one tenor track that Larry didn't send us...
            @files == 2 or die "Found more than two (or only 1) for file $num, parts $part1 and $part2";
            my @part_files = map {
                "$_-only-$num.mp3"
            } ($part1,$part2);
            for (0..1) {
                sys_or_die(
                    @base_command,
                    $files[$_],
                    $part_files[$_],
                    @{$mixer_commands[0]}
                ) unless -f $part_files[$_];
            }
            sys_or_die(
                @base_command, "-m",
                @part_files,
                "$num-$part1-$part2.mp3"
            );
        }
    }
}
# sox -S Lead/$num*.mp3 leadonly-$num.mp3 mixer 0.4,0.6,0,0 
# sox -S Bass/$num*.mp3 bassonly-$num.mp3 mixer 0.6,0.4,0,0 
# sox -S -m bassonly-$num.mp3 leadonly-$num.mp3 leadbass-$num.mp3







sub command_line {
    GetOptions(
        "help" => \$help,
        "dry"  => \$dry_run,
    );

    if ($help) {
        print usage();
        exit 0;
    }
}
