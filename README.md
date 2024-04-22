# sox-make-learning-duets
Makes "learning duets" out of learning tracks.

You should set up a temporary directory with symlinks for each part (lead,
bari, bass, tenor), and then all 6 duets will be created when run in that
temporary directory.  By default, we try for tracks 1 through 12; use
something like:

    perl sox-make-learning-duets.pl --start=15 --end=15

to override that.  Doesn't do well with single files; it assumes you have a
whole album of tracks.  (In particular, this was thrown together for working
with Harmony Brigades.)

Requires sox (compiled with liblame), Perl, and the Time::HiRes and MP3::Tag Perl modules from CPAN.

Patches, suggestions, and some sort of test suite would be very welcome.

If the tracks you get aren't aligned (presumably because there are short
intros of varying lengths added to the beginning), the duets won't be in sync.
I recommend using Audacity to time shift them.

KNOWN BUGS

* Looks like the "author" tag is being filled with the derived track number
* The script puts the parts in the wrong order (so if bari is in the left side and tenor in the right, it is given the name Tr/Br)
* The left channel might be much louder than the right of any given track.  (This might just be the speakers in my car.)
