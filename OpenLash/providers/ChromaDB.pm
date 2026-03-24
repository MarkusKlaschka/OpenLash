package OpenLash::Providers::ChromaDB;

use strict;
use warnings;
use LWP::UserAgent;
use JSON::PP qw(encode_json decode_json);
use HTTP::Request::Common;

sub new {
    my ($class, $config) = @_;
    my $self = {
        ua => LWP::UserAgent->new(timeout => 60),
        endpoint => $config->{endpoint} || 'http://localhost:8000',
        collection => $config->{collection} || 'long_term_memory',
    };
    bless $self, $class;
    $self->_ensure_collection;
    return $self;
}

sub _ensure_collection {
    my $self = shift;
    my $req = GET "$self->{endpoint}/api/v1/collections/$self->{collection}";
    my $res = $self->{ua}->request($req);
    unless ($res->is_success) {
        # Create if not exists
        my $create_req = POST "$self->{endpoint}/api/v1/collections",
            Content_Type => 'application/json',
            Content => encode_json({
                name => $self->{collection},
                metadata => { "hnsw:space": "cosine" },
            });
        $self->{ua}->request($create_req);
    }
}

sub store {
    my ($self, $doc_id, $document, $metadata, $embedding) = @_;
    my $req = POST "$self->{endpoint}/api/v1/collections/$self->{collection}/add",
        Content_Type => 'application/json',
        Content => encode_json({
            ids => [$doc_id],
            documents => [$document],
            metadatas => [$metadata],
            embeddings => [$embedding],
        });
    my $res = $self->{ua}->request($req);
    die "Chroma store failed: " . $res->status_line unless $res->is_success;
}

sub query {
    my ($self, $query_embedding, $n_results) = @_;
    $n_results ||= 5;
    my $req = POST "$self->{endpoint}/api/v1/collections/$self->{collection}/query",
        Content_Type => 'application/json',
        Content => encode_json({
            query_embeddings => [$query_embedding],
            n_results => $n_results,
            include => ['documents', 'metadatas', 'distances'],
        });
    my $res = $self->{ua}->request($req);
    die "Chroma query failed: " . $res->status_line unless $res->is_success;
    return decode_json($res->content);
}

1;