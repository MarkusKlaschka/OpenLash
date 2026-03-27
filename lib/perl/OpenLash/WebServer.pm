package OpenLash::WebServer;
use strict;
use warnings;
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);
use OpenLash::WebUI;
use IO::Socket::INET;
use JSON::PP;
use File::Spec;

my  = OpenLash::WebUI->new;

sub handle_request {
    my (, ) = @_;
    my  = ->url_path;
    if ( =~ m!^/(css|js)/(.*)) {
        my  = ;
        my  = ;
        my  = File::Spec->catfile('/root/OpenLash/webserver', , );
        if (-f ) {
            open my , '<',  or return print HTTP/1.0 500rnrnError;
            print HTTP/1.0 200 OKrnContent-Type:  . ( eq 'css' ? 'text/css' : 'application/javascript') . rnrn;
            print <>;
            close ;
        } else {
            print HTTP/1.0 404 Not Foundrnrn;
        }
    } elsif ( =~ m!^/api/(.*)) {
        my  = ;
        my  = IO::Socket::INET->new(PeerAddr => 'localhost', PeerPort => 5555, Proto => 'tcp');
        if () {
            print  encode_json({query => API: }) . n;
            my  = <>;
            print HTTP/1.0 200 OKrnContent-Type: text/plainrnrn . decode_json()->{result};
            close ;
        } else {
            print HTTP/1.0 500rnrnSocket error;
        }
    } else {
        print HTTP/1.0 200 OKrnContent-Type: text/htmlrnrn . ->render('index.tpl', {});
    }
}

1;
EOF && git add lib/perl/OpenLash/WebServer.pm
