#!/usr/bin/env perl

use Time::HiRes "sleep";


# Creates duets out of learning tracks
# See usage.
sub usage {
    return <<"EOQ";
Usage: $0 [--start=N] [--end=N]
Creates duets out of learning tracks.  You should set up a temporary directory
with symlinks for each part (lead, bari, bass, tenor), and then all 6 duets will
be created when run in that temporary directory.
By default, we try for 1 through 12.
EOQ
}

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
my $pt_re = qr<@{[
    join "|", map { qr/\b$_\b/i } @parts
]}>;

my @nums = map { sprintf("%02d",$_) } $start..$end;

my @base_command = qw(sox -S);
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
                # It would probably be better to set "file1" and "$file2"
                # above, one time each, instead of deriving it every time.
                # Deriving made some sense before we started using the -M flag
                # to sox with the remix effect, but now it doesn't (I think).
                (first{ -f $_ } (glob("$part1/$num*.mp3"), glob ("$part1/?-$num*.mp3"))),
                (first{ -f $_ } (glob("$part2/$num*.mp3"), glob ("$part2/?-$num*.mp3"))),
                # Some years, I claim that the albums are, for example
                # "1 of 4", and some years I don't. Thus, the name iTunes gives
                # the file varies.
            );
            do {
                print "No more files! (parts are $part1 $part2)\n";
                exit 0 ;
            } if @files == 0;
            next if @files == 1;

            @files == 2 or die "Found more than two (or only 1) for file $num, parts $part1 and $part2";
            die "Undefined files in @files!" if grep { ! defined } @files;
            # I think we're getting undefs because first() is doing weird
            # things.  Don't care enough to track it down.

            my $file = "$num-$part2-$part1.mp3";
            sys_or_die(
                @base_command, '-M',
                # -M means merge with separate channels.  So with two files,
                # we'll have four channels: left, right, left, right, (at this
                # stage, anyway).
                @files,

                qw(-C 160.2),
                # See soxformat(7).  Specifically, the 160 denotes 160kps
                # bitrate, and "quality" is set (using lame) at the recommended
                # "2" (instead of the lousy default "5").

                $file,
                qw(remix 3 1),
                # I.e. take the third channel (left of the second) for the left
                # channel and the first channel (right of the first) for the
                # right.
            );
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
            my $new_title = $title;
            $new_title =~ s{\s*$duet\s*-?\s*}{ };
            $new_title =~ s{/}{_}g;
            system(qw(mv -v), $file, "$num $part2-$part1 - $new_title.mp3")
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
