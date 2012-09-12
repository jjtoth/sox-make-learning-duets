#!/usr/bin/env perl

use Time::HiRes "sleep";


# Creates duos out of learning tracks
# See usage.
sub usage {
    return <<"EOQ";
Usage: $0 [--start=N] [--end=N]
Creates duos out of learning tracks.  You should set up a temporary directory
with symlinks for each part (lead, bari, bass, tenor), and then all 6 duos will
be created when run in that temporary directory.
By default, we try for 1 through 12.
EOQ
}

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
use MP3::Tag;

use Getopt::Long;

use List::Util qw(first);

my $help;
my $dry_run;
my $verbose = 1;
my ($start, $end) = (1,12);
command_line();

# These should be configurable.  They're not, yet.
my @parts = qw(lead bass tenor bari);
my @pts = qw(Ld Bs Tr Br);
my ($pt_re) = map { qr/\b$_\b/i } join("|", @parts);

my @nums = map { sprintf("%02d",$_) } $start..$end;

my @base_command = qw(sox -S);
my @mixer_commands = (
    ["remix", 0, 1],
    ["remix", 1, 0],
    #`["mixer", "1.0,0.0,0.0,0.0"],
    #`["mixer", "0.0,1.0,0.0,0.0"],
    #["mixer", "0.4,0.6,0,0"],
    #["mixer", "0.6,0.4,0,0"],
);
# 40% into left channel and 60% into the right, then vice versa
# ---bzzzt!  Now doing "All right, then all left"

sub sys_or_die{
    print "\e[32m@_\e[0m\n" if $verbose;
    sleep .01;
    if (not $dry_run) {
        system(@_) == 0 or exit 1;
    }
}

for my $num (@nums) {
    for my $i ( 0..$#parts ) {
        my $part1 = $parts[$i];
        for my $j ( ($i+1)..$#parts ) {
            my $part2 = $parts[$j];
            my @files = (
                (first{ -f $_ } (glob("$part1/$num*.mp3"), glob ("$part1/?-$num*.mp3"))),
                (first{ -f $_ } (glob("$part2/$num*.mp3"), glob ("$part2/?-$num*.mp3"))),
            );
            do {
                print "No more files! (parts are $part1 $part2\n";
                exit 0 ;
            } if @files == 0;
            next if @files == 1;
            @files == 2 or die "Found more than two (or only 1) for file $num, parts $part1 and $part2";
            die "Undefined files in @files!" if grep { ! defined } @files;
            my @part_files = (
                "$part1-right-only-$num.mp3",
                "$part2-left-only-$num.mp3"
            );
            for (0..1) {
                unless (-f $part_files[$_]) {
                    sys_or_die(
                        @base_command,
                        $files[$_],
                        $part_files[$_],
                        @{$mixer_commands[$_]}
                    );
                    my $type = $part_files[$_];
                    $type =~ s/-\d+\.mp3$// or die "$type???";
                    $type = join " ", map { ucfirst } split /-/, $type;
                    sys_or_die(qw(mp3info2 -l), $type, $part_files[$_]);
                }
            }
            my $file = "$num-$part1-$part2.mp3";
            sys_or_die(
                @base_command, "-m",
                @part_files,
                $file
            );
            sys_or_die(qw(mp3info2 -l), "$part1 $part2 duets", $file);
        }
    }
}
# sox -S Lead/$num*.mp3 leadonly-$num.mp3 mixer 0.4,0.6,0,0 
# sox -S Bass/$num*.mp3 bassonly-$num.mp3 mixer 0.6,0.4,0,0 
# sox -S -m bassonly-$num.mp3 leadonly-$num.mp3 leadbass-$num.mp3

            my $mp3 = MP3::Tag->new($file);

            my ($title, $track, $artist, $album) =
                $mp3->autoinfo();
            # Really we care about $title and $album.  Though we might want to
            # fiddle with track (if it contains the disk # info).

            my $duet = "$pts[$i]/$pts[$j]";

            for ($title, $album) {
                $_ = "$duet - $_" unless s/$pt_re/$duet/g;
            }
            $album =~ s/Learning Tracks/Duets/;
            $mp3->update_tags({
                title => $title,
                album => $album,
            });
        }
    }
}



sub command_line {
    GetOptions(
        "help" => \$help,
        "dry"  => \$dry_run,
        "start=i" => \$start,
        "end=i" => \$end,
    ) or exit 1;

    if ($help) {
        print usage();
        exit 0;
    }
}
