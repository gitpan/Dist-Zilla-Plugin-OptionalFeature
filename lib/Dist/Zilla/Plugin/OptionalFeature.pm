use strict;
use warnings;
package Dist::Zilla::Plugin::OptionalFeature;
{
  $Dist::Zilla::Plugin::OptionalFeature::VERSION = '0.004';
}
# git description: v0.003-1-g9674fbc

BEGIN {
  $Dist::Zilla::Plugin::OptionalFeature::AUTHORITY = 'cpan:ETHER';
}
# ABSTRACT: Specify prerequisites for optional features in your dist

use Moose;
with
    'Dist::Zilla::Role::MetaProvider',
    'Dist::Zilla::Role::PrereqSource';

use MooseX::Types::Moose qw(HashRef Bool);
use MooseX::Types::Common::String 'NonEmptySimpleStr';
use namespace::autoclean;

has name => (
    is => 'ro', isa => NonEmptySimpleStr,
    required => 1,
);
has description => (
    is => 'ro', isa => NonEmptySimpleStr,
    lazy => 1,
    default => sub { shift->name }
);

has always_recommend => (
    is => 'ro', isa => Bool,
    default => 0,
    predicate => '_has_always_recommend',
);

has _prereq_phase => (
    is => 'ro', isa => NonEmptySimpleStr,
    lazy => 1,
    default  => 'runtime',
);

has _prereq_type => (
    is => 'ro', isa => NonEmptySimpleStr,
    lazy => 1,
    default => 'requires',
);

has _prereqs => (
    is => 'ro', isa => HashRef[NonEmptySimpleStr],
    lazy => 1,
    default => sub { {} },
);

sub mvp_aliases { return { -relationship => '-type' } }

around BUILDARGS => sub
{
    my $orig = shift;
    my $class = shift;

    my $args = $class->$orig(@_);

    my @private = grep { /^_/ } keys %$args;
    confess "Invalid options: @private" if @private;

    my ($zilla, $plugin_name) = delete @{$args}{qw(zilla plugin_name)};

    my ($feature_name, $description, $always_recommend, $phase) =
        delete @{$args}{qw(-name -description -always_recommend -phase)};
    my ($type) = grep { defined } delete @{$args}{qw(-type -relationship)};

    my @other_options = grep { /^-/ } keys %$args;
    confess "invalid option(s): @other_options" if @other_options;

    # handle magic plugin names
    if ((not $feature_name or not $phase or not $type)
            # plugin comes from a bundle
        and $plugin_name !~ m! (?: \A | / ) OptionalFeature \z !x)
    {
        $feature_name ||= $plugin_name;

        if ($feature_name =~ / -
                (Build|Test|Runtime|Configure|Develop)
                (Requires|Recommends|Suggests|Conflicts)?
            \z/xp)
        {
            $feature_name = ${^PREMATCH};
            $phase ||= lc($1) if $1;
            $type = lc($2) if $2;
        }
    }

    confess 'optional features may not use the configure phase'
        if $phase and $phase eq 'configure';

    return {
        zilla => $zilla,
        plugin_name => $plugin_name,
        defined $feature_name ? ( name => $feature_name ) : (),
        defined $description ? ( description => $description ) : (),
        always_recommend => $always_recommend,
        $phase ? ( _prereq_phase => $phase ) : (),
        $type ? ( _prereq_type => $type ) : (),
        _prereqs => $args,
    };
};

sub register_prereqs
{
    my $self = shift;

    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => 'develop',
        },
        %{ $self->_prereqs },
    );

    return if not $self->always_recommend;
    $self->zilla->register_prereqs(
        {
            type  => 'recommends',
            phase => $self->_prereq_phase,
        },
        %{ $self->_prereqs },
    );
}

sub metadata
{
    my $self = shift;

    return {
        dynamic_config => 1,
        optional_features => {
            $self->name => {
                description => $self->description,
                prereqs => { $self->_prereq_phase => { $self->_prereq_type => $self->_prereqs } },
            },
        },
    };
}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=encoding utf-8

=for :stopwords Karen Etheridge irc

=head1 NAME

Dist::Zilla::Plugin::OptionalFeature - Specify prerequisites for optional features in your dist

=head1 VERSION

version 0.004

=head1 SYNOPSIS

In your F<dist.ini>:

    [OptionalFeature / XS Support]
    -description = XS implementation (faster, requires a compiler)
    Foo::Bar::XS = 1.002

=head1 DESCRIPTION

This plugin provides a mechanism for specifying prerequisites for optional
features in metadata, which should cause CPAN clients to interactively prompt
you regarding these features at install time.

The feature I<name> and I<description> are required. The name can be extracted
from the plugin name.

You can specify requirements for different phases and relationships with:

    [OptionalFeature / Feature name]
    -description = description
    -phase = test
    -relationship = requires
    Fitz::Fotz    = 1.23
    Text::SoundEx = 3

If not provided, C<-phase> defaults to C<runtime>, and C<-relationship> to
C<requires>.

To specify feature requirements for multiple phases, provide them as separate
plugin configurations (keeping the feature name and description constant):

    [OptionalFeature / Feature name]
    -description = description
    -phase = runtime
    Foo::Bar = 0

    [OptionalFeature / Feature name]
    -description = description
    -phase = test
    Foo::Baz = 0

It is possible that future versions of this plugin may allow a more compact
way of providing sophisticated prerequisite specifications.

If the plugin name is the CamelCase concatenation of a phase and relationship
(or just a relationship), it will set those parameters implicitly.  If you use
a custom name, but it does not specify the relationship, and you didn't
specify either or both of C<-phase> or C<-relationship>, these values default
to C<runtime> and C<requires> respectively.

The example below is equivalent to the synopsis example above, except for the
name of the resulting plugin:

    [OptionalFeature]
    -name = XS Support
    -description = XS implementation (faster, requires a compiler)
    -phase = runtime
    -relationship = requires
    Foo::Bar::XS = 1.002

=for Pod::Coverage mvp_aliases metadata register_prereqs

=head1 CONFIG OPTIONS

This is mostly a restating of the information above.

=over 4

=item * C<-name>

The name of the optional feature, to be presented to the user. Can also be
extracted from the plugin name.

=item * C<-description>

The description of the optional feature, to be presented to the user.
Defaults to the feature name, if not provided.

=item * C<-always_recommend>

If set with a true value, the prerequisites are added to the distribution's
metadata as recommended prerequisites (e.g. L<cpanminus> will install
recommendations with C<--with-recommends>, even when running
non-interactively).

=item * C<-phase>

The phase of the prequisite(s). Should be one of: build, test, runtime,
or develop.

=item * C<-relationship> (or C<-type>)

The relationship of the prequisite(s). Should be one of: requires, recommends,
suggests, or conflicts.

=back

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-OptionalFeature>
(or L<bug-Dist-Zilla-Plugin-OptionalFeature@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-OptionalFeature@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=over 4

=item *

L<CPAN::Meta::Spec/optional_features>

=item *

L<Module::Install::API/features, feature (Module::Install::Metadata)>

=back

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
