use strict;
use warnings;

# This test was generated via Dist::Zilla::Plugin::Test::Compile 2.011

use Test::More 0.94;



use Capture::Tiny qw{ capture };

my @module_files = qw(
lib/Dist/Zilla/Plugin/OptionalFeature.pm
);

my @scripts = qw(

);

# no fake home requested

my @warnings;
for my $lib (@module_files)
{
    my ($stdout, $stderr, $exit) = capture {
        system($^X, '-Mblib', '-e', qq{require qq[$lib]});
    };
    is($?, 0, "$lib loaded ok");
    warn $stderr if $stderr;
    push @warnings, $stderr if $stderr;
}

is(scalar(@warnings), 0, 'no warnings found') if $ENV{AUTHOR_TESTING};



BAIL_OUT("Compilation problems") if !Test::More->builder->is_passing;

done_testing;
