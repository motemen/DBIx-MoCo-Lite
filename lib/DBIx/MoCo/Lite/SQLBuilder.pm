package DBIx::MoCo::Lite::SQLBuilder;
use strict;
use warnings;
use parent 'SQL::Abstract';
use Carp;

our @CARP_NOT = qw(DBIx::MoCo::Lite);

sub _where_ARRAYREF {
    my ($self, $where) = @_;

    my ($sql, %bind) = @$where;

    my @values;
    $sql =~ s/:([A-Za-z_][A-Za-z0-9_]*)/
        croak qq(Bind value '$1' not found) unless exists $bind{$1};
        my $bind_values = $bind{$1};
        $bind_values = [ $bind_values ] if ref $bind_values ne 'ARRAY';
        push @values, @$bind_values;
        join ',', ( '?' ) x @$bind_values;
    /ge;

    return ($sql, @values);
}

sub select {
    my $self = shift;
    my ($table, $field, $where, $order, $limit, $offset) = @_;
    my ($sql, @binds) = $self->SUPER::select(@_);
    if (defined $limit) {
        croak qq(Non numeric limit '$limit') if $limit =~ /\D/;
        $sql .= ' LIMIT ' . int($limit);
        if (defined $offset) {
            croak qq(Non numeric offset '$offset') if $offset =~ /\D/;
            $sql .= ' OFFSET ' . int($offset);
        }
    }
    return ($sql, @binds);
}

1;
