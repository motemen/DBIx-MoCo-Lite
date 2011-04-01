package DBIx::MoCo::Lite::List;
use strict;
use warnings;
use parent 'List::Rubyish';
use Carp;

sub make_empty_list {
    my $self = shift;
    my $class = ref $self || $self;
    return wantarray ? () : $class->new;
}

sub map_relation {
    my ($self, $name) = @_;

    return $self->make_empty_list unless @$self;

    my $rel_info = $DBIx::MoCo::Lite::Relation->{ ref $self->[0] }->{ $name } or croak; # FIXME
    my ($model, $our_key, $their_key) = @$rel_info;

    return $model->find_multi($their_key => [ map { $_->{$our_key} } @$self ]);
}

sub embed_relation {
    my ($self, $name) = @_;
    my $sides = $self->map_relation($name);
    for (0 .. $#$self) {
        $self->[$_]->__build_property($name, sub { $sides->[$_] });
    }
    return $self;
}

1;
