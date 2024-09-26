#!/usr/bin/env perl

use Time::HiRes "sleep";

# Creates duets out of learning tracks
# See usage at the bottom.
use warnings;
use v5.12;
use MP3::Tag;

use Getopt::Long;

use List::Util qw(first);

my $help;
my $dry_run;
my $verbose;
my ($start, $stop) = (1,12);
my ($begin, $end)  = (1, 1_000_000_000);
my $album;

# Parts should be configurable.  They're not, yet.
my @parts = qw(lead bass tenor bari);
my @pts = qw(Ld Bs Tr Br);

command_line();

my $pt_re = qr<@{[
    join "|", map { qr/\b$_\b/i } @parts
]}>;


my @base_command = qw(sox -S);
sub sys_or_die{
    print "@_\n" if $verbose;
    sleep .01;
    if (not $dry_run) {
        system(@_) == 0 or exit 1;
    }
}

sub file_for {
    state %file_for;
    my ($part, $num) = @_;
    my $file =  $file_for{$part}{$num} //=
        first{ -f $_ } (glob("$part/$num*.mp3"), glob ("$part/?-$num*.mp3"));
        # Some years, I claim that the albums are, for example
        # "1 of 4", and some years I don't. Thus, the filename Apple Music gives
        # the track can vary.
    die "No file found for part $part track number $num" unless $file;
    return $file;
}

# We use $tracknum to keep count of the output track number, so we can put them
# all in the same album. Since we increment it at the start of the loop, we
# want it to be one less than our desired starting number.
my $tracknum = ($start - 1 ) * @parts * (@parts - 1) / 2;

my @nums = map { sprintf("%02d",$_) } $start..$stop;
ALL:
for my $num (@nums) {
    for my $i ( 0..$#parts ) {
        my $part1 = $parts[$i];
        for my $j ( ($i+1)..$#parts ) {
            $tracknum++;
            if ($tracknum < $begin) {
                if ($verbose) {
                    state $have_printed;
                    print ! $have_printed++
                        ? "[$tracknum<$begin"   # Show beginning if we haven't printed"
                        : "[$tracknum"          # Just show the track number if we have
                        ;
                    # Why no closing bracket?  Um:
                    print $tracknum == $begin - 1
                        ? "=$begin-1]\n"     # show this is the end if it's the last time
                        : "]"                   # otherwise, just close the bracket
                }
                next;
            }
            if ($tracknum > $end) {
                print "$tracknum > \$end($end)\n"
                    if $verbose;
                last ALL;
            }
            my $part2 = $parts[$j];
            my @files;
            eval { @files = (
                    file_for($part1, $num),
                    file_for($part2, $num),
                );
            };
            if ($@) {
                die $@ unless $dry_run;
                print "Would have died (after track number $tracknum): $@\n";
            }
            next if @files == 1 or @files == 0;
            @files == 2 or die "Found more than two (or only 1) for file $num, parts $part1 and $part2";
            die "Undefined files in @files!" if grep { ! defined } @files;
            # I think we're getting undefs because first() is doing weird
            # things.  Don't care enough to track it down.

            my $file = sprintf("%03d",$tracknum) . "-$num-$part2-$part1.mp3";
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
            next if $dry_run;
            my ($title, $track, $artist, $cur_album) =
                MP3::Tag->new($files[0])->autoinfo;
            # Really we care about $title and $album.  Though we might want to
            # fiddle with track (if it contains the disk # info).

            unless ($album) {
                $album = $cur_album;
                $album =~ s/Learning Tracks/Learning Duets/;
                $album =~ s/$pt_re //;
            }

            my $duet = "$part2/$part1";
            for ($title) {
                $_ = "$duet - $_" unless s/$pt_re/$duet/g;
                s/\s\s+/ /g;
            }

            my $mp3 = MP3::Tag->new($file);
            $mp3->update_tags({
                title => $title,
                album => $album,
                track => $tracknum,
            });
            # Now make title appropriate for paths.
            $title =~ s{\s*$duet\s*-?\s*}{ };
            $title =~ s{/}{_}g;
            $duet =~ s{/}{-}g;
            my $new_path = sprintf(
                "%02d %s - %s.mp3",
                $tracknum, $duet, $title
            );
            system(qw(mv -v), $file, $new_path);
        }
    }
}

sub command_line {
    GetOptions(
        "help" => \$help,
        "dry-run!"  => \$dry_run,
        "verbose!"  => \$verbose,
        "start=i" => \$start,
        "stop=i" => \$stop,
        "begin=i" => \$begin,
        "end=i" => \$end,
        "album=s"   => \$album,
    ) or exit 1;

    if ($help) {
        print usage();
        exit 0;
    }
    $verbose //= $dry_run;
}
sub usage {
    return <<"EOQ";
Usage: $0 [--dry-run] [--verbose]
    [--start=N] [--stop=N]  # Refers to the source track numbers
    [--begin=N] [--end=N]   # Refers to the destination track numbers
Creates duets out of learning tracks. You should set up a temporary directory
with symlinks for each part (lead, bari, bass, tenor), and then all 6 duets will
be created when run in that temporary directory.


By default, we try for source track numbers 1 through 12, and do all
destination tracks. Use --start and --stop (for the source tracks)
and --begin and --end (for the destination track numbers) to change
that if some have already been made.

Use --dry-run to see what would be done. (Extremely useful for
figuring out --begin and --end)

It is assumed that the file names will be something like, for example:
    bari/01 Make 'Em Laugh.mp3
    tenor/10 May I Never Love Again.mp3

EOQ
}
