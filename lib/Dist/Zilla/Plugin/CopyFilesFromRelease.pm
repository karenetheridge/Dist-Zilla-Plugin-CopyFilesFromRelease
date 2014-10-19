package Dist::Zilla::Plugin::CopyFilesFromRelease;
use 5.008;
use strict;
use warnings;

# ABSTRACT: Copy files from a release (for SCM inclusion, etc.)

use Moose;
use Moose::Autobox;
with qw/ Dist::Zilla::Role::AfterRelease /;

use File::Copy ();

sub mvp_multivalue_args { qw{ filename match } }

has filename => (
    is => 'ro',
    lazy => 1,
    isa        => 'ArrayRef[Str]',
    default    => sub { [] },
);

has match => (
    is => 'ro',
    lazy => 1,
    isa        => 'ArrayRef[Str]',
    default    => sub { [] },
);

around dump_config => sub {
    my $orig = shift;
    my $self = shift;

    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        map { $_ => $self->$_ } qw(filename match),
    };

    return $config;
};

sub after_release {
    my $self = shift;
    my $built_in = $self->zilla->ensure_built;
    my $root = $self->zilla->root;

    my $file_match = join '|', map quotemeta, @{ $self->filename };
    $file_match = join '|', '^(?:' . $file_match . ')$', @{ $self->match };
    $file_match = qr/$file_match/;

    $built_in->recurse( callback => sub {
        my $file = shift;
        return
            if $file->is_dir;
        my $rel_path = $file->relative($built_in);
        my $unix_style = $rel_path->as_foreign('Unix');
        return
            unless $unix_style =~ $file_match;
        my $dest = $root->file($rel_path);
        File::Copy::copy("$file", "$dest")
            or $self->log_fatal("Unable to copy $file to $dest: $!");
        $self->log("Copied $file to $dest");
    });
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
__END__

=head1 SYNOPSIS

In your dist.ini:

    [CopyFilesFromRelease]
    filename = README
    match = ^MANIFEST*

=head1 DESCRIPTION

This plugin will automatically copy the files that you specify in
dist.ini from the build directory into the distribution directoory.
This is so you can commit them to version control.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Plugin::CopyFilesFromBuild> - The basis for this module
