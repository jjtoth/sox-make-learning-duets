# sox-make-learning-duets
Makes "learning duets" out of learning tracks.  Currently hard coded for Lead, Bari, Bass, and Tenor.

Requires sox (compiled with liblame), Perl, and the Time::HiRes and MP3::Tag Perl modules from CPAN.

Patches, suggestions, and some sort of test suite would be very welcome.

If the tracks you get aren't aligned (presumably because there are varying
lengths added to the beginning, the duets won't be in sync. I recommend using
Audacity to time shift them.
