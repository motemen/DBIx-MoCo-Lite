package DBIx::MoCo::Lite::SQLBuilder;
use strict;
use warnings;
use parent 'SQL::Abstract';
use Carp;

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

1;
