package Test::More::Autodoc;
use 5.008005;
use strict;
use warnings;
use parent qw/Exporter/;
use Carp;
use Test::More ();
use Scope::Guard;
use JSON;
use LWP::UserAgent;
use Text::Xslate qw(mark_raw);;

our @EXPORT = qw/describe context http_ok/;

our $VERSION = "0.01";

my $in_describe;
my $in_context;
my $context;
my $results;

sub describe {
    if ($in_describe) {
        return Test::More::fail; # TODO add fail message.
    }

    my $guard = sub {
        return Scope::Guard->new(sub {
            undef $in_describe;
            undef $results;
        });
    }->();

    $in_describe = 1;

    my ($description, $coderef) = @_;

    my $result = Test::More::subtest($description => $coderef);

    if ($result) {
        _generate_markdown($description);
    }
}

sub context {
    if ($in_context) {
        return Test::More::fail; # TODO add fail message.
    }

    my $guard = sub {
        return Scope::Guard->new(sub {
            undef $in_context;
        });
    }->();

    $in_context = 1;

    $context    = shift;
    my $coderef = shift;

    Test::More::subtest($context => $coderef);
}

sub http_ok {
    my ($req, $expected_code, $comment) = @_; # TODO comment

    unless ($req->isa('HTTP::Request')) {
        return Test::More::fail; # TODO add fail message.
    }

    my $request_body = $req->content;
    my $content_type = $req->content_type;

    if($content_type =~ m!^application/json!) {
        $request_body = to_json(from_json($req->decoded_content), { pretty => 1 });
    }

    my $res = LWP::UserAgent->new->request($req);

    my $result = Test::More::is $res->code, $expected_code; # TODO
    return unless $result;

    my $response_body = $res->content;
    if($res->content_type =~ m!^application/json!) {
        $response_body = to_json(from_json($res->decoded_content), { pretty => 1 });
    }

    push @$results, +{
        context      => mark_raw($context),

        location     => mark_raw($req->uri->path),
        method       => mark_raw($req->method),
        query        => mark_raw($req->uri->query),
        parameters   => mark_raw($request_body),
        content_type => mark_raw($content_type),

        status       => mark_raw($expected_code),
        response     => mark_raw($response_body),
    };
}

sub _generate_markdown {
    my ($description) = @_;

    my $template = << 'END_OF_MARKDOWN';
# <: $description :>

: for $results -> $result {
## <: $result.context :>

### parameters

```
<: $result.parameters :>
```

### request

<: $result.method:> <: $result.location :>

: if $result.query {
    <: $result.query :>
: }
### response

```
Status: <: $result.status :>
Response:
<: $result.response :>
: }
```
END_OF_MARKDOWN

    my $tx = Text::Xslate->new();
    print $tx->render_string($template, {
        description => mark_raw($description),
        results     => $results,
    });
}

1;
__END__

=encoding utf-8

=head1 NAME

Test::More::Autodoc - It's new $module

=head1 ** CAUTION **

This module still alpha quality. DO NOT USE THIS.

このモジュールは出来損ないだ。良い子は使わない事！

=head1 SYNOPSIS

    use Test::More::Autodoc;

=head1 DESCRIPTION

Test::More::Autodoc is ...

=head1 LICENSE

Copyright (C) moznion.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

moznion E<lt>moznion@gmail.comE<gt>

=cut
