use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;
use Test::Fatal;
use Test::Deep;
use Test::CPAN::Meta::JSON;
use Test::DZil;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/dist/DZT' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ GatherDir => ],
                    [ MetaJSON  => ],
                    [ OptionalFeature => 'Feature Name' => {
                            # use default description, phase, type
                            A => 0,
                        }
                    ],
                ),
            },
        },
    );

    like(
        exception { $tzil->build },
        qr/invalid syntax for optional feature name 'Feature Name'/,
        'bad feature name is disallowed',
    );

    # we test that this really does violate the spec, so if the spec ever gets
    # changed, we'll know to remove our prohibition.

    my $spec = Test::CPAN::Meta::JSON::Version->new(data => {
        optional_features => {
            'Feature Name' => {
                description => 'Feature Name',
                prereqs => {
                    runtime => { requires => { A => 0 } },
                },
            },
        },
        prereqs => {
            develop => { requires => { A => 0 } },
        },
    });

    my $result = $spec->parse;
    my @errors = $spec->errors;
    cmp_deeply(
        \@errors,
        superbagof(re(qr/^\QKey 'Feature Name' is not a legal identifier. (optional_features -> Feature Name) [Validation: 2]\E$/)),
        'metadata is invalid',
    )
    or diag 'got:', join("\n", '', @errors);
}

done_testing;
