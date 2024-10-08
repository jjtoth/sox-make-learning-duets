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

my @parts;
my %abbr_for = (
    tenor => "Tr",
    lead  => "Ld",
    bass  => "Bs",
    bari  => "Br",
);
my @files;

sub abbr_for {
    my $thing = shift;
    return $abbr_for{$thing} || $thing;
}

command_line();

$verbose //= 0; # This avoids tripping warnings about comparing non-numeric things

if (@ARGV) {
    while (my $arg = shift) {
        if (-d $arg ) {
            push @parts, $arg;
        }
        else {
            die "No directory for $arg";
        }
    }
}
else {
    @parts = qw( bari lead tenor bass);
}



my $pt_re = qr<@{[
    join "|", map { qr/$_/i } @parts
]}>;


my @base_command = qw(sox -S);
sub sys_or_die{
    if ($verbose) {
        say join " ", map {
            $_ eq quotemeta($_)   ? $_
            : $_ =~ m/^[\w_+.-]+$/ ? $_
            : ! m/'/              ? qq{'$_'}
            : do {
                my $copy = $_;
                $copy =~ s{'}{'\\''};
                qq{'$copy'}
            }
        } @_;
    }
    sleep .01;
    if (not $dry_run) {
        system(@_) == 0 or exit 1;
    }
}

sub file_for {
    state %file_for;
    my ($part, $num) = @_;
    my $file =  $file_for{$part}{$num} //=
        first{ -f $_ } (
            map {
                glob("$part/$_$num*.mp3"),
                glob ("$part/?-$_$num*.mp3")
            } ("0", "00", "")
        );
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

ALL:
for my $num ($start..$stop) {
    my @cur_parts = @parts;
    while (my $part1 = shift @cur_parts) {
        for my $part2 (@cur_parts) {
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
            my ($title, $track, $artist, $cur_album) =
                MP3::Tag->new($files[0])->autoinfo;
            # Really we care about $title and $album.  Though we might want to
            # fiddle with track (if it contains the disk # info).

            my $file_title = $title;
            my $duet = abbr_for($part1) . "/" . abbr_for($part2);
            for ($title) {
                # Either add the duet label to the front, or change the current
                # tag in the title to be that.
                $_ = "$duet - $_" unless s/(_|\b)$pt_re(\b|_)/$1$duet$2/g;
                s/\s\s+/ /g;
                s/__+/_/g;
                # If we ended up with the duet label at the end, move it to the
                # beginning.
                s/^(.*)([[:space:]]+|_)$duet$/$duet $1/;
            }
            for ($file_title) {
                # Remove leading, trailing ,or (somewhat) inner part name.
                s/(?:_|\b)$pt_re$//
                or
                s/^$pt_re(?:\b|_)//
                or
                s/\b$pt_re\b//;

                # Translate any slashes to underscores;
                s{/}{_}g;
                # Turn spaces and apostrophes into underscores, too.
                s/(?:\s+|')/_/g;
            }
            my $file = sprintf("%03d-%02d-%s-%s-%s.mp3", $tracknum, $num, $part1, $part2, $file_title);
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
                qw(remix 1 3),
                # I.e. take the first channel (left of the second) for the left
                # channel and the third channel (right of the first) for the
                # right.
            );

            unless ($album) {
                $album = $cur_album;
                $album =~ s/\b$pt_re\b//;
                $album =~ s/Learning Tracks/Learning Duets/
                    or $album = "$album Learning Duets";
                $album =~ s/\s\s+/ /g;
                say "\tAlbum will be $album" if $verbose;
            }
            my %mp3tags = (
                    title => $title,
                    album => $album,
                    track => $tracknum,
                    artist => $artist,
            );
            if (! $dry_run) {
                my $mp3 = MP3::Tag->new($file);
                $mp3->update_tags({%mp3tags});
            }
            if ($verbose > 1) {
                print "mp3info: {";
                print for map {
                    my ($key, $value) = ($_, $mp3tags{$_});
                    $value =~ s<([}{])> <} . q<$1> . q{>g;
                    qq{ $key => q{$value}, };
                } sort keys %mp3tags;
                say "}";
            }
        }
    }
}

sub command_line {
    GetOptions(
        "help" => \$help,
        "dry-run!"  => \$dry_run,
        "verbose+"  => \$verbose,
        'noverbose|no-verbose'  => sub {
            $verbose = 0;
        },
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
Usage: $0
    [ list_of_parts ]
    [--dry-run] [--verbose [--verbose [...]]]
    [--start=N] [--stop=N]  # Refers to the source track numbers
    [--begin=N] [--end=N]   # Refers to the destination track numbers

Creates duets out of learning tracks. You should set up a temporary
directory with symlinks for each part (e.g. lead, bari, bass, tenor),
and then all 6 duets will be created when run in that temporary directory.

By default, we try for source track numbers 1 through 12, and do all
destination tracks. Use --start and --stop (for the source tracks)
and --begin and --end (for the destination track numbers) to change
what we will do if some have already been made.

Also by default, we use lead bass tenor bari, in that order. If you'd like to
use other (or additional [or fewer]) parts, or use them in a different order,
you can specify them on the command line instead.

Use --dry-run to see what would be done. (Extremely useful for
figuring out --begin and --end).

--dry-run sets verbose. One -v shows the command to be run and what number of
destination track we are skipping (if applicable), and -v -v will also show
the MP3 tags we would add.

It is assumed that the file names will be something like, for example:
    bari/01 Make 'Em Laugh.mp3
    tenor/10 May I Never Love Again.mp3

EOQ
}
